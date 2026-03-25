#!/usr/bin/env bash
# ============================================================
# Instruction File Build System v2.0
# ============================================================
# Two-tier generation:
#   1. Template-based: templates/*.md.tmpl → generated/{role}.md
#      - Resolves {{INCLUDE:path}} markers with common section content
#   2. CLI-variant: roles/ + common/ concatenation → generated/{cli}-{role}.md
#      (Legacy mode, kept for backward compatibility)
#   3. Auto-load files: CLAUDE.md → AGENTS.md, copilot-instructions.md, etc.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PARTS_DIR="$ROOT_DIR/instructions"
TEMPLATES_DIR="$PARTS_DIR/templates"
COMMON_DIR="$PARTS_DIR/common"
OUTPUT_DIR="$PARTS_DIR/generated"

mkdir -p "$OUTPUT_DIR"

echo "=== Instruction File Build System v2.0 ==="

# ============================================================
# Core: Resolve {{INCLUDE:path}} markers in a template file
# ============================================================
# Reads a template, replaces each {{INCLUDE:common/xxx.md}} line
# with the contents of instructions/common/xxx.md.
# Supports nested includes (1 level deep).
resolve_includes() {
    local input_file="$1"
    local output_file="$2"

    # Detect line ending style of input file
    local line_ending=""
    if file "$input_file" | grep -q "CRLF"; then
        line_ending=$'\r'
    fi

    # Process line by line
    > "$output_file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip trailing CR for processing
        local clean_line="${line%$'\r'}"
        if [[ "$clean_line" =~ ^\{\{INCLUDE:(.+)\}\}$ ]]; then
            local include_path="${BASH_REMATCH[1]}"
            local full_path="$PARTS_DIR/$include_path"
            if [ -f "$full_path" ]; then
                # Include file content, preserving target line endings
                if [ -n "$line_ending" ]; then
                    sed "s/\$/\\${line_ending}/" "$full_path" >> "$output_file"
                else
                    cat "$full_path" >> "$output_file"
                fi
            else
                echo "  ⚠️  WARNING: Include file not found: $full_path"
                printf '%s%s\n' "$clean_line" "$line_ending" >> "$output_file"
            fi
        else
            printf '%s%s\n' "$clean_line" "$line_ending" >> "$output_file"
        fi
    done < "$input_file"
}

# ============================================================
# Phase 1: Template-based generation (primary instructions)
# ============================================================
# Generates the main instruction files from templates.
# These are the files agents actually read at startup.
echo ""
echo "--- Phase 1: Template-based generation ---"

