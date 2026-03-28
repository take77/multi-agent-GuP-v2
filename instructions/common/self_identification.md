## Self-Identification (CRITICAL)

**Always confirm your ID first:**
```bash
tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
```

Why `@agent_id` not `pane_index`: pane_index shifts on pane reorganization. @agent_id is set by gup_v2_launch.sh at startup and never changes.
