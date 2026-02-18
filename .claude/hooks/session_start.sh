#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Session Start Hook for multi-agent-GuP-v2
# ═══════════════════════════════════════════════════════════════════════════════
# This hook runs automatically when Claude Code starts a session.
# It identifies the agent from tmux, loads persona and instructions,
# and outputs them as context for Claude.
#
# Also supports Agent Teams teammate mode:
# - Reads stdin JSON (if provided)
# - Injects captain rules for teammate captains
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Get script directory (project root is parent of .claude)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ───────────────────────────────────────────────────────────────────────────────
# Step 0: Read stdin JSON (for Agent Teams teammate mode)
# ───────────────────────────────────────────────────────────────────────────────
HOOK_INPUT=""
if read -t 0.5 HOOK_INPUT 2>/dev/null; then
    # JSON received (potential Agent Teams teammate environment)
    # Extract session_id if jq is available (fallback to grep/sed if not)
    if command -v jq >/dev/null 2>&1; then
        SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id' 2>/dev/null || echo "")
    else
        # Fallback: simple grep/sed extraction
        SESSION_ID=$(echo "$HOOK_INPUT" | grep -o '"session_id":"[^"]*"' | sed 's/"session_id":"\([^"]*\)"/\1/' || echo "")
    fi
fi

# ───────────────────────────────────────────────────────────────────────────────
# inject_captain_context function (for teammate mode)
# ───────────────────────────────────────────────────────────────────────────────
inject_captain_context() {
    local CAPTAIN_RULES_FILE="$PROJECT_ROOT/instructions/agent_teams/captain_injection.md"

    if [ -f "$CAPTAIN_RULES_FILE" ]; then
        local CAPTAIN_CONTEXT
        CAPTAIN_CONTEXT=$(cat "$CAPTAIN_RULES_FILE")

        # Escape for JSON: use jq -Rs . for proper escaping
        local ESCAPED_CONTEXT
        if command -v jq >/dev/null 2>&1; then
            ESCAPED_CONTEXT=$(echo "$CAPTAIN_CONTEXT" | jq -Rs . 2>/dev/null)
        else
            # Fallback: manual escape (basic)
            ESCAPED_CONTEXT=\"\"
        fi

        # Output JSON for Claude Code to read
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ESCAPED_CONTEXT
  }
}
EOF
    fi
}

# ───────────────────────────────────────────────────────────────────────────────
# Step 1: Environment Detection (teammate vs normal agent)
# ───────────────────────────────────────────────────────────────────────────────
if [ -z "$TMUX_PANE" ] && [ "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" = "1" ]; then
    # ─────────────────────────────────────────────────────────────────────────
    # Teammate Mode: Inject captain rules and exit
    # ─────────────────────────────────────────────────────────────────────────
    inject_captain_context
    exit 0
fi

# ───────────────────────────────────────────────────────────────────────────────
# Normal Agent Mode: Existing logic below (unchanged)
# ───────────────────────────────────────────────────────────────────────────────
# Step 1: Identify agent from tmux
# ───────────────────────────────────────────────────────────────────────────────
if [ -n "$TMUX_PANE" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || echo "")
    AGENT_NAME=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_name}' 2>/dev/null || echo "")
    AGENT_ROLE=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_role}' 2>/dev/null || echo "")
else
    # Not in tmux - try environment variables set by gup_v2_launch.sh
    AGENT_ID="${AGENT_ID:-}"
    AGENT_NAME="${AGENT_NAME:-}"
    AGENT_ROLE="${AGENT_ROLE:-}"
fi

# Exit silently if no agent_id found (non-multi-agent session)
if [ -z "$AGENT_ID" ]; then
    exit 0
fi

# ───────────────────────────────────────────────────────────────────────────────
# Step 2: Determine role if not set
# ───────────────────────────────────────────────────────────────────────────────
if [ -z "$AGENT_ROLE" ]; then
    case "$AGENT_ID" in
        anzu) AGENT_ROLE="battalion_commander" ;;
        miho) AGENT_ROLE="chief_of_staff" ;;
        darjeeling|katyusha|kay|maho) AGENT_ROLE="captain" ;;
        pekoe|nonna|arisa|erika) AGENT_ROLE="vice_captain" ;;
        *) AGENT_ROLE="member" ;;
    esac
fi

# ───────────────────────────────────────────────────────────────────────────────
# Step 3: Build context output
# ───────────────────────────────────────────────────────────────────────────────
echo "# Session Start: Agent Initialization Complete"
echo ""
echo "## Agent Identity"
echo "- **Agent ID**: ${AGENT_ID}"
echo "- **Agent Name**: ${AGENT_NAME:-$AGENT_ID}"
echo "- **Role**: ${AGENT_ROLE}"
echo ""

# ───────────────────────────────────────────────────────────────────────────────
# Step 4: Load persona file
# ───────────────────────────────────────────────────────────────────────────────
PERSONA_FILE="${PROJECT_ROOT}/persona/${AGENT_ID}.md"
if [ -f "$PERSONA_FILE" ]; then
    echo "## Persona (WHO you are)"
    echo ""
    cat "$PERSONA_FILE"
    echo ""
else
    echo "## Persona"
    echo "**Warning**: Persona file not found at ${PERSONA_FILE}"
    echo ""
fi

# ───────────────────────────────────────────────────────────────────────────────
# Step 5: Load instructions file
# ───────────────────────────────────────────────────────────────────────────────
INSTRUCTIONS_FILE="${PROJECT_ROOT}/instructions/${AGENT_ROLE}.md"
if [ -f "$INSTRUCTIONS_FILE" ]; then
    echo "## Instructions (WHAT you do)"
    echo ""
    cat "$INSTRUCTIONS_FILE"
    echo ""
else
    echo "## Instructions"
    echo "**Warning**: Instructions file not found at ${INSTRUCTIONS_FILE}"
    echo ""
fi

# ───────────────────────────────────────────────────────────────────────────────
# Step 6: Global CLAUDE.md override notice
# ───────────────────────────────────────────────────────────────────────────────
echo "## Important Notes"
echo ""
echo "- **Global CLAUDE.md DISABLED**: Sakurasou team settings from ~/.claude/CLAUDE.md are NOT active."
echo "- **Active Configuration**: Girls und Panzer military structure only."
echo "- You are ${AGENT_NAME:-$AGENT_ID}, role: ${AGENT_ROLE}."
echo "- Always speak in character as defined in your persona."
echo ""

exit 0