TEMPLATE_ROLES=()
for tmpl in "$TEMPLATES_DIR"/*.md.tmpl; do
    [ -f "$tmpl" ] || continue
    role_name="$(basename "$tmpl" .md.tmpl)"
    TEMPLATE_ROLES+=("$role_name")
    output_path="$OUTPUT_DIR/${role_name}.md"

    echo "Building from template: ${role_name}.md.tmpl → generated/${role_name}.md"
    resolve_includes "$tmpl" "$output_path"
    echo "  ✅ Created: generated/${role_name}.md"
done

if [ ${#TEMPLATE_ROLES[@]} -eq 0 ]; then
    echo "  ℹ️  No templates found in $TEMPLATES_DIR"
fi

# ============================================================
# Phase 2: CLI-variant generation (legacy concatenation mode)
# ============================================================
# Combines roles/ + common/ + cli_specific/ for multi-CLI support.
echo ""
echo "--- Phase 2: CLI-variant generation ---"

build_cli_variant() {
    local cli_type="$1"
    local role="$2"
    local output_filename="$3"
    local output_path="$OUTPUT_DIR/$output_filename"
    local original_file="$ROOT_DIR/instructions/${role}.md"

    echo "Building CLI variant: $output_filename (CLI: $cli_type, Role: $role)"

    # Extract YAML front matter from original file
    if [ -f "$original_file" ]; then
        awk '/^---$/{if(++n==2) {print "---"; exit} if(n==1) next} n==1' "$original_file" > "$output_path"
        echo "" >> "$output_path"
    else
        cat > "$output_path" <<EOFYAML
---
role: $role
version: "3.0"
cli_type: $cli_type
---

EOFYAML
    fi

    # Append role-specific content
    if [ -f "$PARTS_DIR/roles/${role}_role.md" ]; then
        cat "$PARTS_DIR/roles/${role}_role.md" >> "$output_path"
    fi

    # Append common sections
    for common_file in protocol.md task_flow.md forbidden_actions.md; do
        if [ -f "$COMMON_DIR/$common_file" ]; then
            echo "" >> "$output_path"
            cat "$COMMON_DIR/$common_file" >> "$output_path"
        fi
    done

    # Append CLI-specific tools section
    local cli_tools="$PARTS_DIR/cli_specific/${cli_type}_tools.md"
    if [ -f "$cli_tools" ]; then
        echo "" >> "$output_path"
        cat "$cli_tools" >> "$output_path"
    fi

    echo "  ✅ Created: $output_filename"
}

# Build CLI variants for roles that have role definition files
for role_file in "$PARTS_DIR"/roles/*_role.md; do
    [ -f "$role_file" ] || continue
    role_name="$(basename "$role_file" _role.md)"

    for cli_type in codex copilot kimi; do
        build_cli_variant "$cli_type" "$role_name" "${cli_type}-${role_name}.md"
    done
done

# ============================================================
# Phase 3: CLI auto-load file generation
# ============================================================
echo ""
echo "--- Phase 3: CLI auto-load files ---"

generate_agents_md() {
    local output_path="$ROOT_DIR/AGENTS.md"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: AGENTS.md (Codex auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping AGENTS.md generation."
        return 0
    fi

    sed \
        -e 's|CLAUDE\.md|AGENTS.md|g' \
        -e 's|CLAUDE\.local\.md|AGENTS.override.md|g' \
        -e 's|instructions/captain\.md|instructions/generated/codex-captain.md|g' \
        -e 's|instructions/vice_captain\.md|instructions/generated/codex-vice_captain.md|g' \
        -e 's|instructions/member\.md|instructions/generated/codex-member.md|g' \
        -e 's|~/.claude/|~/.codex/|g' \
        -e 's|\.claude\.json|.codex/config.toml|g' \
        -e 's|\.mcp\.json|config.toml (mcp_servers section)|g' \
        -e 's|Claude Code|Codex CLI|g' \
        "$claude_md" > "$output_path"

    echo "  ✅ Created: AGENTS.md"
}

generate_copilot_instructions() {
    local github_dir="$ROOT_DIR/.github"
    local output_path="$github_dir/copilot-instructions.md"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: .github/copilot-instructions.md (Copilot auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping copilot-instructions.md generation."
        return 0
    fi

    mkdir -p "$github_dir"

    sed \
        -e 's|CLAUDE\.md|copilot-instructions.md|g' \
        -e 's|CLAUDE\.local\.md|copilot-instructions.local.md|g' \
        -e 's|instructions/captain\.md|instructions/generated/copilot-captain.md|g' \
        -e 's|instructions/vice_captain\.md|instructions/generated/copilot-vice_captain.md|g' \
        -e 's|instructions/member\.md|instructions/generated/copilot-member.md|g' \
        -e 's|~/.claude/|~/.copilot/|g' \
        -e 's|\.claude\.json|.copilot/config.json|g' \
        -e 's|\.mcp\.json|.copilot/mcp-config.json|g' \
        -e 's|Claude Code|GitHub Copilot CLI|g' \
        "$claude_md" > "$output_path"

    echo "  ✅ Created: .github/copilot-instructions.md"
}

generate_kimi_instructions() {
    local agents_dir="$ROOT_DIR/agents/default"
    local system_md_path="$agents_dir/system.md"
    local agent_yaml_path="$agents_dir/agent.yaml"
    local claude_md="$ROOT_DIR/CLAUDE.md"

    echo "Generating: agents/default/system.md + agent.yaml (Kimi auto-load)"

    if [ ! -f "$claude_md" ]; then
        echo "  ⚠️  CLAUDE.md not found. Skipping Kimi auto-load generation."
        return 0
    fi

    mkdir -p "$agents_dir"

    sed \
        -e 's|CLAUDE\.md|agents/default/system.md|g' \
        -e 's|CLAUDE\.local\.md|agents/default/system.local.md|g' \
        -e 's|instructions/captain\.md|instructions/generated/kimi-captain.md|g' \
        -e 's|instructions/vice_captain\.md|instructions/generated/kimi-vice_captain.md|g' \
        -e 's|instructions/member\.md|instructions/generated/kimi-member.md|g' \
        -e 's|~/.claude/|~/.kimi/|g' \
        -e 's|\.claude\.json|.kimi/config.json|g' \
        -e 's|\.mcp\.json|.kimi/mcp.json|g' \
        -e 's|Claude Code|Kimi K2 CLI|g' \
        "$claude_md" > "$system_md_path"

    echo "  ✅ Created: agents/default/system.md"

    cat > "$agent_yaml_path" <<'EOFYAML'
# Kimi K2 Agent Configuration
# Auto-generated by build_instructions.sh — do not edit manually
name: multi-agent-captain
description: "Kimi K2 CLI agent for multi-agent-captain system"
model: moonshot-k2.5
system_prompt_file: system.md
tools:
  - file_read
  - file_write
  - shell_exec
  - web_search
EOFYAML

    echo "  ✅ Created: agents/default/agent.yaml"
}

generate_agents_md
generate_copilot_instructions
generate_kimi_instructions

# ============================================================
# Phase 4: Drift Detection
# ============================================================
echo ""
echo "--- Phase 4: Drift Detection ---"

DRIFT_FOUND=0
for tmpl in "$TEMPLATES_DIR"/*.md.tmpl; do
    [ -f "$tmpl" ] || continue
    role_name="$(basename "$tmpl" .md.tmpl)"
    generated="$OUTPUT_DIR/${role_name}.md"
    current="$PARTS_DIR/${role_name}.md"

    if [ -f "$current" ] && [ -f "$generated" ]; then
        if ! diff -q "$current" "$generated" > /dev/null 2>&1; then
            echo "  ⚠️  DRIFT: ${role_name}.md differs from generated version"
            echo "     Run: diff instructions/${role_name}.md instructions/generated/${role_name}.md"
            DRIFT_FOUND=1
        else
            echo "  ✅ ${role_name}.md — in sync"
        fi
    elif [ ! -f "$current" ]; then
        echo "  ℹ️  ${role_name}.md — no current file to compare (new role?)"
    fi
done

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== Build Complete ==="
echo ""
echo "Templates:"
ls "$TEMPLATES_DIR"/*.md.tmpl 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
echo ""
echo "Common sections:"
ls "$COMMON_DIR"/*.md 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
echo ""
echo "Generated instruction files:"
ls -lh "$OUTPUT_DIR"/*.md 2>/dev/null
echo ""
echo "CLI auto-load files:"
[ -f "$ROOT_DIR/AGENTS.md" ] && ls -lh "$ROOT_DIR/AGENTS.md"
[ -f "$ROOT_DIR/.github/copilot-instructions.md" ] && ls -lh "$ROOT_DIR/.github/copilot-instructions.md"
[ -f "$ROOT_DIR/agents/default/system.md" ] && ls -lh "$ROOT_DIR/agents/default/system.md"
[ -f "$ROOT_DIR/agents/default/agent.yaml" ] && ls -lh "$ROOT_DIR/agents/default/agent.yaml"

if [ $DRIFT_FOUND -eq 1 ]; then
    echo ""
    echo "⚠️  Drift detected! Review diffs above and update templates or current files."
    exit 1
fi
