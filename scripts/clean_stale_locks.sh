#!/bin/bash
# clean_stale_locks.sh — queue/inbox/*.yaml.lock のstaleロックを除去する
#
# 使用方法:
#   bash scripts/clean_stale_locks.sh [inbox_dir]
#
# 引数:
#   inbox_dir  — スキャン対象ディレクトリ（省略時: プロジェクトルートの queue/inbox）
#
# stale判定ロジック:
#   flock -n（ノンブロッキング）でロック取得を試みる。
#   取得成功 → stale（誰も保持していない）→ 削除可
#   取得失敗 → active（別プロセスが保持中）→ 削除しない

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="${1:-${SCRIPT_DIR}/queue/inbox}"

# ロックファイルが見つからない場合はスキップ（エラーにしない）
if ! ls "${INBOX_DIR}"/*.yaml.lock >/dev/null 2>&1; then
    echo "[clean_stale_locks] No lock files found in ${INBOX_DIR}" >&2
    exit 0
fi

removed=0
skipped=0

for lockfile in "${INBOX_DIR}"/*.yaml.lock; do
    # ファイル存在確認（glob展開失敗対策）
    [ -f "$lockfile" ] || continue

    # flock -n: ノンブロッキングでロック取得を試みる
    # 取得成功（exit 0）→ stale → 削除
    # 取得失敗（exit 1）→ active → スキップ
    if flock -n "$lockfile" true 2>/dev/null; then
        rm -f "$lockfile"
        removed=$((removed + 1))
        echo "[clean_stale_locks] Removed stale lock: $(basename "$lockfile")" >&2
    else
        skipped=$((skipped + 1))
        echo "[clean_stale_locks] Skipped active lock: $(basename "$lockfile")" >&2
    fi
done

echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [clean_stale_locks] Done: removed=${removed}, skipped=${skipped}" >&2
