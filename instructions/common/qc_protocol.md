# QC Protocol（T3: 2026-04-19 制定）

## 原則: 副隊長 1 層 QC で最終 verdict 確定

QC の実質判断は **副隊長 1 層**に集約する。
隊長・miho・大隊長は「中継 + 受理」であり、**再レビューしない**。

## verdict フロー

```
member 実装完了
  → report.yaml 書き込み
  → 隊長 L4+ 判定
  → 副隊長 QC
    ├─ PASS → 隊長が受理 → integration merge → miho 中継 → 大隊長中継
    └─ FAIL → 隊長が Redo Protocol 発動（差し戻し）
```

## 各 role の責務（2026-04-19 改訂）

| Role | QC での責務 |
|------|------------|
| **member** | report.yaml に summary + acceptance 照合結果を明記 |
| **vice_captain（副隊長）** | 実質 verdict 確定。Codex は道具として使用可（T4 参照）。severity calibration 権限あり |
| **captain（隊長）** | 副隊長 verdict を受理・統合 merge 実行。**再レビューしない** |
| **chief_of_staff（miho）** | 裁可 = **中継のみ**。再レビューしない。集約報告のみ担当 |
| **battalion_commander（anzu）** | 司令官への報告中継。再レビューしない |

## 再レビュー禁止ルール

副隊長 verdict に対して以下は禁止:

- ❌ 隊長が副隊長の LGTM を覆す（Major を後付けで指摘）
- ❌ miho が副隊長の verdict を再評価（中継役に徹する）
- ❌ anzu が副隊長・miho 経由の verdict を覆す（司令官の命令でない限り）
- ❌ 他隊の副隊長が横から review する（担当隊副隊長の専権）

**例外: 司令官からの明示的な再レビュー指示**のみ、副隊長 verdict の取り直しが可能。

## 副隊長 verdict 権限

副隊長は以下を単独で決定できる:

- LGTM / Minor / Major / Critical の severity 判定
- Codex 出力の severity calibration（道具として使用、T4 参照）
- Redo 要否判断（Redo が必要なら隊長に差し戻し指示）

**副隊長 verdict = 最終 verdict**。上位 role は中継するのみ。

## component commit チェック（T3 補強）

副隊長 QC 時は以下を必須とする:

1. PR の全 component commit を列挙（squash/merge 元の feature branch commit を遡る）
2. 各 commit の diff stat を併記
3. 宣言 changed_files と実体 git diff が一致するか tick
4. production entry point（main.dart 等）への wiring grep 照合
5. merge 後の乖離チェック（post-merge で別の変更が入っていないか）

詳細は memory の `feedback_qc_component_commit_mandatory.md` 参照。
本プロトコルでは「副隊長が単独で」これを実施し、verdict を確定する。

## 根拠

2026-04-19 までの運用で 4 層（副隊長 → 隊長 → miho → 大隊長）の冗長 QC が
通信 25% を占めつつ、実質的な再検証にはなっていないことが判明。1 層集約で
-60% の通信削減と意思決定速度 3 倍を目標とする。
