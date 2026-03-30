#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  cd "$PROJECT_ROOT"
}

# ── パーサー抽出ヘルパー ──
# gup_v2_launch.sh から引数パース部分のみ切り出して安全に実行する。
# tmux 操作や source は一切含まない。
run_parser() {
  local script="$PROJECT_ROOT/gup_v2_launch.sh"
  local tmpscript
  tmpscript=$(mktemp)

  {
    echo '#!/bin/bash'
    # 変数初期値（SETUP_ONLY=false ～ WORKTREE_CMD_ID="" のブロック）
    sed -n '/^SETUP_ONLY=false$/,/^WORKTREE_CMD_ID=""/p' "$script"
    echo ''
    # while ループ（引数パース）
    # "while [[ $# -gt 0 ]]; do" から対応する "done" まで
    sed -n '/^while \[\[ \$# -gt 0 \]\]; do$/,/^done$/p' "$script"
    echo ''
    # 結果出力
    echo 'echo "WORKTREE_MODE=$WORKTREE_MODE"'
    echo 'echo "WORKTREE_CMD_ID=$WORKTREE_CMD_ID"'
    echo 'echo "SETUP_ONLY=$SETUP_ONLY"'
    echo 'echo "CLUSTER_MODE=$CLUSTER_MODE"'
    echo 'echo "CLEAN_MODE=$CLEAN_MODE"'
    echo 'echo "KESSEN_MODE=$KESSEN_MODE"'
    echo 'echo "SILENT_MODE=$SILENT_MODE"'
    echo 'echo "AGENT_TEAMS_MODE=$AGENT_TEAMS_MODE"'
  } > "$tmpscript"

  chmod +x "$tmpscript"
  run bash "$tmpscript" "$@"
  rm -f "$tmpscript"
}

@test "ヘルプに --agent-teams が表示される" {
  ./gup_v2_launch.sh -h | grep -q "\-\-agent-teams"
}

@test ".claude/settings.json の env から環境変数を読み取れる" {
  # テスト用の一時ディレクトリを作成
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/.claude"

  # テスト用の設定ファイルを作成
  cat > "$TEST_DIR/.claude/settings.json" <<'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF

  # gup_v2_launch.sh の該当部分をテスト用にコピー（環境変数読み取りロジックのみ）
  cat > "$TEST_DIR/test_env_read.sh" <<'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AT_ENV=""

if [ -z "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]; then
    SETTINGS_FILE="$SCRIPT_DIR/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            AT_ENV=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' "$SETTINGS_FILE" 2>/dev/null)
        else
            AT_ENV=$(grep -o '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)"/\1/')
        fi
        if [ -n "$AT_ENV" ]; then
            export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="$AT_ENV"
            echo "SUCCESS: $AT_ENV"
        else
            echo "FAIL: env not found in JSON"
        fi
    else
        echo "FAIL: settings.json not found"
    fi
else
    echo "SUCCESS: ${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS}"
fi
EOF

  chmod +x "$TEST_DIR/test_env_read.sh"

  # 環境変数をクリアして実行
  unset CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
  result=$("$TEST_DIR/test_env_read.sh")

  # クリーンアップ
  rm -rf "$TEST_DIR"

  # 検証
  echo "$result" | grep -q "SUCCESS: 1"
}

@test "ヘルプに --worktree が表示される" {
  ./gup_v2_launch.sh -h | grep -q "\-\-worktree"
}

# ── パーサーテスト（tmux 干渉なし） ──

@test "パーサー: --worktree 単体 → WORKTREE_MODE=true, CMD_ID空" {
  run_parser --worktree
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE_MODE=true"* ]]
  [[ "$output" == *'WORKTREE_CMD_ID='* ]]
  # CMD_ID が空であること（=の後に値がない）
  echo "$output" | grep -q '^WORKTREE_CMD_ID=$'
}

@test "パーサー: --worktree cmd_160 → WORKTREE_MODE=true, CMD_ID=cmd_160" {
  run_parser --worktree cmd_160
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE_MODE=true"* ]]
  [[ "$output" == *"WORKTREE_CMD_ID=cmd_160"* ]]
}

@test "パーサー: --worktree -s → WORKTREE_MODE=true, SETUP_ONLY=true" {
  run_parser --worktree -s
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE_MODE=true"* ]]
  [[ "$output" == *"SETUP_ONLY=true"* ]]
}

@test "パーサー: --worktree cmd_160 -s → 全フラグ正しく設定" {
  run_parser --worktree cmd_160 -s
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE_MODE=true"* ]]
  [[ "$output" == *"WORKTREE_CMD_ID=cmd_160"* ]]
  [[ "$output" == *"SETUP_ONLY=true"* ]]
}

@test "パーサー: 不明なオプション → exit 1 + エラーメッセージ" {
  run_parser --nonexistent-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"不明なオプション"* ]]
}

@test "パーサー: --worktree と --cluster の組み合わせ → 両方設定" {
  run_parser --worktree cmd_160 --cluster darjeeling
  [ "$status" -eq 0 ]
  [[ "$output" == *"WORKTREE_MODE=true"* ]]
  [[ "$output" == *"WORKTREE_CMD_ID=cmd_160"* ]]
  [[ "$output" == *"CLUSTER_MODE=darjeeling"* ]]
}
