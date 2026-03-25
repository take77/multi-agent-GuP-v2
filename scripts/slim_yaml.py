#!/usr/bin/env python3
"""
YAML Slimming Utility (GuP-v2 v2)

Compresses queue YAML files to maintain performance.
- inbox/*.yaml  : archive read:true messages, keep latest 20
- reports/*.yaml: archive status:done files, keep latest 5
- tasks/*.yaml  : archive status:done (canonical → reset to idle), keep latest 3 archives

Usage:
    python3 slim_yaml.py [--dry-run]           # Full slim (all queues)
    python3 slim_yaml.py <agent_id> [--dry-run] # Slim specific agent's inbox (+ full if miho)
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

# GuP-v2 canonical member names (24 members across 4 squads)
CANONICAL_MEMBERS = {
    # カチューシャ隊
    'nonna', 'klara', 'mako', 'erwin', 'caesar', 'saori',
    # ダージリン隊
    'pekoe', 'hana', 'rosehip', 'marie', 'andou', 'oshida',
    # ケイ隊
    'arisa', 'naomi', 'yukari', 'anchovy', 'carpaccio', 'pepperoni',
    # まほ隊
    'erika', 'mika', 'aki', 'mikko', 'kinuyo', 'fukuda',
}

IDLE_STUB = {'task': {'status': 'idle'}}

# Retention settings
INBOX_KEEP = 20        # keep latest N messages in inbox
REPORTS_KEEP = 5       # keep latest N done report files
TASKS_ARCHIVE_KEEP = 3 # keep latest N archives per canonical member


def get_queue_dir():
    return Path(__file__).resolve().parent.parent / 'queue'


def load_yaml(filepath):
    """Safely load YAML file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing {filepath}: {e}", file=sys.stderr)
        return {}


def save_yaml(filepath, data):
    """Safely save YAML file."""
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
        return True
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return False


def backup_file(filepath, backup_root):
    """Copy file to queue/backup/YYYYMMDD_HHMMSS/ before modification."""
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_dir = backup_root / ts
    backup_dir.mkdir(parents=True, exist_ok=True)
    dest = backup_dir / filepath.name
    shutil.copy2(filepath, dest)
    return dest


def append_to_daily_archive(archive_dir, entries, label):
    """Append archived entries to queue/archive/YYYYMMDD.yaml."""
    if not entries:
        return True
    today = datetime.now().strftime('%Y%m%d')
    archive_file = archive_dir / f'{today}.yaml'

    # Load existing daily archive
    existing = {}
    if archive_file.exists():
        existing = load_yaml(archive_file)
    if not isinstance(existing, dict):
        existing = {}

    existing.setdefault(label, [])
    existing[label].extend(entries)

    archive_dir.mkdir(parents=True, exist_ok=True)
    return save_yaml(archive_file, existing)


# ---------------------------------------------------------------------------
# Inbox slimming
# ---------------------------------------------------------------------------

def slim_inbox(agent_id, dry_run=False):
    """Archive read:true messages older than INBOX_KEEP threshold."""
    queue_dir = get_queue_dir()
    inbox_file = queue_dir / 'inbox' / f'{agent_id}.yaml'
    backup_root = queue_dir / 'backup'
    archive_dir = queue_dir / 'archive'

    if not inbox_file.exists():
        return True

    data = load_yaml(inbox_file)
    if not data or 'messages' not in data:
        return True

    messages = data.get('messages', [])
    if not messages:
        return True  # Empty inbox, nothing to slim
    if not isinstance(messages, list):
        print(f"Warning: {inbox_file}: 'messages' is not a list, skipping", file=sys.stderr)
        return True  # Skip gracefully, don't fail

    if len(messages) <= INBOX_KEEP:
        return True  # Nothing to slim

    # Sort by timestamp (oldest first)
    sorted_msgs = sorted(messages, key=lambda m: str(m.get('timestamp', '')))

    # Latest INBOX_KEEP messages are always kept
    tail = sorted_msgs[-INBOX_KEEP:]
    head = sorted_msgs[:-INBOX_KEEP]

    # From the older messages, archive only read:true
    to_archive = [m for m in head if m.get('read', False)]
    keep_head = [m for m in head if not m.get('read', False)]  # unread: must keep

    if not to_archive:
        return True

    total_keep = INBOX_KEEP + len(keep_head)

    if dry_run:
        print(f"[DRY-RUN] inbox/{agent_id}: would archive {len(to_archive)} messages "
              f"(total={len(messages)}, keep={total_keep}, "
              f"reduction={len(to_archive)} entries / ~{len(to_archive)*200} bytes)")
        return True

    # Backup before modification
    backup_file(inbox_file, backup_root)

    # Update inbox (keep unread head + tail)
    data['messages'] = keep_head + tail
    if not save_yaml(inbox_file, data):
        return False

    # Append to daily archive
    append_to_daily_archive(archive_dir, to_archive, f'inbox_{agent_id}')

    print(f"[slim] inbox/{agent_id}: archived {len(to_archive)} messages, kept {total_keep}")
    return True


def slim_all_inboxes(dry_run=False):
    """Slim all inbox files."""
    queue_dir = get_queue_dir()
    inbox_dir = queue_dir / 'inbox'
    if not inbox_dir.exists():
        return True
    for filepath in sorted(inbox_dir.glob('*.yaml')):
        if not slim_inbox(filepath.stem, dry_run):
            return False
    return True


# ---------------------------------------------------------------------------
# Reports slimming
# ---------------------------------------------------------------------------

