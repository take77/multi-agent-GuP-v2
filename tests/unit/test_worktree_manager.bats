#!/usr/bin/env bats
# test_worktree_manager.bats — worktree_manager.sh ユニットテスト
#
# テスト構成:
#   T-001~T-003: 引数バリデーション（no args, create missing args, delete missing args）
#   T-004: --help 出力
#   T-005: create — worktree作成 + ブランチ + シンボリックリンク
#   T-006: create — 重複作成でexit 1
#   T-007: delete — 正常削除
#   T-008: delete — 存在しないworktreeでexit 1
#   T-009: list — 正常実行
#   T-010: フルライフサイクル（create → verify → delete → verify）
#
# 注意: 全テストは一時gitリポジトリ内で実行。実リポジトリには一切影響しない。

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export ORIG_SCRIPT="$PROJECT_ROOT/scripts/worktree_manager.sh"

    # スクリプト存在確認（前提条件）
    [ -f "$ORIG_SCRIPT" ] || return 1
}

setup() {
    # テスト毎に独立した一時ディレクトリを作成
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/worktree_manager_test.XXXXXX")"

    # 一時gitリポジトリを初期化
    export TEST_REPO="$TEST_TMPDIR/repo"
    mkdir -p "$TEST_REPO"
    git -C "$TEST_REPO" init -b main >/dev/null 2>&1
    git -C "$TEST_REPO" config user.name "Test"
    git -C "$TEST_REPO" config user.email "test@test.com"

    # 初期コミットが必要（worktreeはコミットがないと作れない）
    git -C "$TEST_REPO" commit --allow-empty -m "initial commit" >/dev/null 2>&1

    # SHARED_DIRSに対応するディレクトリを作成
    local shared_dirs=(queue coordination config persona scripts context templates logs clusters)
    for dir in "${shared_dirs[@]}"; do
        mkdir -p "$TEST_REPO/$dir"
        # 空ディレクトリだとgitが追跡しないので.keepファイルを置く
        touch "$TEST_REPO/$dir/.keep"
    done
    git -C "$TEST_REPO" add -A >/dev/null 2>&1
    git -C "$TEST_REPO" commit -m "add shared dirs" >/dev/null 2>&1

    # worktree_manager.shをコピーし、SCRIPT_DIRをテスト用リポジトリに書き換え
    # + cd を注入して git コマンドがテストリポを参照するようにする
    export TEST_SCRIPT="$TEST_TMPDIR/worktree_manager.sh"
    sed "s|SCRIPT_DIR=\"\$(cd \"\$(dirname \"\$0\")/..*|SCRIPT_DIR=\"$TEST_REPO\"\ncd \"\$SCRIPT_DIR\"|" \
        "$ORIG_SCRIPT" > "$TEST_SCRIPT"
    chmod +x "$TEST_SCRIPT"
}

