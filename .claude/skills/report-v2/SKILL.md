---
name: report-v2
description: "Write task completion reports in v2.0 YAML format. Use PROACTIVELY when a member completes a task and needs to write a report YAML file."
user-invocable: false
---

# Report v2.0 Format

## Task

タスク完了時に v2.0 フォーマットの報告 YAML を作成する。

## Instructions

### 1. 報告ファイルパス

```
queue/reports/${AGENT_ID}_report.yaml
```

### 2. YAML テンプレート

```yaml
worker_id: member1
task_id: subtask_001
parent_cmd: cmd_035
timestamp: "2026-01-25T10:15:00"  # date "+%Y-%m-%dT%H:%M:%S" で取得
status: done  # done | failed | blocked
commit_info:
  branch: "feature/writing-ux-wave4"
  commit_hash: "4b81b3b"
  pushed_to: "origin/feature/writing-ux-wave4"

# === MANDATORY: Changed Files ===
changed_files:
  - path: "src/components/ChatPane.tsx"
    action: "modified"  # created | modified | deleted
  - path: "src/hooks/useChat.ts"
    action: "created"

# === MANDATORY: Verification ===
verification:
  build_result: "pass"           # pass | fail
  build_command: "yarn build"    # 実行したコマンド
  dev_server_check: "pass"       # pass | fail | skipped
  dev_server_url: "http://localhost:3000/workspace"
  error_console: "no_errors"     # no_errors | has_warnings | has_errors

# === MANDATORY: TODO Scan ===
todo_scan:
  count: 0              # プロジェクト内の // TODO 総数
  new_todos: []         # 自分が追加した TODO（なければ空配列）

result:
  summary: "WBS 2.3節 完了しました"
  notes: "Additional details"

skill_candidate:
  found: false  # MANDATORY — true/false
```

### 3. 必須フィールド

worker_id, task_id, parent_cmd, status, timestamp, **changed_files, verification, todo_scan**, result, skill_candidate

### 4. changed_files（必須）

- 作成・修正・削除した**全ファイル**を記録
- action: `created` | `modified` | `deleted`
- 空リストは不正（変更なし = done 報告すべきでない）

### 5. verification（必須）

| フィールド | 値 | 判定基準 |
|-----------|-----|---------|
| build_result | pass / fail | `yarn build`（または相当コマンド）成功？ |
| build_command | string | 実行したコマンド |
| dev_server_check | pass / fail / skipped | devサーバーでテスト？docs-only なら skipped 可 |
| dev_server_url | string | テストしたURL |
| error_console | no_errors / has_warnings / has_errors | ブラウザコンソール状態 |

**"pass" 基準:**
- build_result: pass — ビルド成功
- dev_server_check: pass — 機能が意図通り動作
- error_console: no_errors — 自分の変更に起因するエラーなし

**以下の場合 "done" 報告してはならない:**
- ビルド失敗
- devサーバーで機能が動作しない
- コンソールに自分の変更起因のエラー

### 6. todo_scan（必須）

```bash
grep -r "// TODO" src/ | wc -l        # 総数
grep -rn "// TODO" src/ | grep "..."   # 自分が追加した TODO
```

- count: プロジェクト内の `// TODO` 総数
- new_todos: 自分が追加した TODO（ファイルパス+行番号）
- 既存 TODO が多い場合は `result.notes` に記載

### 7. 隊長による却下条件

| 条件 | 理由 |
|------|------|
| changed_files が空 | 変更なし = 作業未完了 |
| build_result が fail | ビルド失敗 = 未完了 |
| dev_server_check が fail | 機能未動作 = 未完了 |
| error_console が has_errors | 品質問題 |
| todo_scan 未記載 | フォーマット不備 |
| skill_candidate 未記載 | フォーマット不備 |

却下された場合: 隊長から inbox で差し戻し理由が届く。修正して再提出。

## Notes

- timestamp は必ず `date "+%Y-%m-%dT%H:%M:%S"` で取得。推測禁止。
- skill_candidate.found は必ず true/false を記載。見つからなくても false と明記。
