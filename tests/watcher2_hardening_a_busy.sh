#!/usr/bin/env bash
# Test harness for agent_is_busy flag-based logic (A verification)
export __INBOX_WATCHER_TESTING__=1
source scripts/inbox_watcher.sh

# Controlled test environment
TMPD=$(mktemp -d)
export IDLE_FLAG_DIR="$TMPD"
AGENT_ID="testbot"
PANE_TARGET="nonexistent:0.0"
LAST_CLEAR_TS=0
CLUSTER_ID=""

# Stub CLI type + pane scan
STUB_CLI="claude"
get_effective_cli_type() { echo "$STUB_CLI"; }
detect_agent_state() { echo "${STUB_PANE_STATE:-idle}"; }

pass=0; fail=0
chk() { if [ "$1" = "$2" ]; then echo "  PASS: $3 (got=$1)"; pass=$((pass+1)); else echo "  FAIL: $3 (got=$1 want=$2)"; fail=$((fail+1)); fi; }

echo "== idle_flag_path resolution =="
chk "$(idle_flag_path)" "$TMPD/gup_idle_testbot" "flat path (CLUSTER_ID unset)"
CLUSTER_ID="maho"; chk "$(idle_flag_path)" "$TMPD/gup_maho_idle_testbot" "cluster path (CLUSTER_ID=maho)"; CLUSTER_ID=""

echo "== claude: flag ABSENT => busy (suppress nudge) =="
rm -f "$TMPD/gup_idle_testbot"
if agent_is_busy; then chk busy busy "flag absent -> agent_is_busy=true (busy)"; else chk idle busy "flag absent -> busy"; fi

echo "== claude: flag PRESENT => idle (deliver nudge) =="
touch "$TMPD/gup_idle_testbot"
if agent_is_busy; then chk busy idle "flag present -> idle"; else chk idle idle "flag present -> agent_is_busy=false (idle)"; fi

echo "== /clear cooldown: forced busy within 30s even with flag present =="
LAST_CLEAR_TS=$(date +%s)
if agent_is_busy; then chk busy busy "within /clear cooldown -> busy"; else chk idle busy "cooldown should force busy"; fi
LAST_CLEAR_TS=$(( $(date +%s) - 31 ))
if agent_is_busy; then chk busy idle "after cooldown(31s) + flag present -> idle"; else chk idle idle "after cooldown -> idle"; fi
LAST_CLEAR_TS=0

echo "== non-claude (codex): uses pane scan fallback, ignores flag =="
STUB_CLI="codex"; rm -f "$TMPD/gup_idle_testbot"   # flag absent but should not matter
STUB_PANE_STATE="busy"; if agent_is_busy; then chk busy busy "codex pane=busy -> busy"; else chk idle busy "codex busy"; fi
STUB_PANE_STATE="idle"; if agent_is_busy; then chk busy idle "codex pane=idle -> idle"; else chk idle idle "codex idle (flag absent ignored)"; fi

echo ""
echo "RESULT: pass=$pass fail=$fail"
rm -rf "$TMPD"
[ "$fail" -eq 0 ]
