# Bridge Specification — Agent Teams ↔ YAML Conversion Protocol

**Version**: 1.0
**Last Updated**: 2026-02-16
**Scope**: multi-agent-GuP-v2 (Phase 2)

## Overview

このドキュメントは、Agent Teams プロトコルと tmux 作業層 YAML 間の双方向変換ブリッジの動作仕様を定義します。
`scripts/bridge_relay.sh` が変換処理を担当し、Captain がブリッジモード時にこのスクリプトを呼び出します。

---

## 1. Message Conversion Rules (Downward: Agent Teams → YAML)

### 1.1 Conversion Flow

```
Agent Teams Message (Battalion_Commander)
  ↓
TeammateTool.list() → Captain receives message
  ↓
bash scripts/bridge_relay.sh down <captain_id> <cluster_session> <message_content> <project> <priority> <acceptance_criteria>
  ↓
Python script generates cmd_XXX in queue/captain_to_vice_captain.yaml
  ↓
inbox_write.sh → Vice_Captain woken up
  ↓
Vice_Captain processes cmd
```

### 1.2 Field Mapping

| Agent Teams Input | YAML Field | Transformation Rule |
|-------------------|------------|---------------------|
| Message content | `purpose` | First sentence or summary line |
| Message content | `command` | Full message content as-is |
| Argument: `project` | `project` | Project ID (e.g., "gup-v2-bridge-test") |
| Argument: `priority` | `priority` | "high", "medium", or "low" (default: "medium") |
| Argument: `acceptance_criteria` | `acceptance_criteria` | Split by newline into list; default: "No acceptance criteria provided" |
| Auto-generated | `id` | `cmd_XXX` (auto-increment from max existing ID + 1) |
| Current timestamp | `timestamp` | ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`) |
| Fixed value | `status` | Always "pending" on creation |
| **Fixed value** | `source` | **Always "agent_teams"** (security marker) |

### 1.3 Example YAML Output

```yaml
- id: cmd_048
  timestamp: "2026-02-16T01:23:45"
  purpose: "Agent Teams ブリッジテストが完了し、下り・上り両方向の変換が動作確認されること"
  acceptance_criteria:
    - "bridge_relay.sh down でメッセージから YAML に変換されること"
    - "bridge_relay.sh up でレポートから Agent Teams 報告に変換されること"
  command: |
    Agent Teams からのテスト指示をブリッジ経由で実行。
    完了後、Agent Teams に結果を返却せよ。
  project: gup-v2-bridge-test
  priority: high
  status: pending
  source: agent_teams
```

### 1.4 Python Script Behavior (bridge_relay.sh lines 76-134)

- **YAML safe_load**: Existing queue file is loaded safely (handles empty/malformed files)
- **ID auto-increment**: Scans all existing `cmd_XXX` entries, finds max number, adds 1
- **Atomic write**: Uses `tempfile.mkstemp()` + `os.replace()` to prevent partial writes during concurrent access
- **Lock protection**: `flock -w 5` (5-second timeout) ensures serialized access to queue file

---

## 2. source Field Management

### 2.1 Attachment Rules

| Condition | source Field | Rationale |
|-----------|--------------|-----------|
| Message comes from Agent Teams (bridge_relay.sh down) | **Must be "agent_teams"** | Enables upward relay filtering |
| Message comes from Lord (direct Captain input) | **Omitted** | No relay to Agent Teams needed |
| cmd created by Vice_Captain decomposition | **Inherits parent cmd's source** | Maintains relay lineage |

**Who sets the field?**
- **bridge_relay.sh down**: Automatically adds `source: agent_teams` (line 112)
- **Captain**: Never manually adds this field for Lord-originated cmds
- **Vice_Captain/Member**: Never adds or modifies this field (read-only)

### 2.2 Relay Rules (Upward Direction)

Captain checks `source` field before relaying completion reports:

```yaml
# RELAY to Agent Teams (source present)
- id: cmd_048
  status: done
  source: agent_teams  # ← MUST relay via TeammateTool.write()

