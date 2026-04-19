#!/usr/bin/env bash
# inbox_archive.sh — inbox の read:true メッセージをアーカイブに退避する
# Usage:
#   bash scripts/inbox_archive.sh                    # 全 inbox 対象（デフォルト閾値 / retention）
#   bash scripts/inbox_archive.sh darjeeling         # 特定 agent のみ
#   bash scripts/inbox_archive.sh --keep-recent 5    # 直近 read 5 件は inbox に残す
#   bash scripts/inbox_archive.sh --threshold 30     # メッセージ総数 30 以上の inbox のみアーカイブ
#   bash scripts/inbox_archive.sh --all              # 閾値無視、全 inbox を即アーカイブ（従来挙動）
#
# T5（2026-04-19 制定）: retention ＋ threshold で inbox bloat を自動抑制。
# inbox_write.sh から総数閾値超過時に自動で呼ばれる。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INBOX_DIR="$SCRIPT_DIR/queue/inbox"
ARCHIVE_DIR="$INBOX_DIR/archive"
TODAY=$(date "+%Y-%m-%d")

# デフォルト設定
KEEP_RECENT=10      # 直近 read メッセージを何件 inbox に残すか（直近 context 保持）
THRESHOLD=20        # メッセージ総数がこの値以上の inbox のみアーカイブ対象
FORCE_ALL=0         # --all 時: 閾値無視
TARGET_AGENT=""

# 引数パース
while [ $# -gt 0 ]; do
    case "$1" in
        --keep-recent)
            KEEP_RECENT="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --all)
            FORCE_ALL=1
            THRESHOLD=0
            shift
            ;;
        -*)
            echo "[inbox_archive] Unknown flag: $1" >&2
            exit 1
            ;;
        *)
            TARGET_AGENT="$1"
            shift
            ;;
    esac
done

# アーカイブディレクトリ作成
mkdir -p "$ARCHIVE_DIR"

# 処理対象のinboxファイルを決定
if [ -n "$TARGET_AGENT" ]; then
    TARGETS=("$INBOX_DIR/${TARGET_AGENT}.yaml")
else
    mapfile -t TARGETS < <(find -L "$INBOX_DIR" -maxdepth 1 -name "*.yaml" ! -name "*.lock" | sort)
fi

for INBOX in "${TARGETS[@]}"; do
    if [ ! -f "$INBOX" ]; then
        echo "[inbox_archive] SKIP: $INBOX not found" >&2
        continue
    fi

    BASENAME=$(basename "$INBOX" .yaml)
    ARCHIVE_FILE="$ARCHIVE_DIR/${TODAY}_${BASENAME}.yaml"
    LOCKFILE="${INBOX}.lock"

    (
        flock -w 10 200 || {
            echo "[inbox_archive] Lock timeout for $INBOX, skipping" >&2
            exit 0
        }

        IA_INBOX="$INBOX" IA_ARCHIVE="$ARCHIVE_FILE" \
        IA_KEEP_RECENT="$KEEP_RECENT" IA_THRESHOLD="$THRESHOLD" \
        python3 -c "
import yaml, sys, os, tempfile

inbox_path = os.environ['IA_INBOX']
archive_path = os.environ['IA_ARCHIVE']
keep_recent = int(os.environ['IA_KEEP_RECENT'])
threshold = int(os.environ['IA_THRESHOLD'])

try:
    with open(inbox_path) as f:
        content = f.read().strip()
    if not content:
        sys.exit(0)

    data = yaml.safe_load(content)
    if not data or not isinstance(data, dict):
        sys.exit(0)

    messages = data.get('messages', []) or []
    if not messages:
        sys.exit(0)

    # 閾値: メッセージ総数が threshold 未満ならスキップ
    if len(messages) < threshold:
        sys.exit(0)

    # read:true を時系列で分離、直近 keep_recent 件は inbox に残す
    read_msgs = [m for m in messages if m.get('read', False) == True]
    unread_msgs = [m for m in messages if m.get('read', False) == False]

    if len(read_msgs) <= keep_recent:
        # アーカイブ対象が十分な量でなければスキップ
        sys.exit(0)

    to_archive = read_msgs[:-keep_recent] if keep_recent > 0 else read_msgs
    keep_read = read_msgs[-keep_recent:] if keep_recent > 0 else []

    agent_name = os.path.basename(inbox_path).replace('.yaml', '')
    print(f'[inbox_archive] {agent_name}: archiving {len(to_archive)} (keep recent {len(keep_read)}, unread {len(unread_msgs)})', file=sys.stderr)

    # アーカイブファイルへ append
    archive_data = {'messages': []}
    if os.path.exists(archive_path):
        with open(archive_path) as f:
            existing = yaml.safe_load(f)
        if existing and isinstance(existing, dict):
            archive_data = existing
        if not archive_data.get('messages'):
            archive_data['messages'] = []

    archive_data['messages'].extend(to_archive)

    archive_dir = os.path.dirname(archive_path)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=archive_dir, suffix='.tmp')
    try:
        with os.fdopen(tmp_fd, 'w') as f:
            yaml.dump(archive_data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path, archive_path)
    except:
        os.unlink(tmp_path)
        raise

    # inbox 更新: unread + 直近 read (keep_recent 件)
    data['messages'] = unread_msgs + keep_read

    tmp_fd2, tmp_path2 = tempfile.mkstemp(dir=os.path.dirname(inbox_path), suffix='.tmp')
    try:
        with os.fdopen(tmp_fd2, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path2, inbox_path)
    except:
        os.unlink(tmp_path2)
        raise

except Exception as e:
    print(f'[inbox_archive] ERROR processing {inbox_path}: {e}', file=sys.stderr)
    sys.exit(1)
"
    ) 200>"$LOCKFILE"
done

echo "[inbox_archive] Done (threshold=${THRESHOLD}, keep_recent=${KEEP_RECENT})." >&2
