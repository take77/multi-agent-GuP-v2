#!/usr/bin/env bash
# codex_review_post.sh — Codex verdict を jsonl に全文記録 + inbox に 3 行 pointer を流す
# T7: 2026-04-19 制定
#
# Usage:
#   bash scripts/codex_review_post.sh \
#     --task-id <id> --pr <N> --verdict <lgtm|minor|major|critical> \
#     --to <target_agent> --from <vice_captain_id> \
#     [--reason "calibration 理由"] [--summary "1 行要旨"] \
#     [--full-text-file path/to/full_verdict.txt]
#
# 効果:
#   1. queue/hq/codex_reviews.jsonl に 1 行 JSON で全文追記（line_no 確定）
#   2. inbox に 3 行 pointer のみ送信（verdict / reason / pointer=jsonl:line_no）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSONL="$SCRIPT_DIR/queue/hq/codex_reviews.jsonl"

# 引数パース
TASK_ID=""
PR=""
VERDICT=""
TO=""
FROM=""
REASON=""
SUMMARY=""
FULL_TEXT_FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --task-id)      TASK_ID="$2"; shift 2 ;;
        --pr)           PR="$2"; shift 2 ;;
        --verdict)      VERDICT="$2"; shift 2 ;;
        --to)           TO="$2"; shift 2 ;;
        --from)         FROM="$2"; shift 2 ;;
        --reason)       REASON="$2"; shift 2 ;;
        --summary)      SUMMARY="$2"; shift 2 ;;
        --full-text-file) FULL_TEXT_FILE="$2"; shift 2 ;;
        *)              echo "[codex_review_post] Unknown: $1" >&2; exit 1 ;;
    esac
done

# 必須チェック
if [ -z "$TASK_ID" ] || [ -z "$VERDICT" ] || [ -z "$TO" ] || [ -z "$FROM" ]; then
    cat <<USAGE >&2
Usage: codex_review_post.sh --task-id <id> --verdict <v> --to <agent> --from <agent> [options]
  Required: --task-id --verdict --to --from
  Optional: --pr --reason --summary --full-text-file
USAGE
    exit 1
fi

# verdict 正規化
case "$VERDICT" in
    lgtm|LGTM)         VERDICT="lgtm" ;;
    minor|Minor)       VERDICT="minor" ;;
    major|Major)       VERDICT="major" ;;
    critical|Critical) VERDICT="critical" ;;
    info|Info)         VERDICT="info" ;;
    *)
        echo "[codex_review_post] ERROR: invalid --verdict (lgtm/minor/major/critical/info)" >&2
        exit 1
        ;;
esac

mkdir -p "$(dirname "$JSONL")"
touch "$JSONL"

# full text 読み込み（optional）
FULL_TEXT=""
if [ -n "$FULL_TEXT_FILE" ] && [ -f "$FULL_TEXT_FILE" ]; then
    FULL_TEXT=$(cat "$FULL_TEXT_FILE")
fi

TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# JSON 1 行を python で生成（escape を正しく）
JSON_LINE=$(
    CR_TS="$TIMESTAMP" CR_TASK_ID="$TASK_ID" CR_PR="$PR" \
    CR_VERDICT="$VERDICT" CR_FROM="$FROM" CR_REASON="$REASON" \
    CR_SUMMARY="$SUMMARY" CR_FULL="$FULL_TEXT" \
    python3 -c "
import json, os
obj = {
    'ts': os.environ['CR_TS'],
    'task_id': os.environ['CR_TASK_ID'],
    'pr': os.environ['CR_PR'] or None,
    'verdict': os.environ['CR_VERDICT'],
    'from': os.environ['CR_FROM'],
    'reason': os.environ['CR_REASON'] or None,
    'summary': os.environ['CR_SUMMARY'] or None,
    'full_text': os.environ['CR_FULL'] or None,
}
# None フィールドは落とす
obj = {k: v for k, v in obj.items() if v is not None}
print(json.dumps(obj, ensure_ascii=False))
"
)

# jsonl に append（flock で排他）
JSONL_LOCK="${JSONL}.lock"
(
    flock -w 5 201 || { echo "[codex_review_post] lock timeout" >&2; exit 1; }
    echo "$JSON_LINE" >> "$JSONL"
) 201>"$JSONL_LOCK"

# 追記後の行番号を取得
LINE_NO=$(wc -l < "$JSONL" | tr -d ' ')

# inbox pointer 生成（3 行）
PR_TAG=""
if [ -n "$PR" ]; then
    PR_TAG=" PR #${PR}"
fi

REASON_LINE=""
if [ -n "$REASON" ]; then
    REASON_LINE="
- reason: ${REASON}"
fi

POINTER_MSG="Codex QC 完了${PR_TAG} (${TASK_ID})
- verdict: ${VERDICT}${REASON_LINE}
- pointer: codex_reviews.jsonl:${LINE_NO}"

# inbox_write 実行
bash "$SCRIPT_DIR/scripts/inbox_write.sh" "$TO" "$POINTER_MSG" codex_verdict "$FROM"

echo "[codex_review_post] SUCCESS: jsonl:${LINE_NO} → ${TO}" >&2