# DO NOT relay (source absent)
- id: cmd_049
  status: done
  # No source field → Lord-originated cmd, no Agent Teams relay
```

### 2.3 Security Considerations

- **Immutability**: Vice_Captain and Member must treat `source: agent_teams` as **read-only**
- **Forgery prevention**: Only `bridge_relay.sh down` can add this field (enforced by Captain)
- **Relay privilege**: Only cmds with `source: agent_teams` are relayed to Agent Teams (prevents accidental disclosure of internal cmds)

---

## 3. Error Handling

### 3.1 Retry Policy

**Downward conversion (bridge_relay.sh lines 66-161)**:

| Attempt | Wait Time | Reason |
|---------|-----------|--------|
| 1st | 0s | Immediate execution |
| 2nd | 1s sleep | Lock timeout or Python error |
| 3rd | 1s sleep | Final retry |
| Failure | Exit 1 + log | All retries exhausted |

**Lock acquisition**: `flock -w 5` (5-second timeout per attempt)

**Upward conversion**: No retry needed (read-only operation)

### 3.2 Error Scenarios

| Error Type | Detection | Recovery Action | Log Level |
|------------|-----------|-----------------|-----------|
| Lock timeout | `flock` returns non-zero | Retry up to 3 times | WARN (attempt 1-2), ERROR (attempt 3) |
| Python YAML parse error | `yaml.safe_load()` exception | Exit 1, log full traceback | ERROR |
| Missing required argument | Bash argument check (lines 16-24, 38-45) | Exit 1, print usage | ERROR |
| Invalid direction | `[ "$DIRECTION" != "down" ] && [ "$DIRECTION" != "up" ]` | Exit 1, print error | ERROR |
| Queue file write failure | `os.replace()` exception | Exit 1, log error | ERROR |
| inbox_write.sh failure | Non-zero exit from `bash scripts/inbox_write.sh` | Continue (message saved, nudge failed) | WARN |

**Note**: If `inbox_write.sh` fails but YAML was successfully written, the cmd is still valid. Vice_Captain's self-watch or escalation hook will eventually pick it up.

### 3.3 Log Output Format

**Log function (bridge_relay.sh lines 32-34)**:

```bash
log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [bridge_relay/$DIRECTION] $*" | tee -a "$LOG_FILE" >&2
}
```

**Log destination**:
- `stderr` (visible in Captain's tmux pane)
- `$LOG_FILE` (persistent log file)

**Example log entries**:

```
[2026-02-16T01:23:45] [bridge_relay/down] DOWN SUCCESS: cmd_048 created (project=gup-v2-bridge-test, priority=high)
[2026-02-16T01:24:12] [bridge_relay/down] Lock timeout (attempt 1/3), retrying...
[2026-02-16T01:24:13] [bridge_relay/down] ERROR: Failed to acquire lock after 3 attempts
[2026-02-16T01:25:00] [bridge_relay/up] UP SUCCESS: cmd_048 [done] — テスト完了、両方向変換動作確認済み
```

---

## 4. Log Format Specification

### 4.1 File Path

**Pattern**: `logs/bridge/${CAPTAIN_ID}_$(date +%Y%m%d).log`

**Examples**:
- `logs/bridge/miho_20260216.log`
- `logs/bridge/darjeeling_20260216.log`

**Rotation**: Daily (new file per date, no size-based rotation)

**Directory creation**: `mkdir -p "$LOG_DIR"` (line 28) ensures directory exists before first write

### 4.2 Log Entry Format

```
[TIMESTAMP] [bridge_relay/DIRECTION] MESSAGE
```

**Fields**:
- `TIMESTAMP`: ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`)
- `DIRECTION`: "down" or "up"
- `MESSAGE`: Free-form text (success/error/warning)

### 4.3 Standard Log Patterns

