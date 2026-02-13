#!/usr/bin/env bats
# test_cli_adapter.bats — cli_adapter.sh ユニットテスト
# Multi-CLI統合設計書 §4.1 準拠

# --- セットアップ ---

setup() {
    # テスト用のtmpディレクトリ
    TEST_TMP="$(mktemp -d)"

    # プロジェクトルート
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # デフォルトsettings（cliセクションなし = 後方互換テスト）
    cat > "${TEST_TMP}/settings_none.yaml" << 'YAML'
language: ja
shell: bash
display_mode: shout
YAML

    # claude only settings
    cat > "${TEST_TMP}/settings_claude_only.yaml" << 'YAML'
cli:
  default: claude
YAML

    # mixed CLI settings (dict形式)
    cat > "${TEST_TMP}/settings_mixed.yaml" << 'YAML'
cli:
  default: claude
  agents:
    captain:
      type: claude
      model: opus
    vice_captain:
      type: claude
      model: opus
    member1:
      type: claude
      model: sonnet
    member2:
      type: claude
      model: sonnet
    member3:
      type: claude
      model: sonnet
    member4:
      type: claude
      model: sonnet
    member5:
      type: codex
    member6:
      type: codex
    member7:
      type: copilot
    member8:
      type: copilot
YAML

    # 文字列形式のagent設定
    cat > "${TEST_TMP}/settings_string_agents.yaml" << 'YAML'
cli:
  default: claude
  agents:
    member5: codex
    member7: copilot
YAML

    # 不正CLI名
    cat > "${TEST_TMP}/settings_invalid_cli.yaml" << 'YAML'
cli:
  default: claudee
  agents:
    member1: invalid_cli
YAML

    # codexデフォルト
    cat > "${TEST_TMP}/settings_codex_default.yaml" << 'YAML'
cli:
  default: codex
YAML

    # 空ファイル
    cat > "${TEST_TMP}/settings_empty.yaml" << 'YAML'
YAML

    # YAML構文エラー
    cat > "${TEST_TMP}/settings_broken.yaml" << 'YAML'
cli:
  default: [broken yaml
  agents: {{invalid
YAML

    # モデル指定付き
    cat > "${TEST_TMP}/settings_with_models.yaml" << 'YAML'
cli:
  default: claude
  agents:
    member1:
      type: claude
      model: haiku
    member5:
      type: codex
      model: gpt-5
models:
  vice_captain: sonnet
YAML

    # kimi CLI settings
    cat > "${TEST_TMP}/settings_kimi.yaml" << 'YAML'
cli:
  default: claude
  agents:
    member3:
      type: kimi
      model: k2.5
    member4:
      type: kimi
YAML

    # kimi default settings
    cat > "${TEST_TMP}/settings_kimi_default.yaml" << 'YAML'
cli:
  default: kimi
YAML
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ヘルパー: 特定のsettings.yamlでcli_adapterをロード
load_adapter_with() {
    local settings_file="$1"
    export CLI_ADAPTER_SETTINGS="$settings_file"
    source "${PROJECT_ROOT}/lib/cli_adapter.sh"
}

# =============================================================================
# get_cli_type テスト
# =============================================================================

# --- 正常系 ---

@test "get_cli_type: cliセクションなし → claude (後方互換)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_cli_type "captain")
    [ "$result" = "claude" ]
}

@test "get_cli_type: claude only設定 → claude" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(get_cli_type "member1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed設定 captain → claude" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "captain")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed設定 member5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "member5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: mixed設定 member7 → copilot" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "member7")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: mixed設定 member1 → claude (個別設定)" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "member1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: 文字列形式 member5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_string_agents.yaml"
    result=$(get_cli_type "member5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 文字列形式 member7 → copilot" {
    load_adapter_with "${TEST_TMP}/settings_string_agents.yaml"
    result=$(get_cli_type "member7")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: kimi設定 member3 → kimi" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_cli_type "member3")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: kimi設定 member4 → kimi (モデル指定なし)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_cli_type "member4")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: kimiデフォルト設定 → kimi" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_cli_type "member1")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: 未定義agent → default継承" {
    load_adapter_with "${TEST_TMP}/settings_codex_default.yaml"
    result=$(get_cli_type "member3")
    [ "$result" = "codex" ]
}

@test "get_cli_type: 空agent_id → claude" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "")
    [ "$result" = "claude" ]
}

