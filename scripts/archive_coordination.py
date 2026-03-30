#!/usr/bin/env python3
"""
Coordination Archive Utility (GuP-v2)

coordination/commander_to_staff.yaml から完了施策（status: completed/done）を
coordination/archive/ ディレクトリに退避し、元ファイルをスリム化する。

Usage:
    python3 archive_coordination.py [--dry-run] [--statuses completed,done]

Options:
    --dry-run          実行せず、対象施策の一覧を表示するのみ
    --statuses <list>  アーカイブ対象のステータス（カンマ区切り、デフォルト: completed,done）
"""

import sys
import shutil
from datetime import datetime
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML not installed. Run: pip3 install pyyaml", file=sys.stderr)
    sys.exit(1)

# デフォルトのアーカイブ対象ステータス
DEFAULT_ARCHIVE_STATUSES = {'completed', 'done'}

# ファイルパス定数
COORDINATION_FILE = 'commander_to_staff.yaml'


def get_coordination_dir():
    return Path(__file__).resolve().parent.parent / 'coordination'


def get_archive_dir():
    return get_coordination_dir() / 'archive'


def get_backup_dir():
    return get_coordination_dir() / 'backup'


def load_yaml_raw(filepath):
    """YAMLファイルをロード（順序保持）。"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing {filepath}: {e}", file=sys.stderr)
        return {}


def save_yaml(filepath, data):
    """YAMLファイルを保存。"""
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False,
                      default_flow_style=False)
        return True
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return False


def backup_file(filepath):
    """修正前にファイルをバックアップ（coordination/backup/YYYYMMDD_HHMMSS/）。"""
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_dir = get_backup_dir() / ts
    backup_dir.mkdir(parents=True, exist_ok=True)
    dest = backup_dir / filepath.name
    shutil.copy2(filepath, dest)
    return dest


def append_to_daily_archive(archive_dir, entries):
    """アーカイブ対象エントリを coordination/archive/YYYYMMDD.yaml に追記。"""
    if not entries:
        return True
    today = datetime.now().strftime('%Y%m%d')
    archive_file = archive_dir / f'{today}.yaml'

    existing = {}
    if archive_file.exists():
        existing = load_yaml_raw(archive_file)
    if not isinstance(existing, dict):
        existing = {}

    # entries は {cmd_id: entry_data} の dict
    existing.update(entries)

    archive_dir.mkdir(parents=True, exist_ok=True)
    return save_yaml(archive_file, existing)


def archive_coordination(dry_run=False, archive_statuses=None):
    """
    commander_to_staff.yaml の完了施策をアーカイブする。

    Returns:
        True on success, False on failure
    """
    if archive_statuses is None:
        archive_statuses = DEFAULT_ARCHIVE_STATUSES

    coord_dir = get_coordination_dir()
    coord_file = coord_dir / COORDINATION_FILE
    archive_dir = get_archive_dir()

    if not coord_file.exists():
        print(f"Error: {coord_file} not found", file=sys.stderr)
        return False

    data = load_yaml_raw(coord_file)
    if not data:
        print(f"Warning: {coord_file} is empty or failed to parse", file=sys.stderr)
        return True

    if not isinstance(data, dict):
        print(f"Error: {coord_file} top-level is not a mapping", file=sys.stderr)
        return False

    # アーカイブ対象と残留エントリの仕分け
    to_archive = {}
    to_keep = {}

    for cmd_id, entry in data.items():
        if not isinstance(entry, dict):
            # YAML コメント由来の非dictエントリはそのまま残す
            to_keep[cmd_id] = entry
            continue

        status = entry.get('status', '')
        if status in archive_statuses:
            to_archive[cmd_id] = entry
        else:
            to_keep[cmd_id] = entry

    if not to_archive:
        print("No entries to archive (no completed/done status found).")
        return True

    # dry-run モード
    if dry_run:
        original_size = coord_file.stat().st_size
        print(f"[DRY-RUN] {coord_file.name}: {len(data)} entries total, "
              f"{len(to_archive)} to archive, {len(to_keep)} to keep")
        print(f"[DRY-RUN] Original size: {original_size:,} bytes")
        print(f"[DRY-RUN] Entries to archive:")
        for cmd_id, entry in to_archive.items():
            status = entry.get('status', 'unknown')
            issued = entry.get('issued_at', 'unknown')
            print(f"  [DRY-RUN]   {cmd_id} (status={status}, issued={issued})")
        today = datetime.now().strftime('%Y%m%d')
        print(f"[DRY-RUN] Archive destination: {archive_dir}/{today}.yaml")
        return True

    # バックアップ作成
    backup_dest = backup_file(coord_file)
    print(f"[archive] Backup created: {backup_dest}")

    # アーカイブファイルに書き込み
    if not append_to_daily_archive(archive_dir, to_archive):
        print("Error: failed to write archive file", file=sys.stderr)
        return False

    today = datetime.now().strftime('%Y%m%d')
    print(f"[archive] Archived {len(to_archive)} entries to {archive_dir}/{today}.yaml")
    for cmd_id in to_archive:
        print(f"  -> {cmd_id}")

    # 元ファイルを残留エントリのみに更新
    if not save_yaml(coord_file, to_keep):
        print("Error: failed to update coordination file", file=sys.stderr)
        return False

    new_size = coord_file.stat().st_size
    print(f"[archive] {coord_file.name}: {len(to_archive)} entries removed, "
          f"{len(to_keep)} entries remain, size={new_size:,} bytes")

    return True


def parse_arguments():
    args = sys.argv[1:]
    dry_run = '--dry-run' in args
    positional = [a for a in args if not a.startswith('--')]

    archive_statuses = DEFAULT_ARCHIVE_STATUSES
    for i, a in enumerate(args):
        if a == '--statuses' and i + 1 < len(args):
            archive_statuses = set(args[i + 1].split(','))

    return dry_run, archive_statuses


def main():
    dry_run, archive_statuses = parse_arguments()

    # アーカイブ・バックアップディレクトリを事前作成
    get_archive_dir().mkdir(parents=True, exist_ok=True)
    get_backup_dir().mkdir(parents=True, exist_ok=True)

    if not archive_coordination(dry_run=dry_run, archive_statuses=archive_statuses):
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()
