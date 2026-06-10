#!/usr/bin/env bash
export __INBOX_WATCHER_TESTING__=1
source scripts/inbox_watcher.sh
TMPD=$(mktemp -d); export IDLE_FLAG_DIR="$TMPD"
AGENT_ID="testbot"; PANE_TARGET="fake:0.0"; LAST_CLEAR_TS=0; CLUSTER_ID=""; FINAL_ESCALATION_ONLY=0
mkdir -p "$TMPD/bin"
cat > "$TMPD/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
if [ "$1" = "send-keys" ]; then shift; echo "SEND-KEYS $*" >> "$SENT_LOG"; fi
exit 0
TMUX
# timeout shim: drop duration arg, exec rest (matches polyfill semantics for test)
cat > "$TMPD/bin/timeout" <<'TO'
#!/usr/bin/env bash
shift; exec "$@"
TO
chmod +x "$TMPD/bin/tmux" "$TMPD/bin/timeout"
export PATH="$TMPD/bin:$PATH"; export SENT_LOG="$TMPD/sent.log"
get_effective_cli_type() { echo "claude"; }
agent_has_self_watch() { return 1; }
write_hybrid_inbox() { return 1; }
pass=0; fail=0
chk() { if [ "$1" = "$2" ]; then echo "  PASS: $3"; pass=$((pass+1)); else echo "  FAIL: $3 (got='$1' want='$2')"; fail=$((fail+1)); fi; }

echo "== BUSY (flag absent): SKIP =="
rm -f "$TMPD/gup_idle_testbot"; : > "$SENT_LOG"
send_wakeup 3 2>"$TMPD/busy.err"
chk "$(grep -c 'inbox' "$SENT_LOG")" "0" "no nudge to busy agent"
grep -q "is busy" "$TMPD/busy.err" && echo "  (log: deferring nudge)"

echo "== IDLE (flag present): DELIVER inbox3 =="
touch "$TMPD/gup_idle_testbot"; : > "$SENT_LOG"
send_wakeup 3 2>"$TMPD/idle.err"
chk "$(grep -c 'inbox3' "$SENT_LOG")" "1" "nudge inbox3 delivered to idle agent"
echo "  sent: $(tr '\n' '|' < "$SENT_LOG")"

echo ""; echo "RESULT: pass=$pass fail=$fail"
rm -rf "$TMPD"; [ "$fail" -eq 0 ]