| Pattern | Meaning | Example |
|---------|---------|---------|
| `DOWN SUCCESS: cmd_XXX created (project=..., priority=...)` | Downward conversion succeeded | cmd_048 created |
| `UP SUCCESS: cmd_XXX [status] — summary` | Upward relay succeeded | cmd_048 [done] — テスト完了 |
| `Lock timeout (attempt X/3), retrying...` | flock timeout, will retry | Concurrent access detected |
| `ERROR: Failed to acquire lock after 3 attempts` | All retries exhausted | Manual investigation needed |
| `ERROR: down mode requires message_content and project` | Missing required argument | Caller error |
| `ERROR: {Python traceback}` | Python script failure | YAML parse or write error |

---

## 5. Phase 0 Integration

### 5.1 Auto-Applied Features

Agent Teams 経由で作成された cmd（`source: agent_teams`）には、通常の tmux 側タスクと同じく以下の Phase 0 機能が**自動適用**されます:

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Stop Hook** | 2-4 分間無応答で強制 nudge（Escape × 2 + 再送信） | inbox_watcher.sh escalation stages |
| **Full Scan** | 4 分以上無応答で `/clear` 送信（完全セッションリセット） | inbox_watcher.sh stage 3 escalation |
| **F006 Enforcement** | Vice_Captain の inbox_write 禁止（dashboard.md 経由でのみ報告） | vice_captain.md forbidden_actions |
| **Redo Protocol** | 品質不合格時の再割り当て（`redo_of` フィールドによる追跡） | vice_captain.md quality check |

**重要**: Agent Teams からのタスクも、内部タスクと同じ品質基準とエスカレーション機構が適用されます。特別扱いはありません。

### 5.2 Quality Assurance

- **Acceptance Criteria Check**: Vice_Captain は `source: agent_teams` の有無に関わらず、すべての cmd で acceptance_criteria を検証
- **Redo on Failure**: 品質不合格時は通常と同じく redo タスクが作成され、元の cmd_id に `redo_of` フィールドが記録される
- **Agent Teams Report**: Redo が発生した場合、最終的に成功した cmd のみ Agent Teams に報告（中間失敗は報告しない）

---

## 6. Upward Conversion (YAML → Agent Teams)

### 6.1 Conversion Flow

```
Vice_Captain marks cmd as done in queue/captain_to_vice_captain.yaml
  ↓
Vice_Captain updates dashboard.md with completion report
  ↓
Captain reads dashboard.md
  ↓
Captain checks if cmd has `source: agent_teams`
  ↓ (YES)
bash scripts/bridge_relay.sh up <captain_id> <cluster_session> <cmd_id> <status> <summary>
  ↓
Script generates formatted report message
  ↓
Captain uses TeammateTool.write() to send report to Battalion_Commander
```

### 6.2 Field Extraction

| YAML Field | Report Component | Example |
|------------|------------------|---------|
| `id` | cmd_id in message | "cmd_048" |
| `status` | Status indicator | "done" / "failed" |
| `purpose` | Summary header | "Agent Teams ブリッジテスト" |
| `acceptance_criteria` | Achievement checklist | "✓ 下り変換動作確認\n✓ 上り変換動作確認" |
| dashboard.md notes | Detailed summary | "両方向変換正常動作。ログ確認済み。" |

### 6.3 Report Message Format (bridge_relay.sh lines 175-178)

```bash
REPORT_MESSAGE="${CAPTAIN_ID}隊報告: $CMD_ID [$STATUS] — $SUMMARY"
```

**Example**:
```
miho隊報告: cmd_048 [done] — Agent Teams ブリッジテスト完了。両方向変換動作確認済み。
```

**Captain's TeammateTool.write() Template**:

```
隊長より報告:

cmd_XXX（<purpose>）が完了しました。

<acceptance_criteria achievement summary>

詳細: <dashboard.md link or key findings>
```

### 6.4 No-Relay Conditions

