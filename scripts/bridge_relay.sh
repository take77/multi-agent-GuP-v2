#!/bin/bash
# bridge_relay.sh — Agent Teams ↔ YAML 変換ブリッジ
# Usage: bash scripts/bridge_relay.sh <direction> <captain_id> <cluster_session> [args...]
# direction: down (Agent Teams → YAML) | up (YAML → Agent Teams message)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse common arguments
DIRECTION="${1:-}"
CAPTAIN_ID="${2:-}"
CLUSTER_SESSION="${3:-}"

# Validate common arguments
if [ -z "$DIRECTION" ] || [ -z "$CAPTAIN_ID" ] || [ -z "$CLUSTER_SESSION" ]; then
    echo "Usage: bridge_relay.sh <direction> <captain_id> <cluster_session> [args...]" >&2
    exit 1
fi

if [ "$DIRECTION" != "down" ] && [ "$DIRECTION" != "up" ]; then
    echo "ERROR: direction must be 'down' or 'up'" >&2
    exit 1
fi

# Determine log path
LOG_DIR="$SCRIPT_DIR/logs/bridge"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${CAPTAIN_ID}_$(date +%Y%m%d).log"

# Log function
log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [bridge_relay/$DIRECTION] $*" | tee -a "$LOG_FILE" >&2
}

# --- DOWN: Agent Teams → YAML ---
if [ "$DIRECTION" == "down" ]; then
    MESSAGE_CONTENT="${4:-}"
    PROJECT="${5:-}"
    PRIORITY="${6:-medium}"
    ACCEPTANCE_CRITERIA="${7:-No acceptance criteria provided}"

    if [ -z "$MESSAGE_CONTENT" ] || [ -z "$PROJECT" ]; then
        echo "ERROR: down mode requires message_content and project" >&2
        exit 1
    fi

    # Determine queue path (cluster-aware)
    if [ -d "$SCRIPT_DIR/clusters/$CLUSTER_SESSION/queue" ]; then
        QUEUE_FILE="$SCRIPT_DIR/clusters/$CLUSTER_SESSION/queue/captain_to_vice_captain.yaml"
        CLUSTER_ID="$CLUSTER_SESSION"
    else
        QUEUE_FILE="$SCRIPT_DIR/queue/captain_to_vice_captain.yaml"
        CLUSTER_ID=""
    fi

    LOCKFILE="${QUEUE_FILE}.lock"
    mkdir -p "$(dirname "$QUEUE_FILE")"

    # Initialize queue file if not exists
    if [ ! -f "$QUEUE_FILE" ]; then
        echo "commands: []" > "$QUEUE_FILE"
    fi

    # Atomic write with flock (3 retries)
    attempt=0
    max_attempts=3
    CMD_ID=""

    while [ $attempt -lt $max_attempts ]; do
        CMD_ID=$(
            (
                flock -w 5 200 || exit 1

                # Generate cmd_id and append entry via Python3
                python3 -c "
import yaml, sys
from datetime import datetime

try:
    with open('$QUEUE_FILE') as f:
        data = yaml.safe_load(f)

    # Initialize if needed
    if not data:
        data = {}
    if not data.get('commands'):
        data['commands'] = []

    # Find max cmd_id
    max_id = 0
    for cmd in data['commands']:
        if cmd.get('id', '').startswith('cmd_'):
            try:
                num = int(cmd['id'].split('_')[1])
                max_id = max(max_id, num)
            except (IndexError, ValueError):
                pass

    new_id = f'cmd_{max_id + 1:03d}'

    # Create new entry
    new_entry = {
        'id': new_id,
        'timestamp': datetime.now().strftime('%Y-%m-%dT%H:%M:%S%z'),
        'purpose': '''$MESSAGE_CONTENT''',
        'acceptance_criteria': ['''$ACCEPTANCE_CRITERIA'''],
        'command': '''$MESSAGE_CONTENT''',
        'project': '$PROJECT',
        'priority': '$PRIORITY',
        'status': 'pending',
        'source': 'agent_teams'
    }

    data['commands'].append(new_entry)

    # Atomic write: tmp file + rename
    import tempfile, os
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname('$QUEUE_FILE'), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2, sort_keys=False)
        os.replace(tmp_path, '$QUEUE_FILE')
    except:
        os.unlink(tmp_path)
        raise

    # Output cmd_id to stdout for capture
    print(new_id)

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" || exit 1

            ) 200>"$LOCKFILE"
        )

        if [ -n "$CMD_ID" ]; then
            # Notify vice_captain via inbox_write.sh
            if [ -n "$CLUSTER_ID" ]; then
                CLUSTER_ID="$CLUSTER_ID" bash "$SCRIPT_DIR/scripts/inbox_write.sh" vice_captain "新規指令 $CMD_ID を受信。処理されたし。" cmd_new "$CAPTAIN_ID"
            else
                bash "$SCRIPT_DIR/scripts/inbox_write.sh" vice_captain "新規指令 $CMD_ID を受信。処理されたし。" cmd_new "$CAPTAIN_ID"
            fi

            log "DOWN SUCCESS: $CMD_ID created (project=$PROJECT, priority=$PRIORITY)"
            echo "$CMD_ID"
            exit 0
        else
            # Lock timeout or error
            attempt=$((attempt + 1))
            if [ $attempt -lt $max_attempts ]; then
                log "Lock timeout (attempt $attempt/$max_attempts), retrying..."
                sleep 1
            else
                log "ERROR: Failed to acquire lock after $max_attempts attempts"
                exit 1
            fi
        fi
    done

# --- UP: YAML → Agent Teams message ---
elif [ "$DIRECTION" == "up" ]; then
    CMD_ID="${4:-}"
    STATUS="${5:-}"
    SUMMARY="${6:-}"

    if [ -z "$CMD_ID" ] || [ -z "$STATUS" ] || [ -z "$SUMMARY" ]; then
        echo "ERROR: up mode requires cmd_id, status, and summary" >&2
        exit 1
    fi

    # Generate report message
    REPORT_MESSAGE="${CAPTAIN_ID}隊報告: $CMD_ID [$STATUS] — $SUMMARY"

    log "UP SUCCESS: $REPORT_MESSAGE"
    echo "$REPORT_MESSAGE"
    exit 0
fi
