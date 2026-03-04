#!/usr/bin/env bash
# init_runtime_data.sh — 運用データファイルの初期化スクリプト
# git pull 後に必要なファイルが存在しない場合、初期構造で自動生成する。
# 既存ファイルは絶対に上書きしない。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# テストから PROJECT_ROOT を上書きできるようにする（未設定時はスクリプト位置から自動解決）
: "${PROJECT_ROOT:="$(cd "$SCRIPT_DIR/.." && pwd)"}"
SQUADS_YAML="$PROJECT_ROOT/config/squads.yaml"

# ----------------------------------------------------------------
# ユーティリティ
# ----------------------------------------------------------------

# ファイルを作成（存在しない場合のみ）
create_if_missing() {
  local path="$1"
  local content="$2"
  if [ ! -f "$path" ]; then
    mkdir -p "$(dirname "$path")"
    printf '%s' "$content" > "$path"
    echo "[created] $path"
  else
    echo "[skip]    $path (already exists)"
  fi
}

# config/squads.yaml からエージェント一覧を取得（yq なし版）
get_all_agents() {
  if ! [ -f "$SQUADS_YAML" ]; then
    echo "ERROR: $SQUADS_YAML が見つかりません" >&2
    return 1
  fi

  if command -v yq > /dev/null 2>&1; then
    # yq が使える場合（CRLF も自動処理）
    yq e '.squads | to_entries | .[] | .value | (.captain, .vice_captain, .members[])' "$SQUADS_YAML" \
      | tr -d '\r'
  else
    # grep/awk でパース（yq なし）
    # CRLF ファイルにも対応するため tr -d '\r' を末尾に付ける
    # captain: / vice_captain: 行（4スペースインデント）
    grep -E '^    (captain|vice_captain): ' "$SQUADS_YAML" | awk '{print $2}' | tr -d '\r'
    # members リスト（6スペース + "- " で始まる行、末尾 \r は tr で除去）
    grep -E '^      - [a-zA-Z_]' "$SQUADS_YAML" | awk '{print $2}' | tr -d '\r'
  fi
}

# ----------------------------------------------------------------
# 1. queue/ntfy_inbox.yaml
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/queue/ntfy_inbox.yaml" \
  "messages: []
"

# ----------------------------------------------------------------
# 2. queue/inbox/{agent}.yaml（全エージェント分）
# ----------------------------------------------------------------
while IFS= read -r agent; do
  [ -z "$agent" ] && continue
  create_if_missing \
    "$PROJECT_ROOT/queue/inbox/${agent}.yaml" \
    "messages: []
"
done < <(get_all_agents)

# ----------------------------------------------------------------
# 3. saytask/tasks.yaml
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/saytask/tasks.yaml" \
  "tasks: []
"

# ----------------------------------------------------------------
# 4. saytask/counter.yaml
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/saytask/counter.yaml" \
  "next_id: 1
"

# ----------------------------------------------------------------
# 5. saytask/streaks.yaml
# ----------------------------------------------------------------
STREAKS_SAMPLE="$PROJECT_ROOT/saytask/streaks.yaml.sample"
STREAKS_DEST="$PROJECT_ROOT/saytask/streaks.yaml"
if [ ! -f "$STREAKS_DEST" ]; then
  mkdir -p "$(dirname "$STREAKS_DEST")"
  if [ -f "$STREAKS_SAMPLE" ]; then
    cp "$STREAKS_SAMPLE" "$STREAKS_DEST"
    echo "[created] $STREAKS_DEST (from sample)"
  else
    printf '%s' 'streak:
  current: 0
  last_date: ""
  longest: 0
today:
  frog: ""
  completed: 0
  total: 0
' > "$STREAKS_DEST"
    echo "[created] $STREAKS_DEST"
  fi
else
  echo "[skip]    $STREAKS_DEST (already exists)"
fi

# ----------------------------------------------------------------
# 6. coordination/heartbeat_{darjeeling,katyusha,kay,maho}.yaml
# ----------------------------------------------------------------
for squad in darjeeling katyusha kay maho; do
  create_if_missing \
    "$PROJECT_ROOT/coordination/heartbeat_${squad}.yaml" \
    'status: inactive
last_heartbeat: ""
'
done

# ----------------------------------------------------------------
# 7. coordination/session_state.yaml
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/coordination/session_state.yaml" \
  'status: inactive
started_at: ""
'

# ----------------------------------------------------------------
# 8. coordination/commander_to_staff.yaml
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/coordination/commander_to_staff.yaml" \
  '# Commander → Chief of Staff queue
commands: []
'

# ----------------------------------------------------------------
# 9. coordination/master_dashboard.md
# ----------------------------------------------------------------
create_if_missing \
  "$PROJECT_ROOT/coordination/master_dashboard.md" \
  "# 総合戦況報告
最終更新: (未初期化)
"

echo ""
echo "初期化完了。"
