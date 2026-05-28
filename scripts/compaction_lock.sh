#!/usr/bin/env bash
# compaction_lock.sh — Compaction 中の inbox 配信一時停止
# Usage:
#   bash scripts/compaction_lock.sh lock    # PreCompact hook から呼ばれる
#   bash scripts/compaction_lock.sh unlock  # PostCompact hook から呼ばれる
#   bash scripts/compaction_lock.sh check   # inbox_watcher から呼ばれる (exit 0=locked, 1=unlocked)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="${AGENT_ID:-$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo 'unknown')}"
LOCKFILE="${SCRIPT_DIR}/queue/inbox/.compaction_lock_${AGENT_ID}"

case "${1:-}" in
    lock)
        mkdir -p "$(dirname "$LOCKFILE")"
        echo "$(date '+%Y-%m-%dT%H:%M:%S')" > "$LOCKFILE"
        echo "[compaction_lock] LOCKED: ${AGENT_ID} — inbox 配信一時停止" >&2
        ;;
    unlock)
        if [ -f "$LOCKFILE" ]; then
            rm -f "$LOCKFILE"
            echo "[compaction_lock] UNLOCKED: ${AGENT_ID} — inbox 配信再開" >&2
        fi
        ;;
    check)
        if [ -f "$LOCKFILE" ]; then
            exit 0  # locked
        else
            exit 1  # unlocked
        fi
        ;;
    *)
        echo "Usage: compaction_lock.sh {lock|unlock|check}" >&2
        exit 2
        ;;
esac