# --- 全member パターン ---

@test "get_cli_type: mixed設定 member1-8全パターン" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    [ "$(get_cli_type member1)" = "claude" ]
    [ "$(get_cli_type member2)" = "claude" ]
    [ "$(get_cli_type member3)" = "claude" ]
    [ "$(get_cli_type member4)" = "claude" ]
    [ "$(get_cli_type member5)" = "codex" ]
    [ "$(get_cli_type member6)" = "codex" ]
    [ "$(get_cli_type member7)" = "copilot" ]
    [ "$(get_cli_type member8)" = "copilot" ]
}

# --- エラー系 ---

@test "get_cli_type: 不正CLI名 → claude フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "member1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: 不正default → claude フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "vice_captain")
    [ "$result" = "claude" ]
}

@test "get_cli_type: 空YAMLファイル → claude" {
    load_adapter_with "${TEST_TMP}/settings_empty.yaml"
    result=$(get_cli_type "captain")
    [ "$result" = "claude" ]
}

@test "get_cli_type: YAML構文エラー → claude" {
    load_adapter_with "${TEST_TMP}/settings_broken.yaml"
    result=$(get_cli_type "member1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: 存在しないファイル → claude" {
    load_adapter_with "/nonexistent/path/settings.yaml"
    result=$(get_cli_type "captain")
    [ "$result" = "claude" ]
}

# =============================================================================
# build_cli_command テスト
# =============================================================================

@test "build_cli_command: claude + model → claude --model opus --dangerously-skip-permissions" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "captain")
    [ "$result" = "claude --model opus --dangerously-skip-permissions" ]
}

@test "build_cli_command: codex → codex --dangerously-bypass-approvals-and-sandbox --no-alt-screen" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "member5")
    [ "$result" = "codex --dangerously-bypass-approvals-and-sandbox --no-alt-screen" ]
}

@test "build_cli_command: copilot → copilot --yolo" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "member7")
    [ "$result" = "copilot --yolo" ]
}

@test "build_cli_command: kimi + model → kimi --yolo --model k2.5" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(build_cli_command "member3")
    [ "$result" = "kimi --yolo --model k2.5" ]
}

@test "build_cli_command: kimi (モデル指定なし) → kimi --yolo --model k2.5" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(build_cli_command "member4")
    [ "$result" = "kimi --yolo --model k2.5" ]
}

@test "build_cli_command: cliセクションなし → claude フォールバック" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(build_cli_command "member1")
    [[ "$result" == claude*--dangerously-skip-permissions ]]
}

@test "build_cli_command: settings読取失敗 → claude フォールバック" {
    load_adapter_with "/nonexistent/settings.yaml"
    result=$(build_cli_command "member1")
    [[ "$result" == claude*--dangerously-skip-permissions ]]
}

# =============================================================================
# get_instruction_file テスト
# =============================================================================

@test "get_instruction_file: captain + claude → instructions/captain.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "captain")
    [ "$result" = "instructions/captain.md" ]
}

@test "get_instruction_file: vice_captain + claude → instructions/vice_captain.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "vice_captain")
    [ "$result" = "instructions/vice_captain.md" ]
}

@test "get_instruction_file: member1 + claude → instructions/member.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "member1")
    [ "$result" = "instructions/member.md" ]
}

@test "get_instruction_file: member5 + codex → instructions/codex-member.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "member5")
    [ "$result" = "instructions/codex-member.md" ]
}

@test "get_instruction_file: member7 + copilot → .github/copilot-instructions-member.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "member7")
    [ "$result" = ".github/copilot-instructions-member.md" ]
}

@test "get_instruction_file: member3 + kimi → instructions/generated/kimi-member.md" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_instruction_file "member3")
    [ "$result" = "instructions/generated/kimi-member.md" ]
}

@test "get_instruction_file: captain + kimi → instructions/generated/kimi-captain.md" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_instruction_file "captain")
    [ "$result" = "instructions/generated/kimi-captain.md" ]
}

@test "get_instruction_file: cli_type引数で明示指定 (codex)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_instruction_file "captain" "codex")
    [ "$result" = "instructions/codex-captain.md" ]
}

