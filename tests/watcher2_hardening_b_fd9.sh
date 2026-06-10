#!/usr/bin/env bash
TMPD=$(mktemp -d)
WATCHED="$TMPD/inbox.yaml"; echo "x" > "$WATCHED"
# Fake watcher: spawns a blocking fswatch (no event => stays alive), records pids, sleeps
cat > "$TMPD/fakewatcher.sh" <<'FW'
#!/usr/bin/env bash
echo $$ > "$PIDFILE_W"
fswatch -1 --event Updated "$WATCHED" &
echo $! > "$PIDFILE_F"
wait
FW
chmod +x "$TMPD/fakewatcher.sh"

spawn() {  # $1=lock $2=w_pidfile $3=f_pidfile $4=mode(old|new)
  local lock="$1" wpf="$2" fpf="$3" mode="$4"
  if [ "$mode" = "old" ]; then
    ( flock -n 9 || exit 0
      PIDFILE_W="$wpf" PIDFILE_F="$fpf" WATCHED="$WATCHED" nohup bash "$TMPD/fakewatcher.sh" >/dev/null 2>&1 &
    ) 9>"$lock"
  else
    ( flock -n 9 || exit 0
      PIDFILE_W="$wpf" PIDFILE_F="$fpf" WATCHED="$WATCHED" nohup bash "$TMPD/fakewatcher.sh" >/dev/null 2>&1 9>&- &
    ) 9>"$lock"
  fi
}
holds_fd9() { lsof "$1" 2>/dev/null | grep -c "9[rwu]"; }
can_acquire() { ( flock -n 9 && echo YES || echo NO ) 9>"$1"; }

LOCK_OLD="$TMPD/old.lock"; LOCK_NEW="$TMPD/new.lock"
pass=0; fail=0
chk(){ if [ "$1" = "$2" ]; then echo "  PASS: $3"; pass=$((pass+1)); else echo "  FAIL: $3 (got='$1' want='$2')"; fail=$((fail+1)); fi; }

echo "== OLD pattern (no 9>&-): child+fswatch inherit fd9 =="
spawn "$LOCK_OLD" "$TMPD/w_old" "$TMPD/f_old" old; sleep 1.5
echo "  lsof OLD lock:"; lsof "$LOCK_OLD" 2>/dev/null | awk 'NR==1||/9[rwu]/{print "    "$1,$2,$4}'
chk "$([ "$(holds_fd9 "$LOCK_OLD")" -ge 1 ] && echo held || echo free)" "held" "OLD: someone holds fd9"

echo "== NEW pattern (9>&-): child+fswatch do NOT inherit fd9 =="
spawn "$LOCK_NEW" "$TMPD/w_new" "$TMPD/f_new" new; sleep 1.5
echo "  lsof NEW lock:"; lsof "$LOCK_NEW" 2>/dev/null | awk 'NR==1||/9[rwu]/{print "    "$1,$2,$4}' || true
chk "$(holds_fd9 "$LOCK_NEW")" "0" "NEW: nobody holds fd9 after subshell exit"

echo "== ORPHAN scenario: kill watcher, leave fswatch orphan, can supervisor respawn? =="
W_OLD=$(cat "$TMPD/w_old"); F_OLD=$(cat "$TMPD/f_old")
W_NEW=$(cat "$TMPD/w_new"); F_NEW=$(cat "$TMPD/f_new")
kill "$W_OLD" 2>/dev/null; kill "$W_NEW" 2>/dev/null; sleep 1
echo "  orphan fswatch OLD alive? $(kill -0 "$F_OLD" 2>/dev/null && echo yes || echo no) / NEW alive? $(kill -0 "$F_NEW" 2>/dev/null && echo yes || echo no)"
chk "$(can_acquire "$LOCK_OLD")" "NO"  "OLD: orphan fswatch holds lock -> respawn BLOCKED (bug)"
chk "$(can_acquire "$LOCK_NEW")" "YES" "NEW: orphan fswatch frees lock -> respawn SUCCEEDS (fix)"

# cleanup: only our captured pids + tmp
for p in "$W_OLD" "$F_OLD" "$W_NEW" "$F_NEW"; do kill "$p" 2>/dev/null || true; done
sleep 0.5; rm -rf "$TMPD"
echo ""; echo "RESULT: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