teardown() {
    # worktreeが残っているとgitが警告を出すので、先にpruneする
    if [ -d "$TEST_REPO" ]; then
        git -C "$TEST_REPO" worktree prune 2>/dev/null || true
    fi
    [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# T-001: 引数バリデーション — 引数なしでexit 1
# =============================================================================

@test "T-001: no arguments → exit 1 with Usage message" {
    run bash "$TEST_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

# =============================================================================
# T-002: 引数バリデーション — create に名前/cmd_id不足でexit 1
# =============================================================================

@test "T-002: create without name → exit 1" {
    run bash "$TEST_SCRIPT" create
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

@test "T-002b: create without cmd_id → exit 1" {
    run bash "$TEST_SCRIPT" create testname
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

# =============================================================================
# T-003: 引数バリデーション — delete に名前不足でexit 1
# =============================================================================

@test "T-003: delete without name → exit 1" {
    run bash "$TEST_SCRIPT" delete
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}

# =============================================================================
# T-004: --help — usage情報を出力
# =============================================================================

@test "T-004: --help → outputs usage info" {
    run bash "$TEST_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "create" ]]
    [[ "$output" =~ "delete" ]]
    [[ "$output" =~ "list" ]]
}

# =============================================================================
# T-005: create — worktreeディレクトリ + ブランチ + シンボリックリンク作成
# =============================================================================

@test "T-005: create → worktree dir, branch, and symlinks created" {
    run bash "$TEST_SCRIPT" create darjeeling cmd_160
    [ "$status" -eq 0 ]

    local wt_path="$TEST_REPO/worktrees/darjeeling"

    # worktreeディレクトリが存在する
    [ -d "$wt_path" ]

    # ブランチが作成されている
    git -C "$TEST_REPO" rev-parse --verify "squad/darjeeling/cmd_160" >/dev/null 2>&1

    # SHARED_DIRSのシンボリックリンクが作成されている
    local shared_dirs=(queue coordination config persona scripts context templates logs clusters)
    for dir in "${shared_dirs[@]}"; do
        [ -L "$wt_path/$dir" ]
    done

    # シンボリックリンクの参照先が正しい（相対パス ../../<dir>）
    local link_target
    link_target=$(readlink "$wt_path/queue")
    [ "$link_target" = "../../queue" ]

    # SUCCESS出力を含む
    [[ "$output" =~ "SUCCESS" ]]
}

# =============================================================================
# T-006: create — 重複作成でexit 1
# =============================================================================

@test "T-006: create duplicate name → exit 1" {
    # 1回目: 成功
    bash "$TEST_SCRIPT" create katyusha cmd_155

    # 2回目: 同名で失敗
    run bash "$TEST_SCRIPT" create katyusha cmd_155
    [ "$status" -eq 1 ]
    [[ "$output" =~ "already exists" ]]
}

# =============================================================================
# T-007: delete — 正常削除
# =============================================================================

@test "T-007: delete → worktree removed and branch deleted" {
    # まず作成
    bash "$TEST_SCRIPT" create maho cmd_170

    local wt_path="$TEST_REPO/worktrees/maho"
    [ -d "$wt_path" ]

    # 削除
    run bash "$TEST_SCRIPT" delete maho
    [ "$status" -eq 0 ]

    # worktreeディレクトリが削除されている
    [ ! -d "$wt_path" ]

    # ブランチが削除されている
    ! git -C "$TEST_REPO" rev-parse --verify "squad/maho/cmd_170" >/dev/null 2>&1

    # SUCCESS出力を含む
    [[ "$output" =~ "SUCCESS" ]]
}

# =============================================================================
# T-008: delete — 存在しないworktreeでexit 1
# =============================================================================

@test "T-008: delete non-existent → exit 1" {
    run bash "$TEST_SCRIPT" delete nonexistent
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

# =============================================================================
# T-009: list — 正常実行
# =============================================================================

@test "T-009: list → runs without error" {
    run bash "$TEST_SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Worktrees" ]]
}

@test "T-009b: list with existing worktrees → shows worktree info" {
    bash "$TEST_SCRIPT" create kay cmd_180

    run bash "$TEST_SCRIPT" list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "kay" ]]

    # cleanup
    bash "$TEST_SCRIPT" delete kay
}

# =============================================================================
# T-010: フルライフサイクル — create → verify symlinks → delete → verify cleanup
# =============================================================================

@test "T-010: full lifecycle → create, verify symlinks work, delete, verify cleanup" {
    local name="erika"
    local cmd_id="cmd_200"
    local wt_path="$TEST_REPO/worktrees/$name"

    # --- Phase 1: Create ---
    run bash "$TEST_SCRIPT" create "$name" "$cmd_id"
    [ "$status" -eq 0 ]
    [ -d "$wt_path" ]

    # --- Phase 2: Verify symlinks actually resolve ---
    local shared_dirs=(queue coordination config persona scripts context templates logs clusters)
    local symlink_count=0
    for dir in "${shared_dirs[@]}"; do
        # シンボリックリンクである
        [ -L "$wt_path/$dir" ]
        # リンク先が実際に存在する（解決できる）
        [ -d "$wt_path/$dir" ]
        symlink_count=$((symlink_count + 1))
    done
    [ "$symlink_count" -eq 9 ]

    # worktree内でファイルを作成し、メインツリーから見えることを確認
    touch "$wt_path/queue/test_from_worktree"
    [ -f "$TEST_REPO/queue/test_from_worktree" ]

    # メインツリーでファイルを作成し、worktreeから見えることを確認
    touch "$TEST_REPO/config/test_from_main"
    [ -f "$wt_path/config/test_from_main" ]

    # ブランチが正しい
    local branch
    branch=$(git -C "$wt_path" branch --show-current)
    [ "$branch" = "squad/$name/$cmd_id" ]

    # --- Phase 3: Delete ---
    run bash "$TEST_SCRIPT" delete "$name"
    [ "$status" -eq 0 ]

    # --- Phase 4: Verify cleanup ---
    [ ! -d "$wt_path" ]
    ! git -C "$TEST_REPO" rev-parse --verify "squad/$name/$cmd_id" >/dev/null 2>&1

    # テスト用ファイルをクリーンアップ
    rm -f "$TEST_REPO/queue/test_from_worktree"
    rm -f "$TEST_REPO/config/test_from_main"
}