@test "get_instruction_file: cli_type引数で明示指定 (copilot)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_instruction_file "vice_captain" "copilot")
    [ "$result" = ".github/copilot-instructions-vice_captain.md" ]
}

@test "get_instruction_file: 全CLI × 全role組み合わせ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # claude
    [ "$(get_instruction_file captain claude)" = "instructions/captain.md" ]
    [ "$(get_instruction_file vice_captain claude)" = "instructions/vice_captain.md" ]
    [ "$(get_instruction_file member1 claude)" = "instructions/member.md" ]
    # codex
    [ "$(get_instruction_file captain codex)" = "instructions/codex-captain.md" ]
    [ "$(get_instruction_file vice_captain codex)" = "instructions/codex-vice_captain.md" ]
    [ "$(get_instruction_file member3 codex)" = "instructions/codex-member.md" ]
    # copilot
    [ "$(get_instruction_file captain copilot)" = ".github/copilot-instructions-captain.md" ]
    [ "$(get_instruction_file vice_captain copilot)" = ".github/copilot-instructions-vice_captain.md" ]
    [ "$(get_instruction_file member5 copilot)" = ".github/copilot-instructions-member.md" ]
    # kimi
    [ "$(get_instruction_file captain kimi)" = "instructions/generated/kimi-captain.md" ]
    [ "$(get_instruction_file vice_captain kimi)" = "instructions/generated/kimi-vice_captain.md" ]
    [ "$(get_instruction_file member7 kimi)" = "instructions/generated/kimi-member.md" ]
}

@test "get_instruction_file: 不明なagent_id → 空文字 + return 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run get_instruction_file "unknown_agent"
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_cli_availability テスト
# =============================================================================

@test "validate_cli_availability: claude → 0 (インストール済み)" {
    command -v claude >/dev/null 2>&1 || skip "claude not installed (CI environment)"
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "claude"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: 不正CLI名 → 1 + エラーメッセージ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "invalid_type"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown CLI type"* ]]
}

@test "validate_cli_availability: 空文字 → 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability ""
    [ "$status" -eq 1 ]
}

@test "validate_cli_availability: codex mock (PATH操作)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # モックcodexコマンドを作成
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/codex"
    chmod +x "${TEST_TMP}/bin/codex"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "codex"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: copilot mock (PATH操作)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/copilot"
    chmod +x "${TEST_TMP}/bin/copilot"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "copilot"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: kimi-cli mock (PATH操作)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/kimi-cli"
    chmod +x "${TEST_TMP}/bin/kimi-cli"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "kimi"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: kimi mock (PATH操作)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/kimi"
    chmod +x "${TEST_TMP}/bin/kimi"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "kimi"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: codex未インストール → 1 + エラーメッセージ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # PATHからcodexを除外（空PATHは危険なのでminimal PATHを設定）
    PATH="/usr/bin:/bin" run validate_cli_availability "codex"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Codex CLI not found"* ]]
}

@test "validate_cli_availability: kimi未インストール → 1 + エラーメッセージ" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    PATH="/usr/bin:/bin" run validate_cli_availability "kimi"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Kimi CLI not found"* ]]
}

# =============================================================================
# get_agent_model テスト
# =============================================================================

@test "get_agent_model: cliセクションなし captain → opus (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "captain")
    [ "$result" = "opus" ]
}

@test "get_agent_model: cliセクションなし vice_captain → opus (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "vice_captain")
    [ "$result" = "opus" ]
}

@test "get_agent_model: cliセクションなし member1 → sonnet (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "member1")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: cliセクションなし member5 → opus (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "member5")
    [ "$result" = "opus" ]
}

@test "get_agent_model: YAML指定 member1 → haiku (オーバーライド)" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "member1")
    [ "$result" = "haiku" ]
}

@test "get_agent_model: modelsセクションから取得 vice_captain → sonnet" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "vice_captain")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: codexエージェントのmodel member5 → gpt-5" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "member5")
    [ "$result" = "gpt-5" ]
}

@test "get_agent_model: 未知agent → sonnet (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "unknown_agent")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: kimi CLI member3 → k2.5 (YAML指定)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_agent_model "member3")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI member4 → k2.5 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_agent_model "member4")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI captain → k2.5 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_agent_model "captain")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI vice_captain → k2.5 (デフォルト)" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_agent_model "vice_captain")
    [ "$result" = "k2.5" ]
}
