#!/usr/bin/env bash
# =============================================================================
# worktree_manager.sh — Git worktree lifecycle management with shared symlinks
# =============================================================================
# Usage:
#   scripts/worktree_manager.sh create <name> <cmd_id>   # Create worktree + symlinks
#   scripts/worktree_manager.sh delete <name>             # Delete worktree + branch
#   scripts/worktree_manager.sh list                      # List worktrees
#
# Examples:
#   scripts/worktree_manager.sh create darjeeling cmd_160
#   scripts/worktree_manager.sh create naomi cmd_155
#   scripts/worktree_manager.sh delete darjeeling
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE_BASE="$SCRIPT_DIR/worktrees"

# Directories symlinked back to main tree (shared runtime/config data).
# These are NOT per-branch — they are system state that all worktrees share.
SHARED_DIRS=(queue coordination config persona scripts context templates logs clusters)

# =============================================================================
# Subcommands
# =============================================================================

create_worktree() {
    local name="$1"
    local cmd_id="$2"
    local wt_path="$WORKTREE_BASE/$name"
    local branch="squad/${name}/${cmd_id}"

    if [ -d "$wt_path" ]; then
        echo "[worktree_manager] ERROR: already exists: $wt_path" >&2
        echo "  Use 'delete $name' first, or choose a different name." >&2
        exit 1
    fi

    mkdir -p "$WORKTREE_BASE"

    echo "[worktree_manager] Creating worktree: $name"
    echo "  path:   $wt_path"
    echo "  branch: $branch"
    echo ""

    # Create worktree from current HEAD (detached initially, then branch)
    git worktree add -b "$branch" "$wt_path" HEAD

    # Replace git-checkout copies of shared directories with symlinks to main tree.
    # The worktree just got a full copy of these dirs from the branch, but we need
    # all worktrees to read/write the SAME queue, inbox, config, etc.
    local linked=0
    for dir in "${SHARED_DIRS[@]}"; do
        # Only symlink if the directory exists in the main tree
        if [ ! -d "$SCRIPT_DIR/$dir" ]; then
            continue
        fi

        local target="$wt_path/$dir"

        # Remove the git-checkout copy (safe — it's a fresh checkout, not user data)
        if [ -d "$target" ] && [ ! -L "$target" ]; then
            rm -rf "$target"
        fi

        # Create relative symlink: worktrees/<name>/<dir> → ../../<dir>
        ln -s "../../$dir" "$target"
        echo "  symlink: $dir → ../../$dir"
        linked=$((linked + 1))
    done

    echo ""
    echo "[worktree_manager] SUCCESS: $wt_path ($linked symlinks)"
}

delete_worktree() {
    local name="$1"
    local wt_path="$WORKTREE_BASE/$name"

    if [ ! -d "$wt_path" ]; then
        echo "[worktree_manager] ERROR: not found: $wt_path" >&2
        exit 1
    fi

    # Get branch name before removal
    local branch=""
    branch=$(git -C "$wt_path" branch --show-current 2>/dev/null || true)

    # Check for uncommitted changes and warn
    local dirty=""
    dirty=$(git -C "$wt_path" status --porcelain 2>/dev/null | head -5 || true)
    if [ -n "$dirty" ]; then
        echo "[worktree_manager] WARNING: uncommitted changes in $wt_path:" >&2
        echo "$dirty" >&2
        echo "  Proceeding with forced removal." >&2
        echo ""
    fi

    echo "[worktree_manager] Removing worktree: $name"

    # Remove worktree (--force handles dirty worktrees)
    git worktree remove --force "$wt_path" 2>/dev/null || {
        # Fallback: manual cleanup if git worktree remove fails
        echo "  git worktree remove failed, cleaning up manually..." >&2
        rm -rf "$wt_path"
        git worktree prune
    }

    # Delete the branch
    if [ -n "$branch" ] && git rev-parse --verify "$branch" >/dev/null 2>&1; then
        git branch -D "$branch" >/dev/null 2>&1 && echo "  branch deleted: $branch"
    fi

    echo "[worktree_manager] SUCCESS: $name removed"
}

list_worktrees() {
    echo "[worktree_manager] Worktrees:"
    echo ""
    git worktree list
    echo ""

    # Show symlink status for managed worktrees
    if [ -d "$WORKTREE_BASE" ]; then
        local found=0
        for d in "$WORKTREE_BASE"/*/; do
            [ -d "$d" ] || continue
            local name
            name=$(basename "$d")
            local symlink_count=0
            for dir in "${SHARED_DIRS[@]}"; do
                [ -L "$d$dir" ] && symlink_count=$((symlink_count + 1))
            done
            local branch
            branch=$(git -C "$d" branch --show-current 2>/dev/null || echo "???")
            printf "  %-16s branch=%-35s symlinks=%d/%d\n" "$name" "$branch" "$symlink_count" "${#SHARED_DIRS[@]}"
            found=$((found + 1))
        done
        if [ "$found" -eq 0 ]; then
            echo "  (no managed worktrees in $WORKTREE_BASE)"
        fi
    fi
}

# =============================================================================
# Dispatch
# =============================================================================

case "${1:-}" in
    create)
        [ -z "${2:-}" ] && { echo "Usage: $0 create <name> <cmd_id>" >&2; exit 1; }
        [ -z "${3:-}" ] && { echo "Usage: $0 create <name> <cmd_id>" >&2; exit 1; }
        create_worktree "$2" "$3"
        ;;
    delete)
        [ -z "${2:-}" ] && { echo "Usage: $0 delete <name>" >&2; exit 1; }
        delete_worktree "$2"
        ;;
    list)
        list_worktrees
        ;;
    -h|--help)
        head -12 "$0" | tail -8
        ;;
    *)
        echo "Usage: $0 {create|delete|list} [args...]" >&2
        echo "Run '$0 --help' for details." >&2
        exit 1
        ;;
esac
