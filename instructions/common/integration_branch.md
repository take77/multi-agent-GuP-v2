# Integration Branch Protocol（T2: 2026-04-19 制定）

## 原則: main 直 merge 禁止、統合ブランチ経由必須

複数の feature branch を main に集合投入する場合、**integration ブランチを経由させる**。
main への直 merge は原則禁止。例外は単発 hotfix のみ。

## 4 段階フロー

```
feature branch（隊員）
  → vice_captain QC Pass
  → integration branch（migration ごとに 1 本、隊長 or miho が作成）
  → 全 feature merge 完了 + 司令官 E2E 承認
  → main への merge
```

| 段階 | 担当 | 成果物 |
|------|------|--------|
| 1. feature branch 作成 | 隊員 | `cmd_XXX/${agent_id}/${short_desc}` |
| 2. feature → integration merge | 隊長（副隊長 QC Pass 後） | squash or merge commit |
| 3. integration E2E 実行 | 司令官（または代行指定） | E2E 結果 |
| 4. integration → main merge | 隊長（司令官 approve 後のみ） | main への PR |

## 統合ブランチ作成手順

```bash
bash scripts/create_integration_branch.sh <migration_name> [base_branch]
# 例: bash scripts/create_integration_branch.sh online-only-migration
```

作成時に `coordination/integration/${migration_name}.yaml` にメタ情報が生成される。
`feature_branches` / `e2e_status` / `e2e_approved_by` / `merged_to_main_at` を適宜更新する。

## 禁止事項

- ❌ feature branch から main に直 merge（hotfix 以外）
- ❌ 副隊長 QC を通さずに integration へ merge
- ❌ 司令官 E2E approve 前に integration を main へ merge
- ❌ 手動で `git branch integration/xxx` を作る（meta ファイルが生成されない）

## 例外: 単発 hotfix

以下すべてを満たす場合のみ main 直 merge 可:

1. 修正が 1 PR に収まる（複数 feature の集合ではない）
2. 司令官 or miho が即時承認
3. PR 本文に「hotfix 例外」と明記

それ以外は integration 経由。

## 根拠

2026-04-19 の運用レビューで、online-only migration の main 集合マージ時に
「どこまで同時投入するか」「E2E は誰がいつやるか」が曖昧になり、PR #92 の
coverage gap 等が post-merge で発覚した。事前統合 → E2E → main 昇格の 4
段階を物理的に分離することで、main に入る前の検証を強制する。
