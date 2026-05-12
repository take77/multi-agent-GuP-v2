#!/usr/bin/env bats
# test_branch_policy.bats — lib/branch_policy.sh ユニットテスト
#
# テスト構成:
#   T-BP-001: branch_policy_query allowed — 設定済み long-lived ブランチ一覧を返す
#   T-BP-002: branch_policy_is_allowed_long_lived — main は許可ブランチ（true）
#   T-BP-003: branch_policy_is_allowed_long_lived — feat/foo は許可外（false）
#   T-BP-004: branch_policy_query short_lived_pattern — パターン文字列を返す
#   T-BP-005: branch_policy_query primary — 最初の long-lived ブランチを返す
#   T-BP-006: branch_policy_query — 存在しない settings ファイルで非ゼロ終了

setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/test_branch_policy.XXXXXX")"
    export TEST_SETTINGS="$TEST_TMPDIR/settings.yaml"
    export LIB="$PROJECT_ROOT/lib/branch_policy.sh"

    cat > "$TEST_SETTINGS" <<'YAML'
branch_policy:
  allowed_long_lived:
    - main
    - develop
  short_lived_pattern: "^(feat|fix|hotfix)/"
  max_age_seconds: 604800
  monitored_repos:
    - path: /tmp/dummy-repo
YAML
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# YAML パース / branch_policy_query
# =============================================================================

@test "T-BP-001: branch_policy_query allowed returns configured long-lived branches" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash -c "source '$LIB' && branch_policy_query allowed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"main"* ]]
    [[ "$output" == *"develop"* ]]
}

@test "T-BP-004: branch_policy_query short_lived_pattern returns configured pattern" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash -c "source '$LIB' && branch_policy_query short_lived_pattern"
    [ "$status" -eq 0 ]
    [[ "$output" == *"feat"* ]]
}

@test "T-BP-005: branch_policy_query primary returns first long-lived branch" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash -c "source '$LIB' && branch_policy_query primary"
    [ "$status" -eq 0 ]
    [ "$output" = "main" ]
}

# =============================================================================
# ブランチ名判定
# =============================================================================

@test "T-BP-002: branch_policy_is_allowed_long_lived main returns true" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash -c "source '$LIB' && branch_policy_is_allowed_long_lived main"
    [ "$status" -eq 0 ]
}

@test "T-BP-003: branch_policy_is_allowed_long_lived feat/foo returns false" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash -c "source '$LIB' && branch_policy_is_allowed_long_lived feat/foo"
    [ "$status" -ne 0 ]
}

# =============================================================================
# エッジケース
# =============================================================================

@test "T-BP-006: branch_policy_query with missing settings file exits non-zero" {
    run env BRANCH_POLICY_SETTINGS="$TEST_TMPDIR/nonexistent.yaml" \
        bash -c "source '$LIB' && branch_policy_query allowed"
    [ "$status" -ne 0 ]
}
