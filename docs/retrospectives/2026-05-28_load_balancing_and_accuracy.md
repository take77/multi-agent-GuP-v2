# 反省会ドキュメント — 2026-05-28 タスク配分偏り + 実装精度

作成: anzu（大隊長）／司令官指示による改善施策

---

## 1. 課題

### タスク配分の偏り
- 施策S〜Xで 20人中8人が完全休眠、上位5名にタスク集中
- naomi は inbox 33KB でコンテキスト飽和スタック
- 根本原因: 隊長に「誰が暇で誰がいっぱいか」を判断する手段がない

### 実装精度の不足
- calsail 実装で大量の往復・redo が発生
- 推論 effort が high 止まりで深い思考が不足
- タスク分解の品質（切り方・振り方）に PM 的なプラクティスが欠如

---

## 2. 実装した施策

### Layer 0: 推論深度
| # | 施策 | 変更先 |
|---|------|--------|
| 0 | effort: high → max | config/settings.yaml, lib/cli_adapter.sh |

### Layer 1: Hook（自動強制 — instructions に書かない）
| # | 施策 | 実装 |
|---|------|------|
| 1 | Definition of Ready（DoR）バリデーション | scripts/validate_task_ready.sh + inbox_write.sh 統合 |
| 2 | T-shirt Sizing チェック | DoR の一部（size フィールド） |
| 3 | inbox 過負荷ガード | inbox_write.sh（15KB 閾値 WARNING） |
| 4 | Compaction 入力遮断 | scripts/compaction_lock.sh + PreCompact/PostCompact hooks |

### Layer 2: Skill（オンデマンド呼び出し）
| # | 施策 | 実装 |
|---|------|------|
| 5 | Spike Task 作成 | .claude/skills/task-spike/SKILL.md（新規） |
| 6 | Pull-based Assignment | .claude/skills/task-dispatch/SKILL.md（拡張） |

### Layer 3: Instructions（判断基準のみ簡潔に）
| # | 施策 | 実装 |
|---|------|------|
| 7 | Vertical Slicing（縦切り必須） | instructions/common/task_decomposition.md |
| 8 | Interface-First（契約先行） | 同上 |
| 9 | L4 タスク強制分解 | 同上 |
| 10 | 事前アプローチ宣言（L3+） | 同上 |
| 11 | コンテキスト予算見積もり | 同上 |

### instructions 膨張の抑制

| 対象 | 追加量 |
|------|--------|
| captain.md | +1行（include 参照） |
| member.md | +1行（include 参照） |
| chief_of_staff.md | +1行（include 参照） |
| common/task_decomposition.md | 新規 ~30行 |

実行ロジックは hook 4件 + skill 2件 + script 2件に外出し。

---

## 3. 設計思想

「instructions には判断基準だけ書き、実行手順は外に出す」

- Hook: エージェントが覚える必要なし。システムが自動強制
- Skill: 必要な時にだけ呼ぶ。instructions は1行の参照
- Common section: 複数ロールで共有する原則を1箇所に集約

---

## 4. 運用確認後の判断

本 PR はマージ前に実運用で効果を確認する。確認ポイント:
- タスク配分の偏りが改善されるか
- redo/往復の頻度が減るか
- effort=max による token コスト増が許容範囲か
