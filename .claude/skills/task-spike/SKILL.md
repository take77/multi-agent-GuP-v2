---
name: task-spike
description: "不確実性のあるタスクに対し調査専用タスク（spike）を作成する。spike のアウトプットはコードではなく実装計画。隊長がタスク分解前に使用。「spike作成」「調査タスク」「不確実」で起動。"
user-invocable: false
---

# Task Spike

## Task

不確実性のあるタスクに対し、実装前の調査タスク（spike）を作成する。

## When to Use

- 要件が曖昧で、複数の実装アプローチが考えられる
- 対象コードベースに不案内で、構造把握が先に必要
- 技術選定が未確定（ライブラリ選択、アーキテクチャ判断等）
- 過去に同種タスクで redo が発生した

## Instructions

### 1. Spike タスク YAML の作成

```yaml
task:
  task_id: spike_{parent_cmd}_{short_desc}
  parent_cmd: cmd_XXX
  bloom_level: L4
  type: spike
  description: |
    【調査目的】何を明らかにするか（1文）
    【調査スコープ】どのファイル・モジュールを調べるか
    【期待アウトプット】実装計画（approach フィールドに記載）
  target_path: "/path/to/investigate"
  target_branch: "cmd_XXX/{agent_id}/spike"
  time_box: "30min"
  status: assigned
  timestamp: "ISO 8601"
```

### 2. Spike の制約

- **タイムボックス**: 最大 30 分。超えたら分かった範囲で報告
- **アウトプット**: report YAML の `result:` に実装計画を書く。コード変更は原則なし
- **実装計画の必須項目**:
  - 推奨アプローチ（1つに絞る）
  - 変更対象ファイル一覧
  - 依存関係・リスク
  - サブタスク分解案（並列可能な単位で）

### 3. Spike 完了後の流れ

1. spike の report を受領
2. 実装計画を元に本実装タスクを分解・dispatch
3. spike で判明した情報を各タスクの description に反映

## Notes

- spike は調査であり実装ではない。コード変更を含む場合は spike ではなく通常タスク
- spike の bloom_level は原則 L4（分析）。L5-L6 が必要なら spike 自体を分割
