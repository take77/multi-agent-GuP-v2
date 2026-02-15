#!/bin/bash
# check_inbox_on_stop.sh
# Claude Code Stop Hook: Check for unread inbox messages
# Usage: Called by .claude/settings.json hooks.stop

AGENT_ID="${1:-}"
[ -z "$AGENT_ID" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Path resolution based on CLUSTER_ID
if [ -n "$CLUSTER_ID" ]; then
    INBOX_PATH="$SCRIPT_DIR/clusters/$CLUSTER_ID/queue/inbox/${AGENT_ID}.yaml"
else
    INBOX_PATH="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
fi

[ ! -f "$INBOX_PATH" ] && exit 0

# Count read: false messages using python3
UNREAD=$(python3 -c "
import yaml
try:
    with open(\"$INBOX_PATH\", \"r\") as f:
        data = yaml.safe_load(f)
    messages = data.get(\"messages\", []) if data else []
    unread = sum(1 for m in messages if not m.get(\"read\", True))
    print(unread)
except:
    print(0)
" 2>/dev/null)

if [ "$UNREAD" -gt 0 ] 2>/dev/null; then
    echo "inbox${UNREAD}"
fi
exit 0
