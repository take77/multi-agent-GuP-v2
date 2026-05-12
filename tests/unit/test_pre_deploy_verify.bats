#!/usr/bin/env bats
# test_pre_deploy_verify.bats — scripts/pre_deploy_verify.sh ユニットテスト
#
# テスト構成:
#   T-PD-001: primary branch (main) で deploy gate を通過する
#   T-PD-002: non-primary branch で abort（非ゼロ終了）する
#   T-PD-003: git repo でないパスで abort（非ゼロ終了）する

setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT="$PROJECT_ROOT/scripts/pre_deploy_verify.sh"
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/test_pre_deploy.XXXXXX")"
    export TEST_REPO="$TEST_TMPDIR/repo"
    export TEST_SETTINGS="$TEST_TMPDIR/settings.yaml"

    mkdir -p "$TEST_REPO"
    git -C "$TEST_REPO" init -q
    git -C "$TEST_REPO" config user.email "test@example.com"
    git -C "$TEST_REPO" config user.name "Test"
    echo "init" > "$TEST_REPO/README.md"
    git -C "$TEST_REPO" add README.md
    git -C "$TEST_REPO" commit -q -m "init"
    git -C "$TEST_REPO" branch -M main

    cat > "$TEST_SETTINGS" <<YAML
branch_policy:
  allowed_long_lived:
    - main
  short_lived_pattern: "^(feat|fix)/"
  max_age_seconds: 604800
  monitored_repos:
    - path: $TEST_REPO
YAML
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# ブランチ検証
# =============================================================================

@test "T-PD-001: passes on primary branch main" {
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash "$SCRIPT" --repo "$TEST_REPO" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] deploy branch confirmed: main"* ]]
}

@test "T-PD-002: aborts on non-primary branch" {
    git -C "$TEST_REPO" checkout -q -b feat/not-main
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash "$SCRIPT" --repo "$TEST_REPO" --dry-run
    [ "$status" -ne 0 ]
}

# =============================================================================
# 異常検知
# =============================================================================

@test "T-PD-003: aborts when repo path is not a git repository" {
    local non_git="$TEST_TMPDIR/not-a-repo"
    mkdir -p "$non_git"
    run env BRANCH_POLICY_SETTINGS="$TEST_SETTINGS" \
        bash "$SCRIPT" --repo "$non_git" --dry-run
    [ "$status" -ne 0 ]
}
