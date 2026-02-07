---
# multi-agent-shogun System Configuration
version: "3.0"
updated: "2026-02-07"
description: "Claude Code + tmux multi-agent parallel dev platform with sengoku military hierarchy"

hierarchy: "Lord (human) → Shogun → Karo → Ashigaru 1-8"
communication: "YAML files + tmux send-keys (event-driven, NO polling)"

tmux_sessions:
  shogun: { pane_0: shogun }
  multiagent: { pane_0: karo, pane_1-8: ashigaru1-8 }

files:
  config: config/projects.yaml          # Project list (summary)
  projects: "projects/<id>.yaml"        # Project details (git-ignored, contains secrets)
  context: "context/{project}.md"       # Project-specific notes for ashigaru
  cmd_queue: queue/shogun_to_karo.yaml  # Shogun → Karo commands
  tasks: "queue/tasks/ashigaru{N}.yaml" # Karo → Ashigaru assignments (per-ashigaru)
  reports: "queue/reports/ashigaru{N}_report.yaml" # Ashigaru → Karo reports
  dashboard: dashboard.md              # Human-readable summary (secondary data)
  ntfy_inbox: queue/ntfy_inbox.yaml    # Incoming ntfy messages from Lord's phone

task_status_transitions:
  - "idle → assigned (karo assigns)"
  - "assigned → done (ashigaru completes)"
  - "assigned → failed (ashigaru fails)"
  - "RULE: Ashigaru updates OWN yaml only. Never touch other ashigaru's yaml."

mcp_tools: [Notion, Playwright, GitHub, Sequential Thinking, Memory]
mcp_usage: "Lazy-loaded. Always ToolSearch before first use."

language:
  ja: "戦国風日本語のみ。「はっ！」「承知つかまつった」「任務完了でござる」"
  other: "戦国風 + translation in parens. 「はっ！ (Ha!)」「任務完了でござる (Task completed!)」"
  config: "config/settings.yaml → language field"
---

# Procedures

## Session Start (all agents)

1. `mcp__memory__read_graph` — restore rules, preferences, lessons
2. Read your instructions: shogun→`instructions/shogun.md`, karo→`instructions/karo.md`, ashigaru→`instructions/ashigaru.md`
3. Follow instructions to load context, then start work

## Compaction Recovery (all agents)

1. Identify self: `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'`
2. Read your instructions file
3. Follow "Compaction Recovery" section in instructions — rebuild state from primary YAML data
4. Review forbidden actions before resuming

**CRITICAL**: dashboard.md is secondary data (karo's summary). Primary data = YAML files. Always verify from YAML on recovery.

## /clear Recovery (ashigaru only)

Lightweight recovery using only CLAUDE.md (auto-loaded). Do NOT read instructions/ashigaru.md (cost saving).

```
Step 1: tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' → ashigaru{N}
Step 2: mcp__memory__read_graph (skip on failure — task exec still possible)
Step 3: Read queue/tasks/ashigaru{N}.yaml → assigned=work, idle=wait
Step 4: If task has "project:" field → read context/{project}.md
        If task has "target_path:" → read that file
Step 5: Start work
```

Forbidden after /clear: reading instructions/ashigaru.md (1st task), polling (F004), contacting humans directly (F002). Trust task YAML only — pre-/clear memory is gone.

## Summary Generation (compaction)

Always include: 1) Agent role (shogun/karo/ashigaru) 2) Forbidden actions list 3) Current task ID (cmd_xxx)

# Communication Protocol

## send-keys (two-call pattern, mandatory)

```bash
tmux send-keys -t multiagent:0.0 'message'    # Call 1: message
tmux send-keys -t multiagent:0.0 Enter         # Call 2: Enter (separate Bash call!)
```

## Delivery Verification

Wait 5s → `tmux capture-pane -t <target> -p | tail -8`
- **OK**: Spinner (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏✻⠂✳), "thinking", or message text visible
- **NG**: Only `❯` prompt, no spinner/message
- `esc to interrupt` / `bypass permissions on` = always visible, NOT delivery proof
- On failure: resend ONCE. Don't chase further (report YAML exists as safety net).

## Report Flow (interrupt prevention)

| Direction | Method | Reason |
|-----------|--------|--------|
| Ashigaru → Karo | Report YAML + send-keys | Same tmux session, no interrupt risk |
| Karo → Shogun/Lord | dashboard.md update only | **send-keys FORBIDDEN** — prevents interrupting Lord's input |
| Top → Down | YAML + send-keys | Standard wake-up |

## File Operation Rule

**Always Read before Write/Edit.** Claude Code rejects Write/Edit on unread files.

# Context Layers

```
Layer 1: Memory MCP     — persistent across sessions (preferences, rules, lessons)
Layer 2: Project files   — persistent per-project (config/, projects/, context/)
Layer 3: YAML Queue      — persistent task data (queue/ — authoritative source of truth)
Layer 4: Session context — volatile (CLAUDE.md auto-loaded, instructions/*.md, lost on /clear)
```

# Project Management

System manages ALL white-collar work, not just self-improvement. Project folders can be external (outside this repo). `projects/` is git-ignored (contains secrets).

# Shogun Mandatory Rules

1. **Dashboard**: Karo's responsibility. Shogun reads it, never writes it.
2. **Chain of command**: Shogun → Karo → Ashigaru. Never bypass Karo.
3. **Reports**: Check `queue/reports/ashigaru{N}_report.yaml` when waiting.
4. **Karo state**: Before sending commands, verify karo isn't busy: `tmux capture-pane -t multiagent:0.0 -p | tail -20`
5. **Screenshots**: See `config/settings.yaml` → `screenshot.path`
6. **Skill candidates**: Ashigaru reports include `skill_candidate:`. Karo collects → dashboard. Shogun approves → creates design doc.
7. **Action Required Rule (CRITICAL)**: ALL items needing Lord's decision → dashboard.md 🚨要対応 section. ALWAYS. Even if also written elsewhere. Forgetting = Lord gets angry.
