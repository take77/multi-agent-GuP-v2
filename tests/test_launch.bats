#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  cd "$PROJECT_ROOT"
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
