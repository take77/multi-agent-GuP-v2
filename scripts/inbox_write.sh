#!/usr/bin/env bash
# inbox_write.sh — メールボックスへのメッセージ書き込み（排他ロック付き）
# Usage: bash scripts/inbox_write.sh <target_agent> <content> [type] [from]
# Example: bash scripts/inbox_write.sh darjeeling "華です。任務完了。" report_received hana

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --force フラグ処理（長文ブロック解除）
FORCE=0
if [ "$1" = "--force" ]; then
    FORCE=1
    shift
fi

TARGET="$1"
CONTENT="$2"
TYPE="${3:-wake_up}"
FROM="${4:-unknown}"

INBOX="$SCRIPT_DIR/queue/inbox/${TARGET}.yaml"
LOCKFILE="${INBOX}.lock"
DELIVERY_LOG="$SCRIPT_DIR/logs/inbox_delivery.log"
mkdir -p "$SCRIPT_DIR/logs"

# Validate arguments
if [ -z "$TARGET" ] || [ -z "$CONTENT" ]; then
    echo "Usage: inbox_write.sh [--force] <target_agent> <content> [type] [from]" >&2
    exit 1
fi

# 行数制約チェック（T8: 長文メッセージ制約）
LINE_COUNT=$(echo "$CONTENT" | wc -l | tr -d ' ')
if [ "$LINE_COUNT" -ge 21 ] && [ "$FORCE" -eq 0 ]; then
    echo "[inbox_write] BLOCK: メッセージが ${LINE_COUNT} 行（上限 20 行）。短文化するか、queue/reports/ に詳細を書いて pointer だけ送信してください。" >&2
    echo "[inbox_write] 強制送信が必要な場合は --force フラグを使用: bash scripts/inbox_write.sh --force ${TARGET} \"...\" ${TYPE} ${FROM}" >&2
    echo "[inbox_write] 参照: instructions/common/message_format.md" >&2
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [BLOCK_LINES] ${FROM} → ${TARGET} (type=${TYPE}) lines=${LINE_COUNT}" >> "$DELIVERY_LOG"
    exit 2
elif [ "$LINE_COUNT" -ge 11 ]; then
    echo "[inbox_write] WARNING: メッセージが ${LINE_COUNT} 行（推奨 10 行以内）。短文化を検討してください。" >&2
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [WARN_LINES] ${FROM} → ${TARGET} (type=${TYPE}) lines=${LINE_COUNT}" >> "$DELIVERY_LOG"
fi

# ACK 廃止チェック（T1: 節目以外の ack を warning）
case "$TYPE" in
    ack|ack_done|ack_progress|ack_merge|ack_merge_plus_followup|decision_ack|direction_ack|directive_ack|info_ack|review_ack|qc_ack|qc_relay_ack|qc_result_ack|task_ack|task_complete_ack|task_done_ack|task_assignment_ack|task_assigned|notification_ack|report_received|coordination_ack|standby_ack|closing_ack|merge_approval_ack|decision_response|report_ack|approval_ack|qc_standby_ack|qc_pass_ack|qc_briefing_ack|qc_acknowledgment|recovery_ack)
        # 許可 3 種: merge_complete / task_assigned_ack（タスク着手前の正式受領） / emergency_stop_ack
        if [ "$TYPE" != "merge_complete" ] && [ "$TYPE" != "task_assigned_ack" ] && [ "$TYPE" != "emergency_stop_ack" ]; then
            echo "[inbox_write] WARNING: ack型メッセージ（type=${TYPE}）は原則廃止。許可されるのは merge_complete / task_assigned_ack / emergency_stop_ack のみ。" >&2
            echo "[inbox_write] 参照: instructions/common/protocol.md § ACK Abolition Rule" >&2
            echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [WARN_ACK] ${FROM} → ${TARGET} (type=${TYPE})" >> "$DELIVERY_LOG"
        fi
        ;;
esac

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

