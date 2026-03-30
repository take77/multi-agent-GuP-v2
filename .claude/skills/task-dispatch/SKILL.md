---
name: task-dispatch
description: "Dispatch tasks to squad members via YAML + inbox. Use PROACTIVELY when captain needs to assign a new task: write task YAML, send inbox notification, update dashboard."
user-invocable: false
---

# Task Dispatch

## Task

隊長が隊員にタスクを配信する。YAML書き込み → inbox_write → dashboard更新の3ステップ。

## Instructions

### 1. タスク配信の3ステップ（必須 — 1つでも欠けたら未配信）

**Step 1**: タスク YAML 書き込み
```bash
# queue/tasks/${AGENT_ID}.yaml に書き込む
```

**Step 2**: inbox_write 実行
```bash
bash scripts/inbox_write.sh ${member_name} "タスクYAMLを読んで作業を開始してください。${タスク概要}" task_assigned ${captain_name}
```

**Step 3**: dashboard.md 更新
- 進行中セクションにタスク追加

### 2. タスク YAML フォーマット

```yaml
# 依存なしタスク
task:
  task_id: subtask_001
  parent_cmd: cmd_001
  bloom_level: L3        # MANDATORY — L1-L3=Sonnet, L4-L6=Opus
  worktree_path: "worktrees/member_name"  # optional
  description: "タスクの詳細説明"
  target_path: "/path/to/target"
  target_branch: "feature/branch-name"
  echo_message: "message"  # optional
  status: assigned
  timestamp: "2026-01-25T12:00:00"

# 依存ありタスク
task:
  task_id: subtask_003
  parent_cmd: cmd_001
  bloom_level: L6
  blocked_by: [subtask_001, subtask_002]
  description: "前工程の結果を統合"
  target_path: "/path/to/target"
  status: blocked          # blocked_by がある場合は blocked
  timestamp: "2026-01-25T12:00:00"
```

### 3. 必須フィールド

task_id, parent_cmd, bloom_level, description, target_path, target_branch, status, timestamp

### 4. status 遷移ルール

```
依存なし:  idle → assigned → done/failed
依存あり:  idle → blocked → assigned → done/failed
```

| status | 意味 | inbox_write? |
|--------|------|-------------|
| idle | 未割当 | No |
| blocked | 依存待ち | **No**（まだ作業不可） |
| assigned | 作業可能 | Yes |
| done | 完了 | — |
| failed | 失敗 | — |

### 5. 並行配信

- 独立タスク → 複数隊員に同時配信
- 依存タスク → `blocked_by` で順序制御
- 1隊員 = 1タスク（完了まで）
- 複数隊員への連続 inbox_write は OK — flock が並行性を保証

### 6. blocked タスクの解除

報告受領時:
1. 完了した task_id を記録
2. 全 task YAML の `status: blocked` をスキャン
3. `blocked_by` に完了 task_id があれば削除。リスト空なら `assigned` に変更 + inbox_write

## Notes

- dashboard のみの更新は配信ではない。YAML + inbox_write が必須。
- L4+ タスクは配信前に model_switch で Opus 昇格すること。
- timestamp は `date "+%Y-%m-%dT%H:%M:%S"` で取得。
