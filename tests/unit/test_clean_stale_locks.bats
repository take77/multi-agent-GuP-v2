#!/usr/bin/env bats
# test_clean_stale_locks.bats — clean_stale_locks.sh ユニットテスト
#
# テスト構成:
#   T-001: ロックファイルなし → エラーにならない（exit 0）
#   T-002: stale ロック（誰も保持していない）→ 削除される
#   T-003: active ロック（別プロセスが保持中）→ 削除されない
#   T-004: stale + active 混在 → stale のみ削除
#   T-005: 削除件数がログ出力される

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export ORIG_SCRIPT="$PROJECT_ROOT/scripts/clean_stale_locks.sh"
    [ -f "$ORIG_SCRIPT" ] || return 1
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/clean_stale_locks_test.XXXXXX")"
    export TEST_INBOX_DIR="$TEST_TMPDIR/inbox"
    mkdir -p "$TEST_INBOX_DIR"
}

teardown() {
    [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# T-001: ロックファイルなし → exit 0（エラーにならない）
# =============================================================================

@test "T-001: no lock files → exit 0 without error" {
    run bash "$ORIG_SCRIPT" "$TEST_INBOX_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No lock files found" ]]
}

# =============================================================================
# T-002: stale ロック → 削除される
# =============================================================================

@test "T-002: stale lock (no holder) → deleted" {
    touch "$TEST_INBOX_DIR/foo.yaml.lock"
    touch "$TEST_INBOX_DIR/bar.yaml.lock"

    run bash "$ORIG_SCRIPT" "$TEST_INBOX_DIR"
    [ "$status" -eq 0 ]

    # ファイルが削除されていること
    [ ! -f "$TEST_INBOX_DIR/foo.yaml.lock" ]
    [ ! -f "$TEST_INBOX_DIR/bar.yaml.lock" ]

    # removed=2 がログに出ること
    [[ "$output" =~ "removed=2" ]]
}

# =============================================================================
# T-003: active ロック（別プロセスが保持中）→ 削除されない
# =============================================================================

@test "T-003: active lock (held by another process) → not deleted" {
    local lockfile="$TEST_INBOX_DIR/active.yaml.lock"
    touch "$lockfile"

    # バックグラウンドプロセスでロックを保持し続ける
    flock "$lockfile" sleep 5 &
    local lock_pid=$!

    # 少し待ってロックが確立されるのを確認
    sleep 0.2

    run bash "$ORIG_SCRIPT" "$TEST_INBOX_DIR"
    [ "$status" -eq 0 ]

    # ファイルが削除されていないこと
    [ -f "$lockfile" ]

    # skipped=1 がログに出ること
    [[ "$output" =~ "skipped=1" ]]

    # クリーンアップ
    kill $lock_pid 2>/dev/null || true
    wait $lock_pid 2>/dev/null || true
}

# =============================================================================
# T-004: stale + active 混在 → stale のみ削除
# =============================================================================

@test "T-004: mixed stale and active → only stale deleted" {
    local stale="$TEST_INBOX_DIR/stale.yaml.lock"
    local active="$TEST_INBOX_DIR/active.yaml.lock"
    touch "$stale"
    touch "$active"

    # active ロックを別プロセスで保持
    flock "$active" sleep 5 &
    local lock_pid=$!
    sleep 0.2

    run bash "$ORIG_SCRIPT" "$TEST_INBOX_DIR"
    [ "$status" -eq 0 ]

    # stale は削除、active は残存
    [ ! -f "$stale" ]
    [ -f "$active" ]

    [[ "$output" =~ "removed=1" ]]
    [[ "$output" =~ "skipped=1" ]]

    kill $lock_pid 2>/dev/null || true
    wait $lock_pid 2>/dev/null || true
}

# =============================================================================
# T-005: 削除件数がログ出力される（removed= の数値確認）
# =============================================================================

@test "T-005: log output contains removal count" {
    touch "$TEST_INBOX_DIR/lock1.yaml.lock"
    touch "$TEST_INBOX_DIR/lock2.yaml.lock"
    touch "$TEST_INBOX_DIR/lock3.yaml.lock"

    run bash "$ORIG_SCRIPT" "$TEST_INBOX_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "removed=3" ]]
    [[ "$output" =~ "skipped=0" ]]
}
