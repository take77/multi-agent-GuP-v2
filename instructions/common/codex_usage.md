# Codex Usage Guide（T4: 2026-04-19 制定）

## 原則: Codex は副隊長の道具

Codex QC は **副隊長が必要と判断した時に使う道具**。自動必須ではない。
副隊長が Codex 出力を参考にしつつ、**最終 verdict は副隊長が確定**する。

## dual_mode 廃止

旧制度の「Codex verdict と人間レビューの dual mode」「L4+ 必須実行」は廃止。
副隊長は以下を単独判断で使い分ける:

- **Codex を使う**: production wiring 変更、複雑な async/concurrency、大規模 refactor
- **Codex を使わない**: 軽微な hygiene fix、明らかな単発 bug fix、doc-only 変更

## severity calibration 権限

Codex が Major / Critical を付けても、副隊長は以下を根拠に Minor / Info に
再分類できる:

- 環境依存（flutter analyze 未実行環境での過大評価など）
- 実体は hygiene（動作影響なし、将来リスクのみ）
- Codex の誤認（docs/test-only 変更を production change と誤解）
- 既知の制約（backlog 登録済みで対応スコープ外）

**再分類時は verdict に理由を 1 行記載**（codex_reviews.jsonl に残す、T7 参照）。

## Codex 実行タイミング

### 推奨

- production entry point（main.dart / index.ts 等）への wiring 変更
- multi-file state 管理変更（provider/store 等）
- DB schema / API contract 変更
- security / auth 周辺

### スキップ可

- doc-only、test-only 変更
- 明確な typo fix、hygiene（rename、import 整理）
- 副隊長が手動レビューで十分と判断したもの

## フォールバック

Codex rate limit / error 時は Claude-only QC に自動フォールバック。
`queue/hq/codex_status.yaml` で可用性管理。軍の稼働は止めない。

## verdict 記録（T7 連動）

Codex 実行結果は `queue/hq/codex_reviews.jsonl` に全文記録（1 行 1 JSON）。
inbox には 3 行 pointer のみ流す（`instructions/common/message_format.md` 参照）:

```
Codex QC 完了 PR #86
- verdict: Major (副隊長 calibration で Minor に再分類)
- reason: flutter analyze 未実行環境の過大評価、実体は hygiene
- pointer: codex_reviews.jsonl:15
```

## 根拠

2026-04-19 までの運用で Codex を「独立監査人」扱いしたことにより、
副隊長 verdict と衝突 → 再調整往復で redo5 連鎖（PR #90）が発生。
Codex は道具、判断は人間（副隊長）という役割明確化で redo 連鎖を断つ。

旧 memory `feedback_codex_l4_review_not_substitutable.md` は
`feedback_codex_as_tool.md` にリネーム + 書き換え予定（T9 連動）。