def slim_reports(dry_run=False):
    """Archive status:done report files, keep latest REPORTS_KEEP."""
    queue_dir = get_queue_dir()
    reports_dir = queue_dir / 'reports'
    backup_root = queue_dir / 'backup'
    archive_dir = queue_dir / 'archive'

    if not reports_dir.exists():
        return True

    # Collect done files sorted by mtime (oldest first)
    done_files = []
    for filepath in reports_dir.glob('*.yaml'):
        data = load_yaml(filepath)
        if isinstance(data, dict) and data.get('status') == 'done':
            done_files.append(filepath)

    done_files.sort(key=lambda f: f.stat().st_mtime)

    if len(done_files) <= REPORTS_KEEP:
        if dry_run:
            print(f"[DRY-RUN] reports: {len(done_files)} done files <= keep={REPORTS_KEEP}, no action needed")
        return True

    to_archive = done_files[:-REPORTS_KEEP]  # oldest

    if dry_run:
        total_bytes = sum(f.stat().st_size for f in to_archive)
        print(f"[DRY-RUN] reports: would archive {len(to_archive)} files "
              f"(total done={len(done_files)}, keep={REPORTS_KEEP}, "
              f"reduction=~{total_bytes} bytes)")
        for f in to_archive:
            print(f"  [DRY-RUN]   -> {f.name}")
        return True

    archived_entries = []
    for filepath in to_archive:
        backup_file(filepath, backup_root)
        data = load_yaml(filepath)
        archived_entries.append({'filename': filepath.name, 'data': data})
        filepath.unlink()
        print(f"[slim] reports: archived {filepath.name}")

    if archived_entries:
        append_to_daily_archive(archive_dir, archived_entries, 'reports')

    return True


# ---------------------------------------------------------------------------
# Tasks slimming
# ---------------------------------------------------------------------------

def slim_tasks(dry_run=False):
    """Archive done canonical task files (reset to idle stub), prune old archives."""
    queue_dir = get_queue_dir()
    tasks_dir = queue_dir / 'tasks'
    archive_tasks_dir = queue_dir / 'archive' / 'tasks'
    backup_root = queue_dir / 'backup'
    archive_dir = queue_dir / 'archive'

    if not tasks_dir.exists():
        return True

    done_statuses = {'done', 'completed', 'cancelled'}
    idle_statuses = {'idle'}
    archived_entries = []

    for filepath in sorted(tasks_dir.glob('*.yaml')):
        if filepath.name == 'pending.yaml':
            continue

        data = load_yaml(filepath)
        if not isinstance(data, dict):
            continue

        task = data.get('task', {})
        if not isinstance(task, dict):
            continue

        status = task.get('status', '')
        stem = filepath.stem

        if stem not in CANONICAL_MEMBERS:
            # Non-canonical files (captains, member{N}, etc.) are skipped
            # to avoid accidentally removing infrastructure files
            continue

        # Canonical member: archive only if done
        if status not in done_statuses:
            continue

        if dry_run:
            print(f"[DRY-RUN] tasks: would archive {filepath.name} (status={status}) → reset to idle")
            # Check archives
            existing = sorted(archive_tasks_dir.glob(f'{stem}_*.yaml')) if archive_tasks_dir.exists() else []
            if len(existing) >= TASKS_ARCHIVE_KEEP:
                prune_count = len(existing) - TASKS_ARCHIVE_KEEP + 1
                print(f"  [DRY-RUN]   would prune {prune_count} old archive(s) for {stem}")
            continue

        # Backup
        backup_file(filepath, backup_root)

        # Move to archive/tasks/
        ts = datetime.now().strftime('%Y%m%d%H%M%S')
        archive_tasks_dir.mkdir(parents=True, exist_ok=True)
        archive_path = archive_tasks_dir / f'{stem}_{ts}.yaml'
        save_yaml(archive_path, data)
        archived_entries.append({'filename': filepath.name, 'data': data})

        # Reset to idle stub
        save_yaml(filepath, IDLE_STUB)
        print(f"[slim] tasks: {stem} archived → reset to idle")

        # Prune old archives: keep only latest TASKS_ARCHIVE_KEEP per member
        member_archives = sorted(
            archive_tasks_dir.glob(f'{stem}_*.yaml'),
            key=lambda f: f.stat().st_mtime
        )
        if len(member_archives) > TASKS_ARCHIVE_KEEP:
            for old in member_archives[:-TASKS_ARCHIVE_KEEP]:
                old.unlink()
                print(f"[slim] tasks: pruned old archive {old.name}")

    if archived_entries and not dry_run:
        append_to_daily_archive(archive_dir, archived_entries, 'tasks')

    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def slim_all(dry_run=False):
    """Run full slim across all queues."""
    ok = True
    ok = slim_tasks(dry_run) and ok
    ok = slim_reports(dry_run) and ok
    ok = slim_all_inboxes(dry_run) and ok
    return ok


def parse_arguments():
    args = sys.argv[1:]
    dry_run = '--dry-run' in args
    positional = [a for a in args if not a.startswith('--')]
    agent_id = positional[0] if positional else None
    return agent_id, dry_run


def main():
    agent_id, dry_run = parse_arguments()

    queue_dir = get_queue_dir()
    (queue_dir / 'archive').mkdir(parents=True, exist_ok=True)
    (queue_dir / 'backup').mkdir(parents=True, exist_ok=True)

    if agent_id:
        # Legacy / agent-specific mode
        if not slim_inbox(agent_id, dry_run):
            sys.exit(1)
        # miho (参謀長) runs full slim
        if agent_id == 'miho':
            if not slim_tasks(dry_run):
                sys.exit(1)
            if not slim_reports(dry_run):
                sys.exit(1)
            if not slim_all_inboxes(dry_run):
                sys.exit(1)
    else:
        # No agent_id → full slim
        if not slim_all(dry_run):
            sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()
