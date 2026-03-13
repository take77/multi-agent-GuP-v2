#!/usr/bin/env python3
"""
YAML Slimming Utility (GuP-v2)

Removes completed/archived items from YAML queue files to maintain performance.
- For miho: Archives completed task/report files and all inbox files.
- For all agents: Archives read: true messages from inbox files.
"""

import os
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

# GuP-v2 canonical member names (24 members across 4 squads)
CANONICAL_TASKS = {
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
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
        return True
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return False


def get_timestamp():
    """Generate archive filename timestamp."""
    return datetime.now().strftime('%Y%m%d%H%M%S')


def get_queue_dir():
    return Path(__file__).resolve().parent.parent / 'queue'


def get_coordination_dir():
    return Path(__file__).resolve().parent.parent / 'coordination'


def get_active_cmd_ids():
    """Return command IDs that are not done from coordination/*_queue.yaml and queue/captain_queue.yaml."""
    active = set()

    # Check coordination/*_queue.yaml files (darjeeling_queue, katyusha_queue, kay_queue, maho_queue)
    coord_dir = get_coordination_dir()
    if coord_dir.exists():
        for filepath in sorted(coord_dir.glob('*_queue.yaml')):
            data = load_yaml(filepath)
            if not isinstance(data, dict):
                continue
            tasks = data.get('tasks', [])
            if not isinstance(tasks, list):
                continue
            for task in tasks:
                if not isinstance(task, dict):
                    continue
                cmd_id = task.get('cmd_id') or task.get('id')
                if cmd_id is None:
                    continue
                status = task.get('status', '')
                if status != 'done':
                    active.add(cmd_id)

    # Check queue/captain_queue.yaml if it exists
    queue_dir = get_queue_dir()
    captain_file = queue_dir / 'captain_queue.yaml'
    if captain_file.exists():
        data = load_yaml(captain_file)
        if isinstance(data, dict):
            for key in ('commands', 'queue', 'tasks'):
                commands = data.get(key, [])
                if not isinstance(commands, list):
                    continue
                for cmd in commands:
                    if not isinstance(cmd, dict):
                        continue
                    cmd_id = cmd.get('id') or cmd.get('cmd_id')
                    if cmd_id is None:
                        continue
                    if cmd.get('status') != 'done':
                        active.add(cmd_id)

    return active


def ensure_parent_dir(path):
    path.parent.mkdir(parents=True, exist_ok=True)


def slim_inbox(agent_id, dry_run=False):
    """Archive read: true messages from inbox file."""
    queue_dir = get_queue_dir()
    archive_dir = queue_dir / 'archive'
    inbox_file = queue_dir / 'inbox' / f'{agent_id}.yaml'

    if not inbox_file.exists():
        return True

    data = load_yaml(inbox_file)
    if not data or 'messages' not in data:
        return True

    messages = data.get('messages', [])
    if not isinstance(messages, list):
        print("Error: messages is not a list", file=sys.stderr)
        return False

    unread = []
    archived = []

    for msg in messages:
        is_read = msg.get('read', False)
        if is_read:
            archived.append(msg)
        else:
            unread.append(msg)

    if not archived:
        return True

    archive_timestamp = get_timestamp()
    archive_file = archive_dir / f'inbox_{agent_id}_{archive_timestamp}.yaml'

    if dry_run:
        print(f"[DRY-RUN] would archive {len(archived)} messages from {agent_id} to {archive_file.name}")
        return True

    ensure_parent_dir(archive_file)
    archive_data = {'messages': archived}
    if not save_yaml(archive_file, archive_data):
        return False

    data['messages'] = unread
    if not save_yaml(inbox_file, data):
        print(f"Error: Failed to update {inbox_file}, but archive was created", file=sys.stderr)
        return False

    print(f"Archived {len(archived)} messages from {agent_id} to {archive_file.name}", file=sys.stderr)
    return True


def slim_tasks(dry_run=False):
    """Archive done/completed/cancelled tasks from queue/tasks/*.yaml."""
    queue_dir = get_queue_dir()
    tasks_dir = queue_dir / 'tasks'
    archive_dir = queue_dir / 'archive' / 'tasks'

    if not tasks_dir.exists():
        return True

    timestamp = get_timestamp()
    done_statuses = {'done', 'completed', 'cancelled'}

    for filepath in sorted(tasks_dir.glob('*.yaml')):
        # Skip pending.yaml — do not archive blocked tasks
        if filepath.name == 'pending.yaml':
            continue

        data = load_yaml(filepath)
        if not isinstance(data, dict):
            continue

        task = data.get('task', {})
        if not isinstance(task, dict):
            continue

        status = task.get('status', '')
        if not status:
            continue

        stem = filepath.stem

        if stem in CANONICAL_TASKS:
            # Canonical member files: archive if done, then reset to idle
            if status not in done_statuses:
                continue

            archive_path = archive_dir / f'{stem}_{timestamp}.yaml'

            if dry_run:
                print(f"[DRY-RUN] would archive canonical task: {filepath}")
                print(f"[DRY-RUN] would write idle stub to: {filepath}")
                continue

            ensure_parent_dir(archive_path)
            if not save_yaml(archive_path, data):
                return False
            if not save_yaml(filepath, IDLE_STUB):
                return False
            continue

        # Non-canonical files: move to archive if done/cancelled
        if status not in {'done', 'cancelled'}:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive non-canonical task: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_reports(dry_run=False):
    """Archive stale reports that are not part of active commands."""
    queue_dir = get_queue_dir()
    reports_dir = queue_dir / 'reports'
    archive_dir = queue_dir / 'archive' / 'reports'

    if not reports_dir.exists():
        return True

    active_cmd_ids = get_active_cmd_ids()
    timestamp = get_timestamp()

    for filepath in sorted(reports_dir.glob('*.yaml')):
        data = load_yaml(filepath)
        parent_cmd = data.get('parent_cmd') if isinstance(data, dict) else None
        is_active = parent_cmd in active_cmd_ids
        is_stale = (time.time() - filepath.stat().st_mtime) >= 86400  # 24 hours

        if not is_stale:
            continue
        if is_active:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive report: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_all_inboxes(dry_run=False):
    """Archive read messages from all inbox files."""
    queue_dir = get_queue_dir()
    inbox_dir = queue_dir / 'inbox'

    if not inbox_dir.exists():
        return True

    for filepath in sorted(inbox_dir.glob('*.yaml')):
        agent_id = filepath.stem
        if dry_run:
            print(f"[DRY-RUN] processing inbox: {filepath}")
        if not slim_inbox(agent_id, dry_run=dry_run):
            return False

    return True


def parse_arguments():
    args = [arg for arg in sys.argv[1:] if arg != '--dry-run']
    dry_run = '--dry-run' in sys.argv[1:]
    if len(args) < 1:
        print("Usage: slim_yaml.py <agent_id> [--dry-run]", file=sys.stderr)
        sys.exit(1)
    return args[0], dry_run


def main():
    """Main entry point."""
    agent_id, dry_run = parse_arguments()

    # Ensure archive directory exists
    archive_dir = get_queue_dir() / 'archive'
    archive_dir.mkdir(parents=True, exist_ok=True)

    # miho (参謀長) runs full slimming across all queues and inboxes
    if agent_id == 'miho':
        if not slim_tasks(dry_run):
            sys.exit(1)
        if not slim_reports(dry_run):
            sys.exit(1)
        if not slim_all_inboxes(dry_run):
            sys.exit(1)

    # All agents: slim own inbox
    if not slim_inbox(agent_id, dry_run):
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()
