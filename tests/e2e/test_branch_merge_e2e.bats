#!/usr/bin/env bats
# test_branch_merge_e2e.bats — auto_merge_short_lived.sh e2e テスト
#
# テスト構成:
#   E2E-BM-001: 不明なオプション → exit 2
#   E2E-BM-002: git リポジトリでないパス → [SKIP] メッセージ, exit 0
#   E2E-BM-003: dry-run + no-fetch + リモートブランチなし → exit 0, マージなし
#   E2E-BM-004: dry-run + dirty worktree → [DRY-RUN] 警告出力, exit 0

setup_file() {
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export MERGE_SCRIPT="$PROJECT_ROOT/scripts/auto_merge_short_lived.sh"
    export TEST_SETTINGS="$PROJECT_ROOT/tests/fixtures/sample_settings.yaml"

    [ -f "$MERGE_SCRIPT" ] || {
        echo "ERROR: auto_merge_short_lived.sh not found" >&2
        return 1
    }
    [ -f "$TEST_SETTINGS" ] || {
        echo "ERROR: sample_settings.yaml not found" >&2
        return 1
    }
    command -v git >/dev/null 2>&1 || {
        echo "ERROR: git not found" >&2
        return 1
    }
    python3 -c "import yaml" 2>/dev/null || {
        echo "ERROR: python3-yaml is required" >&2
        return 1
    }
}

setup() {
    TEST_REPO="$(mktemp -d "$BATS_TMPDIR/branch_merge_e2e.XXXXXX")"
    export TEST_REPO
}

teardown() {
    [ -n "${TEST_REPO:-}" ] && [ -d "${TEST_REPO:-}" ] && rm -rf "$TEST_REPO"
}

# =============================================================================
# E2E-BM-001: 不明なオプション → exit 2 + 使い方表示
# =============================================================================

@test "E2E-BM-001: unknown option → exit 2 with usage" {
    run bash "$MERGE_SCRIPT" --unknown-flag-xyz
    [ "$status" -eq 2 ]
}

# =============================================================================
# E2E-BM-002: git リポジトリでないパス → [SKIP] メッセージ
# =============================================================================

@test "E2E-BM-002: non-git directory → [SKIP] message, exit 0" {
    # TEST_REPO は mktemp で作った空ディレクトリ (git init していない)
    run bash "$MERGE_SCRIPT" \
        --dry-run \
        --no-fetch \
        --repo "$TEST_REPO" \
        --settings "$TEST_SETTINGS"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[SKIP]" ]]
}

# =============================================================================
# E2E-BM-003: dry-run + no-fetch + リモートブランチなし → exit 0
# =============================================================================

@test "E2E-BM-003: dry-run with clean git repo, no remote branches → exit 0, no merge" {
    # git リポジトリを初期化 (リモートなし)
    git init "$TEST_REPO" --quiet
    git -C "$TEST_REPO" config user.email "test@test.local"
    git -C "$TEST_REPO" config user.name "Test"
    git -C "$TEST_REPO" commit --allow-empty -m "init" --quiet

    run bash "$MERGE_SCRIPT" \
        --dry-run \
        --no-fetch \
        --repo "$TEST_REPO" \
        --settings "$TEST_SETTINGS"
    [ "$status" -eq 0 ]
    # リモートブランチがないため "would merge" は出力されない
    [[ ! "$output" =~ "would merge" ]]
}

# =============================================================================
# E2E-BM-004: dry-run + dirty worktree → [DRY-RUN] dirty 警告
# =============================================================================

@test "E2E-BM-004: dry-run with dirty worktree → [DRY-RUN] dirty warning, exit 0" {
    # git リポジトリ初期化
    git init "$TEST_REPO" --quiet
    git -C "$TEST_REPO" config user.email "test@test.local"
    git -C "$TEST_REPO" config user.name "Test"
    git -C "$TEST_REPO" commit --allow-empty -m "init" --quiet

    # ダーティ状態を作る (未追跡ファイル)
    echo "dirty" > "$TEST_REPO/untracked_file.txt"

    run bash "$MERGE_SCRIPT" \
        --dry-run \
        --no-fetch \
        --repo "$TEST_REPO" \
        --settings "$TEST_SETTINGS"
    [ "$status" -eq 0 ]
    # dry-run では [DRY-RUN] メッセージで dirty を警告
    [[ "$output" =~ "[DRY-RUN]" ]]
    [[ "$output" =~ "dirty" ]]
}