# Generate unique message ID (timestamp-based)
MSG_ID="msg_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# Atomic write with flock (3 retries)
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
    if (
        flock -w 5 200 || exit 1

        # Add message via python3 (unified YAML handling)
        # Security: all variables passed via environment/stdin to prevent injection
        IW_INBOX="$INBOX" IW_MSG_ID="$MSG_ID" IW_FROM="$FROM" \
        IW_TIMESTAMP="$TIMESTAMP" IW_TYPE="$TYPE" \
        python3 -c "
import yaml, sys, os

try:
    content = sys.stdin.read().rstrip('\n')
    inbox_path = os.environ['IW_INBOX']

    # Load existing inbox
    with open(inbox_path) as f:
        data = yaml.safe_load(f)

    # Initialize if needed
    if not data:
        data = {}
    if not data.get('messages'):
        data['messages'] = []

    # Add new message
    new_msg = {
        'id': os.environ['IW_MSG_ID'],
        'from': os.environ['IW_FROM'],
        'timestamp': os.environ['IW_TIMESTAMP'],
        'type': os.environ['IW_TYPE'],
        'content': content,
        'read': False
    }
    data['messages'].append(new_msg)

    # Overflow protection: keep max 50 messages
    if len(data['messages']) > 50:
        msgs = data['messages']
        unread = [m for m in msgs if not m.get('read', False)]
        read = [m for m in msgs if m.get('read', False)]
        # Keep all unread + newest 30 read messages
        data['messages'] = unread + read[-30:]

    # Atomic write: tmp file + rename (prevents partial reads)
    import tempfile
    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(inbox_path), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path, inbox_path)
    except:
        os.unlink(tmp_path)
        raise

except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" <<< "$CONTENT" || exit 1

    ) 200>"$LOCKFILE"; then
        # Success — delivery log (案B)
        echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [SUCCESS] ${FROM} → ${TARGET} (type=${TYPE}) msg_id=${MSG_ID}" >> "$DELIVERY_LOG"

        # Read-back verification: confirm msg_id is in inbox (案A)
        if ! python3 -c "
import yaml, sys
try:
    data = yaml.safe_load(open('$INBOX')) or {}
    msgs = data.get('messages', []) or []
    found = any(str(m.get('id', '')) == '$MSG_ID' for m in msgs)
    if not found:
        print('[inbox_write] WARNING: write verification failed — msg_id $MSG_ID not found in $INBOX', file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f'[inbox_write] WARNING: read-back verification error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
            echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [WARN_VERIFY] ${FROM} → ${TARGET} (type=${TYPE}) msg_id=${MSG_ID}" >> "$DELIVERY_LOG"
            echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [inbox_write] WARNING: msg_id ${MSG_ID} not verified in ${INBOX}" >&2
        fi

        echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [inbox_write] SUCCESS: ${FROM} → ${TARGET} (type=${TYPE})" >&2

        # T5: inbox bloat 自動抑制 — メッセージ総数が 30 件を超えたら非同期でアーカイブを発火
        MSG_COUNT=$(python3 -c "
import yaml
try:
    data = yaml.safe_load(open('$INBOX')) or {}
    print(len(data.get('messages', []) or []))
except:
    print(0)
" 2>/dev/null || echo 0)
        if [ "${MSG_COUNT:-0}" -ge 30 ]; then
            nohup bash "$SCRIPT_DIR/scripts/inbox_archive.sh" --threshold 20 --keep-recent 10 "$TARGET" >/dev/null 2>&1 &
        fi

        exit 0
    else
        # Lock timeout or error
        attempt=$((attempt + 1))
        if [ $attempt -lt $max_attempts ]; then
            echo "[inbox_write] Lock timeout for $INBOX (attempt $attempt/$max_attempts), retrying..." >&2
            sleep 1
        else
            echo "[inbox_write] Failed to acquire lock after $max_attempts attempts for $INBOX" >&2
            echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [FAIL] ${FROM} → ${TARGET} (type=${TYPE}) msg_id=${MSG_ID}" >> "$DELIVERY_LOG"
            exit 1
        fi
    fi
done
