#!/usr/bin/env bats
# test_archive_coordination.bats — archive_coordination.py ユニットテスト
#
# テスト構成:
#   T-001: --dry-run で副作用なし（元ファイル変更なし、アーカイブ未作成）
#   T-002: 実行後に元ファイルから完了施策が除去されること
#   T-003: アーカイブファイルに完了施策が含まれること
#   T-004: 元ファイルサイズが減少すること
#   T-005: completed/done エントリがない場合は何もしない（正常終了）
#   T-006: バックアップファイルが作成されること
#   T-007: --statuses オプションでカスタムステータスをアーカイブできること
#   T-008: active/new エントリは保持されること

# --- セットアップ ---

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export SCRIPT="$PROJECT_ROOT/scripts/archive_coordination.py"

    # スクリプト存在確認
    [ -f "$SCRIPT" ] || { echo "Script not found: $SCRIPT" >&2; return 1; }

    # Python3 + PyYAML 確認
    python3 -c "import yaml" 2>/dev/null || { echo "PyYAML not installed" >&2; return 1; }
}

setup() {
    # テスト毎に独立した一時ディレクトリを作成
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/test_archive_coordination.XXXXXX")"
    export TEST_COORD_DIR="$TEST_TMPDIR/coordination"
    export TEST_COORD_FILE="$TEST_COORD_DIR/commander_to_staff.yaml"
    mkdir -p "$TEST_COORD_DIR"

    # テスト用YAML fixture を作成（completed/done/active/new ステータス混在）
    cat > "$TEST_COORD_FILE" <<'YAML'
cmd_001_completed_task:
  issued_at: "2026-01-01"
  status: completed
  priority: P1
  project: test
  summary: "completed task"

cmd_002_done_task:
  issued_at: "2026-01-02"
  status: done
  priority: P2
  project: test
  summary: "done task"

cmd_003_active_task:
  issued_at: "2026-01-03"
  status: active
  priority: P1
  project: test
  summary: "active task"

cmd_004_new_task:
  issued_at: "2026-01-04"
  status: new
  priority: P3
  project: test
  summary: "new task"
YAML

    # スクリプトがコーディネーションディレクトリを参照するよう、
    # PROJECT_ROOT を書き換えたコピーを作成
    export TEST_SCRIPT="$TEST_TMPDIR/archive_coordination.py"
    sed "s|Path(__file__).resolve().parent.parent / 'coordination'|Path('$TEST_COORD_DIR')|g" \
        "$SCRIPT" > "$TEST_SCRIPT"
    chmod +x "$TEST_SCRIPT"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}


# --- テストケース ---

# T-001: dry-run では元ファイルが変更されない
@test "T-001: --dry-run does not modify the source file" {
    local before_content
    before_content="$(cat "$TEST_COORD_FILE")"

    run python3 "$TEST_SCRIPT" --dry-run
    [ "$status" -eq 0 ]

    local after_content
    after_content="$(cat "$TEST_COORD_FILE")"
    [ "$before_content" = "$after_content" ]
}

# T-001b: dry-run ではアーカイブファイルが作成されない
@test "T-001b: --dry-run does not create archive file" {
    run python3 "$TEST_SCRIPT" --dry-run
    [ "$status" -eq 0 ]

    # archive ディレクトリが存在しないか、YAML ファイルがない
    local archive_yamls
    archive_yamls="$(find "$TEST_COORD_DIR/archive" -name '*.yaml' 2>/dev/null | wc -l)"
    [ "$archive_yamls" -eq 0 ]
}

# T-002: 完了施策が元ファイルから除去される
@test "T-002: completed and done entries are removed from source file" {
    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]

    # cmd_001, cmd_002 が消えていること
    run python3 -c "
import yaml
with open('$TEST_COORD_FILE') as f:
    data = yaml.safe_load(f)
assert 'cmd_001_completed_task' not in data, 'cmd_001 should be archived'
assert 'cmd_002_done_task' not in data, 'cmd_002 should be archived'
print('ok')
"
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "ok" ]
}

# T-003: アーカイブファイルに完了施策が含まれる
@test "T-003: archive file contains completed and done entries" {
    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]

    run python3 -c "
import yaml, os, glob
archive_dir = '$TEST_COORD_DIR/archive'
files = glob.glob(os.path.join(archive_dir, '*.yaml'))
assert len(files) == 1, f'Expected 1 archive file, got {len(files)}'
with open(files[0]) as f:
    data = yaml.safe_load(f)
assert 'cmd_001_completed_task' in data, 'cmd_001 should be in archive'
assert 'cmd_002_done_task' in data, 'cmd_002 should be in archive'
assert data['cmd_001_completed_task']['status'] == 'completed'
assert data['cmd_002_done_task']['status'] == 'done'
print('ok')
"
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "ok" ]
}

# T-004: 元ファイルサイズが減少する
@test "T-004: source file size decreases after archiving" {
    local before_size
    before_size="$(wc -c < "$TEST_COORD_FILE")"

    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]

    local after_size
    after_size="$(wc -c < "$TEST_COORD_FILE")"
    [ "$after_size" -lt "$before_size" ]
}

# T-005: アーカイブ対象がない場合は正常終了（ファイル変更なし）
@test "T-005: no-op when no completed/done entries exist" {
    # active/new のみの fixture を作成
    cat > "$TEST_COORD_FILE" <<'YAML'
cmd_010_active:
  issued_at: "2026-01-10"
  status: active
  summary: "active task"

cmd_011_new:
  issued_at: "2026-01-11"
  status: new
  summary: "new task"
YAML

    local before_content
    before_content="$(cat "$TEST_COORD_FILE")"

    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No entries to archive"* ]]

    local after_content
    after_content="$(cat "$TEST_COORD_FILE")"
    [ "$before_content" = "$after_content" ]
}

# T-006: バックアップファイルが作成される
@test "T-006: backup file is created before modification" {
    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]

    # backup/ ディレクトリに commander_to_staff.yaml が存在すること
    local backup_files
    backup_files="$(find "$TEST_COORD_DIR/backup" -name 'commander_to_staff.yaml' 2>/dev/null | wc -l)"
    [ "$backup_files" -ge 1 ]
}

# T-007: --statuses オプションでカスタムステータスをアーカイブできる
@test "T-007: --statuses option archives custom status entries" {
    run python3 "$TEST_SCRIPT" --statuses active
    [ "$status" -eq 0 ]

    run python3 -c "
import yaml
with open('$TEST_COORD_FILE') as f:
    data = yaml.safe_load(f)
assert 'cmd_003_active_task' not in data, 'cmd_003 (active) should be archived'
# completed/done は --statuses active 指定なので対象外 → 残る
assert 'cmd_001_completed_task' in data, 'cmd_001 (completed) should remain'
print('ok')
"
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "ok" ]
}

# T-008: active/new エントリは通常アーカイブされない（保持される）
@test "T-008: active and new entries are kept in source file" {
    run python3 "$TEST_SCRIPT"
    [ "$status" -eq 0 ]

    run python3 -c "
import yaml
with open('$TEST_COORD_FILE') as f:
    data = yaml.safe_load(f)
assert 'cmd_003_active_task' in data, 'cmd_003 (active) should remain'
assert 'cmd_004_new_task' in data, 'cmd_004 (new) should remain'
print('ok')
"
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = "ok" ]
}
