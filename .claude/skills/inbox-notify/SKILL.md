---
name: inbox-notify
description: "Send inbox notifications to other agents via inbox_write.sh. Use PROACTIVELY after task completion to notify captain, or when sending any inter-agent message."
user-invocable: false
---

# Inbox Notify

## Task

エージェント間のメッセージ送信を inbox_write.sh 経由で行う。

## Instructions

### 1. 呼び出し構文

```bash
bash scripts/inbox_write.sh <target_agent> "<message>" <type> <from>
```

| 引数 | 説明 | 例 |
|------|------|-----|
| target_agent | 宛先エージェント名（固有名を使う） | maho, darjeeling, miho |
| message | メッセージ本文 | "ミカです。subtask_084a 完了しました。" |
| type | メッセージタイプ | report_received, task_assigned 等 |
| from | 送信者エージェント名 | mika, darjeeling 等 |

### 2. 隊長名テーブル

隊員が報告する場合、**必ずエージェント固有名**を宛先に使う。`captain` というロール名は不可。

| 隊 | 隊員 | 隊長名（inbox_write 宛先） |
|---|---|---|
| darjeeling | pekoe, hana, rosehip, marie, andou, oshida | **darjeeling** |
| katyusha | nonna, klara, mako, erwin, caesar, saori | **katyusha** |
| kay | arisa, naomi, yukari, anchovy, carpaccio, pepperoni | **kay** |
| maho | erika, mika, aki, mikko, kinuyo, fukuda | **maho** |

参謀長への通知: 宛先は **miho**（`chief_of_staff` ではない）

### 3. type 一覧

| type | 用途 |
|------|------|
| task_assigned | 隊長→隊員: タスク配信 |
| report_received | 隊員→隊長: 報告完了通知 |
| clear_command | 隊長→隊員: /clear + 新タスク開始指示 |
| model_switch | 隊長→隊員: モデル切替（/model opus 等） |
| cmd_done | 隊長→参謀長: 施策完了 |
| cmd_failed | 隊長→参謀長: 施策失敗 |
| qc_request | 隊長→副隊長: QC依頼 |
| qc_result | 副隊長→隊長: QC結果 |
| report_rejected | 隊長→隊員: 報告差し戻し |

### 4. 送信例

**隊員→隊長（報告完了）:**
```bash
bash scripts/inbox_write.sh maho "ミカです。subtask_084a 完了しました。報告書を確認してください。" report_received mika
```

**隊長→参謀長（施策完了）:**
```bash
bash scripts/inbox_write.sh miho "cmd_XXX 全タスク完了。{施策タイトル}、受入基準 N/N 達成。" cmd_done captain_maho
```

**隊長→隊員（タスク配信）:**
```bash
bash scripts/inbox_write.sh mika "タスクYAMLを読んで作業を開始してください。" task_assigned maho
```

## Notes

- inbox_write は永続化を保証する。配信確認やリトライは不要。
- inbox_watcher.sh が配信を処理する。エージェントが直接 tmux send-keys を呼ぶことは禁止。
- 宛先にロール名（captain, chief_of_staff）を使うとメッセージが配信されない。必ず固有名を使うこと。
