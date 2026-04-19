# Communication Protocol

## Mailbox System (inbox_write.sh)

Agent-to-agent communication uses file-based mailbox:

```bash
bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>
```

Examples:
```bash
# Captain → Vice Captain
bash scripts/inbox_write.sh vice_captain "cmd_048を書いた。実行せよ。" cmd_new captain

# Member → Vice Captain
bash scripts/inbox_write.sh vice_captain "隊員5号、任務完了。報告YAML確認されたし。" report_received member5

# Vice Captain → Member
bash scripts/inbox_write.sh member3 "タスクYAMLを読んで作業開始せよ。" task_assigned vice_captain
```

Delivery is handled by `inbox_watcher.sh` (infrastructure layer).
**Agents NEVER call tmux send-keys directly.**

## Delivery Mechanism

Two layers:
1. **Message persistence**: `inbox_write.sh` writes to `queue/inbox/{agent}.yaml` with flock. Guaranteed.
2. **Wake-up signal**: `inbox_watcher.sh` detects file change via `inotifywait` → sends SHORT nudge via send-keys (timeout 5s)

The nudge is minimal: `inboxN` (e.g. `inbox3` = 3 unread). That's it.
**Agent reads the inbox file itself.** Watcher never sends message content via send-keys.

Special cases (CLI commands sent directly via send-keys):
- `type: clear_command` → sends `/clear` + Enter + content
- `type: model_switch` → sends the /model command directly

## Inbox Processing Protocol (vice_captain/member)

When you receive `inboxN` (e.g. `inbox3`):
1. `Read queue/inbox/{your_id}.yaml`
2. Find all entries with `read: false`
3. Process each message according to its `type`
4. Update each processed entry: `read: true` (use Edit tool)
5. Resume normal workflow

**Also**: After completing ANY task, check your inbox for unread messages before going idle.
This is a safety net — even if the wake-up nudge was missed, messages are still in the file.

## Report Flow (interrupt prevention)

| Direction | Method | Reason |
|-----------|--------|--------|
| Member → Vice Captain | Report YAML + inbox_write | File-based notification |
| Vice Captain → Captain/Lord | dashboard.md update only | **inbox to captain FORBIDDEN** — prevents interrupting Lord's input |
| Top → Down | YAML + inbox_write | Standard wake-up |

## File Operation Rule

**Always Read before Write/Edit.** Claude Code rejects Write/Edit on unread files.

## ACK Abolition Rule（2026-04-19 制定）

**原則: ack 型メッセージは廃止。** メッセージ受領は `read: true` マークで完結させる。

### 例外（ack 送信を許可する 3 種）

以下の節目のみ、ack 送信が許可される:

| type | 用途 | 送信タイミング |
|------|------|---------------|
| `merge_complete` | PR が main または統合ブランチに merge された通知 | merge 直後、関係者全員に 1 回 |
| `task_assigned_ack` | タスク正式受領通知（隊員 → 隊長/副隊長、実装に着手する意思表示） | タスク YAML 受領 + 着手前 1 回 |
| `emergency_stop_ack` | 緊急停止命令の受領確認（全軍停止時の到達確認） | 停止命令受領後 1 回のみ |

### 違反時

上記 3 種以外の ack は制度違反。送信者は自主削除、繰り返す場合は anzu に報告。

### 根拠

2026-04-19 の運用データで通信量の 30%（360/1195 通）が ack 往復であることが判明。
意思決定 1 回あたり 3-4 往復の受領確認が発生していた。

---

## Inbox Communication Rules

### Sending Messages

```bash
bash scripts/inbox_write.sh <target> "<message>" <type> <from>
```

**No sleep interval needed.** No delivery confirmation needed. Multiple sends can be done in rapid succession — flock handles concurrency.

### Report Notification Protocol

After writing report YAML, notify Vice Captain:

```bash
bash scripts/inbox_write.sh vice_captain "隊員{N}号、任務完了しました。報告書を確認してください。" report_received member{N}
```

That's it. No state checking, no retry, no delivery verification.
The inbox_write guarantees persistence. inbox_watcher handles delivery.
