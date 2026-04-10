#!/usr/bin/env bash
# inbox_archive.sh — inboxの read:true メッセージをアーカイブに退避する
# Usage:
#   bash scripts/inbox_archive.sh              # 全inbox対象
#   bash scripts/inbox_archive.sh darjeeling   # 特定agentのみ（オプション）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="$SCRIPT_DIR/queue/inbox"
ARCHIVE_DIR="$INBOX_DIR/archive"
TODAY=$(date "+%Y-%m-%d")

# アーカイブディレクトリが存在しない場合は自動作成
mkdir -p "$ARCHIVE_DIR"

# 処理対象のinboxファイルを決定
if [ -n "$1" ]; then
    # 特定エージェントのみ
    TARGETS=("$INBOX_DIR/$1.yaml")
else
    # 全inbox対象（.lockファイルは除外）
    mapfile -t TARGETS < <(find -L "$INBOX_DIR" -maxdepth 1 -name "*.yaml" ! -name "*.lock" | sort)
fi

for INBOX in "${TARGETS[@]}"; do
    # ファイルが存在しない場合はスキップ
    if [ ! -f "$INBOX" ]; then
        echo "[inbox_archive] SKIP: $INBOX not found" >&2
        continue
    fi

    # ファイル名からエージェント名を取得（archivedサブdir内のファイルはスキップ）
    BASENAME=$(basename "$INBOX" .yaml)
    ARCHIVE_FILE="$ARCHIVE_DIR/${TODAY}_${BASENAME}.yaml"
    LOCKFILE="${INBOX}.lock"

    # flockで排他ロック（inbox_write.sh と同じロックファイルを使用）
    (
        flock -w 10 200 || {
            echo "[inbox_archive] Lock timeout for $INBOX, skipping" >&2
            exit 0
        }

        python3 -c "
import yaml, sys, os, tempfile

inbox_path = '$INBOX'
archive_path = '$ARCHIVE_FILE'

try:
    # inbox を読み込む
    with open(inbox_path) as f:
        content = f.read().strip()

    if not content:
        sys.exit(0)

    data = yaml.safe_load(content)

    # 空またはNoneの場合はスキップ
    if not data or not isinstance(data, dict):
        sys.exit(0)

    messages = data.get('messages', [])

    # メッセージがない場合はスキップ
    if not messages:
        sys.exit(0)

    # read:true と read:false に分類
    to_archive = [m for m in messages if m.get('read', False) == True]
    to_keep = [m for m in messages if m.get('read', False) == False]

    # アーカイブ対象がない場合はスキップ
    if not to_archive:
        sys.exit(0)

    agent_name = os.path.basename(inbox_path).replace('.yaml', '')
    print(f'[inbox_archive] {agent_name}: archiving {len(to_archive)} message(s)', file=sys.stderr)

    # アーカイブファイルへ追記（同日に複数回実行された場合はappend）
    archive_data = {'messages': []}
    if os.path.exists(archive_path):
        with open(archive_path) as f:
            existing = yaml.safe_load(f)
        if existing and isinstance(existing, dict):
            archive_data = existing
        if not archive_data.get('messages'):
            archive_data['messages'] = []

    archive_data['messages'].extend(to_archive)

    # アーカイブファイルをアトミックに書き込む
    archive_dir = os.path.dirname(archive_path)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=archive_dir, suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            yaml.dump(archive_data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path, archive_path)
    except:
        os.unlink(tmp_path)
        raise

    # inbox本体を read:false のメッセージのみに更新
    data['messages'] = to_keep

    tmp_fd2, tmp_path2 = tempfile.mkstemp(dir=os.path.dirname(inbox_path), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd2, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path2, inbox_path)
    except:
        os.unlink(tmp_path2)
        raise

except Exception as e:
    print(f'[inbox_archive] ERROR processing $INBOX: {e}', file=sys.stderr)
    sys.exit(1)
"
    ) 200>"$LOCKFILE"
done

echo "[inbox_archive] Done." >&2
