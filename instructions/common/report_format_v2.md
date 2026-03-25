## Report Format (v2.0)

> **See `templates/report_v2.yaml.template` for the full specification.**

**v2.0 upgrade**: Reports now require comprehensive verification fields to prevent "build success ≠ actual functionality" issues discovered in Week 2.

```yaml
worker_id: member1
task_id: subtask_001
parent_cmd: cmd_035
timestamp: "2026-01-25T10:15:00"  # from date command
status: done  # done | failed | blocked
commit_info:
  branch: "feature/writing-ux-wave4"
  commit_hash: "4b81b3b"
  pushed_to: "origin/feature/writing-ux-wave4"

# === NEW v2.0: Changed Files (MANDATORY) ===
changed_files:
  - path: "src/components/ChatPane.tsx"
    action: "modified"  # created | modified | deleted
  - path: "src/hooks/useChat.ts"
    action: "created"

# === NEW v2.0: Verification (MANDATORY) ===
verification:
  build_result: "pass"           # pass | fail
  build_command: "yarn build"    # Exact command you ran
  dev_server_check: "pass"       # pass | fail | skipped
  dev_server_url: "http://localhost:3000/workspace"
  error_console: "no_errors"     # no_errors | has_warnings | has_errors

# === NEW v2.0: TODO Scan (MANDATORY) ===
todo_scan:
  count: 0              # Total // TODO count in the project
  new_todos: []         # TODOs YOU added (empty if none)

result:
  summary: "WBS 2.3節 完了しました"
  files_modified:  # Optional: deprecated, use changed_files instead
    - "/path/to/file"
  notes: "Additional details"

skill_candidate:
  found: false  # MANDATORY — true/false
  # If true, also include:
  name: null        # e.g., "readme-improver"
  description: null # e.g., "Improve README for beginners"
  reason: null      # e.g., "Same pattern executed 3 times"
```

**Required fields**: worker_id, task_id, parent_cmd, status, timestamp, **changed_files, verification, todo_scan**, result, skill_candidate.

### v2.0 Field Details

#### changed_files (MANDATORY)
- **Purpose**: Track ALL files you created, modified, or deleted
- **Empty list is INVALID**: If you changed nothing, why report done?
- **action values**: `created`, `modified`, `deleted`

#### verification (MANDATORY)
**The core of v2.0**: Prove your deliverable works, not just "builds".

| Field | Values | Judgment Criteria |
|-------|--------|-------------------|
| build_result | pass / fail | `yarn build` (or equivalent) succeeded? |
| build_command | string | Exact command you ran |
| dev_server_check | pass / fail / skipped | Did you test in dev server? Use `skipped` only if task doesn't need runtime testing (e.g., docs-only change) |
| dev_server_url | string | URL you accessed (if applicable) |
| error_console | no_errors / has_warnings / has_errors | Browser console state after testing |

**"pass" criteria**:
- `build_result: pass` — Build succeeded with no errors
- `dev_server_check: pass` — Feature works as intended in dev server
- `error_console: no_errors` — No console errors related to your changes

**Don't report "done" if**:
- Build fails
- Feature doesn't work in dev server
- Console shows errors from your changes

#### todo_scan (MANDATORY)
**Purpose**: Detect incomplete work left as TODO comments.

```bash
# Count TODOs in the project
grep -r "// TODO" src/ | wc -l

# List your new TODOs
grep -rn "// TODO" src/ | grep "your new todos"
```

- `count`: Total `// TODO` count in the project
- `new_todos`: TODOs **you added** (empty array if none)
- If `count > 0` and it's pre-existing → note in `result.notes`
- If you added new TODOs → list them with file path and line number

### Report Rejection (Captain Will Reject If...)

| Condition | Why Rejected |
|-----------|-------------|
| changed_files is empty | No changes = no work done |
| verification.build_result is "fail" | Build failure = task incomplete |
| verification.dev_server_check is "fail" | Feature doesn't work = task incomplete |
| verification.error_console is "has_errors" | Console errors = quality issue |
| todo_scan missing | Incomplete report format |
| skill_candidate missing | Incomplete report format |

**If rejected**: Captain will send inbox message with rejection reason. Fix the issues and resubmit.