Captain は以下の場合、Agent Teams に報告しません:

| Condition | Reason |
|-----------|--------|
| `source: agent_teams` フィールドが存在しない | Lord 発信 cmd（内部専用） |
| `status: pending` または `status: in_progress` | 未完了（報告不要） |
| `status: reassigned` | 別の Vice_Captain に委譲済み（最終完了時に報告） |
| `redo_of` フィールドが存在 | Redo タスク（元タスク完了時に報告） |

---

## 7. Implementation Consistency Checklist

作成済みファイルとの整合性確認:

- [x] **bridge_relay.sh down mode**: Field mapping matches Python script (lines 76-134)
- [x] **bridge_relay.sh up mode**: Report format matches script output (lines 175-178)
- [x] **captain.md Bridge Mode section**: source field rules match (lines 528-534)
- [x] **captain.md Phase 0 Integration**: Auto-applied features match (lines 536-544)
- [x] **Log format**: Matches log() function implementation (lines 32-34)
- [x] **Error handling**: Retry policy matches script logic (lines 66-161)

---

## 8. Usage Examples

### 8.1 Downward Conversion (Agent Teams → YAML)

**Scenario**: Battalion_Commander sends "GuP-v2 の inbox_watcher.sh を改修して self-watch 機能を追加せよ"

**Captain executes**:

```bash
bash scripts/bridge_relay.sh down miho main-cluster \
  "GuP-v2 の inbox_watcher.sh を改修して self-watch 機能を追加せよ" \
  "gup-v2-self-watch" \
  "high" \
  "inbox_watcher.sh に self-watch が実装されること
vice_captain.md に self-watch 説明が追記されること
テストで self-watch 動作が確認されること"
```

**Result**:
- `queue/captain_to_vice_captain.yaml` に cmd_049 が追加される
- `source: agent_teams` が自動付与される
- `logs/bridge/miho_20260216.log` に成功ログが記録される
- Vice_Captain (pekoe) が inbox nudge で起動される

### 8.2 Upward Conversion (YAML → Agent Teams)

**Scenario**: Vice_Captain が cmd_049 を完了し、dashboard.md を更新

**Captain confirms**:
1. `queue/captain_to_vice_captain.yaml` で `status: done` を確認
2. `source: agent_teams` が存在することを確認
3. dashboard.md で acceptance_criteria 達成を確認

**Captain executes**:

```bash
bash scripts/bridge_relay.sh up miho main-cluster \
  "cmd_049" \
  "done" \
  "self-watch 機能実装完了。inbox_watcher.sh に inotifywait による自己監視を追加し、テストで動作確認済み。"
```

**Captain sends via TeammateTool.write()**:

```
miho隊より報告:

cmd_049（GuP-v2 inbox_watcher.sh self-watch 機能追加）が完了しました。

✓ inbox_watcher.sh に self-watch が実装されること
✓ vice_captain.md に self-watch 説明が追記されること
✓ テストで self-watch 動作が確認されること

詳細: master_dashboard.md の cmd_049 セクションをご確認ください。
```

---

## 9. Troubleshooting

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| bridge_relay.sh 実行時に "Permission denied" | 実行権限不足 | `chmod +x scripts/bridge_relay.sh` |
| "Failed to acquire lock after 3 attempts" | Concurrent access or stale lock | `rm queue/captain_to_vice_captain.yaml.lock` |
| Agent Teams に報告が届かない | `source: agent_teams` が欠落 | Captain が手動で TeammateTool.write() 実行 |
| Vice_Captain が応答しない | inbox_watcher.sh 停止 or tmux pane 消失 | 既存のエスカレーション機構に任せる（4 分待機） |
| Python YAML parse error | Malformed YAML file | `queue/captain_to_vice_captain.yaml` を手動修正 |
| inbox_write.sh が WARN を返す | inbox ファイル lock timeout | Vice_Captain の自己監視が代替配信（問題なし） |

---

**End of Specification**
