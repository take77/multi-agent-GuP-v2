#!/usr/bin/env bats
# test_stop_hook_e2e.bats — stop_hook_inbox.sh e2e テスト
#
# テスト構成:
#   E2E-SH-001: inbox ファイル不在 → exit 0 (停止許可)
#   E2E-SH-002: inbox が全既読 → exit 0 (停止許可)
#   E2E-SH-003: 未読あり → block JSON 出力 (decision=block)
#   E2E-SH-004: stop_hook_active=True → exit 0 (ループ防止)
#   E2E-SH-005: 完了キーワードを含む last_assistant_message → exit 0 (クラッシュなし)
#
# 注意: bats の `run cmd < file` は stdin を正しく転送しないため、
# stdin を渡す際は bash -c + printf パイプ方式を使用する。

setup_file() {
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export HOOK_SCRIPT="$PROJECT_ROOT/scripts/stop_hook_inbox.sh"

    [ -f "$HOOK_SCRIPT" ] || {
        echo "ERROR: stop_hook_inbox.sh not found at $HOOK_SCRIPT" >&2
        return 1
    }
    python3 -c "import yaml" 2>/dev/null || {
        echo "ERROR: python3-yaml is required" >&2
        return 1
    }
}

setup() {
    # CLUSTER_ID が設定されているとインボックスパスが変わるため、テスト内で無効化
    unset CLUSTER_ID

    # テスト毎に独立した tmpdir を作成 (SCRIPT_DIR として使用)
    TEST_DIR="$(mktemp -d "$BATS_TMPDIR/stop_hook_e2e.XXXXXX")"
    mkdir -p "$TEST_DIR/lib" \
             "$TEST_DIR/scripts" \
             "$TEST_DIR/config" \
             "$TEST_DIR/queue/inbox"

    # 実スクリプトをコピー (テスト対象は PROJECT_ROOT の stop_hook_inbox.sh)
    cp "$PROJECT_ROOT/lib/agent_status.sh" "$TEST_DIR/lib/"
    cp "$PROJECT_ROOT/scripts/inbox_write.sh" "$TEST_DIR/scripts/"

    # テスト用 squads.yaml (aki → captain: maho)
    cp "$PROJECT_ROOT/tests/fixtures/sample_squads.yaml" "$TEST_DIR/config/squads.yaml"

    export TEST_DIR
    export __STOP_HOOK_SCRIPT_DIR="$TEST_DIR"
    export __STOP_HOOK_AGENT_ID="aki"
    export IDLE_FLAG_DIR="$TEST_DIR"
}

teardown() {
    unset __STOP_HOOK_SCRIPT_DIR __STOP_HOOK_AGENT_ID IDLE_FLAG_DIR _HOOK_STDIN
    [ -n "${TEST_DIR:-}" ] && [ -d "${TEST_DIR:-}" ] && rm -rf "$TEST_DIR"
}

# stdin JSON を パイプ経由で渡して hook を実行するヘルパー
# bats の `run cmd < file` は stdin 転送に問題があるため、bash -c + printf を使用
# 注意: "${1:-{}}" は bash の } 解釈バグで JSON に余分な } が付くため、明示的な空チェックを使う
run_hook() {
    local json_content="${1-}"
    [ -n "$json_content" ] || json_content="{}"
    export _HOOK_STDIN="$json_content"
    run bash -c 'printf "%s" "$_HOOK_STDIN" | bash "$HOOK_SCRIPT"'
    unset _HOOK_STDIN
}

# =============================================================================
# E2E-SH-001: inbox ファイルなし → exit 0 (停止許可)
# =============================================================================

@test "E2E-SH-001: no inbox file → exit 0, no output (stop allowed)" {
    # inbox ファイルを作成しない
    run_hook '{}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# =============================================================================
# E2E-SH-002: inbox が全既読 → exit 0 (停止許可)
# =============================================================================

@test "E2E-SH-002: all-read inbox → exit 0, no block output" {
    cat > "$TEST_DIR/queue/inbox/aki.yaml" <<'YAML'
messages:
  - id: msg_001
    from: maho
    timestamp: "2026-05-12T10:00:00"
    type: task_assigned
    content: "過去タスク（既読）"
    read: true
  - id: msg_002
    from: erika
    timestamp: "2026-05-12T10:05:00"
    type: info
    content: "既読メッセージ2"
    read: true
YAML

    run_hook '{}'
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ '"decision"' ]]
}

# =============================================================================
# E2E-SH-003: 未読メッセージあり → block JSON 出力
# =============================================================================

@test "E2E-SH-003: unread messages → block JSON with decision=block" {
    cp "$PROJECT_ROOT/tests/fixtures/sample_inbox.yaml" \
       "$TEST_DIR/queue/inbox/aki.yaml"

    run_hook '{}'
    [ "$status" -eq 0 ]

    # decision: block が含まれること
    [[ "$output" =~ '"decision"' ]]
    [[ "$output" =~ 'block' ]]

    # JSON として parse できること
    python3 <<PYEOF
import json, sys
try:
    data = json.loads('''${output}''')
    assert data.get("decision") == "block", f'Expected block, got {data.get("decision")}'
    assert "reason" in data, "reason field missing"
    print("E2E-SH-003: PASS")
except Exception as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# =============================================================================
# E2E-SH-004: stop_hook_active=True → exit 0 (ループ防止)
# =============================================================================

@test "E2E-SH-004: stop_hook_active=true → exit 0, no block (loop prevention)" {
    # 未読ありの inbox を用意しても…
    cp "$PROJECT_ROOT/tests/fixtures/sample_inbox.yaml" \
       "$TEST_DIR/queue/inbox/aki.yaml"

    # stop_hook_active=True の場合は block しない
    run_hook '{"stop_hook_active": true}'
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ '"decision"' ]]
}

# =============================================================================
# E2E-SH-005: 完了キーワードあり + inbox なし → exit 0 (通知送信のみ)
# =============================================================================

@test "E2E-SH-005: completion keyword in last_assistant_message → exit 0, no crash" {
    # inbox ファイルなし（通知のみ発火、ブロックなし）
    run_hook '{"last_assistant_message": "任務完了しました。報告YAMLを更新しました。"}'
    [ "$status" -eq 0 ]
    # block JSON は出力されない
    [[ ! "$output" =~ '"decision"' ]]
}
