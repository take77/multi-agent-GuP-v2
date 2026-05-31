# 調査キックオフ: Opus 4.8 prompting ベストプラクティス（confabulation 抑制）

**状態**: 調査前キックオフ。/clear 後の fresh context で deep-research を回す**起点**。
**作成**: 2026-05-31（反省会クローズ直後・anzu）
**スコープ**: 別スコープ・独立タスク。GuP-v2 の confabulation/誤読対策の**外部知見収集**。
**前提**: 反省会の instruction 昇格対策(commit 3caede3)は実施済。本調査は「次の一手」を外から取りに行く位置づけ。

## 背景（反省会の結論・cf. memory [[project_gupv2_incident_retrospective]]）
- acctdel Wave(2026-05-30/31) で confabulation 多発。root = verify→write 順序崩れ、2系統:
  - **Chain A**: truncated な tool 出力(cap/inbox肥大)を full 再取得せず誤読
  - **Chain B**: context 劣化で「確認した」と錯覚し存在しない情報を生成
- 上流 shogun は 4.8 未使用(4.6+max)→ 答えなし。**GuP-v2 が 4.8 人柱**。
- 「4.8 が confab を増やしたか」は対照群なしで**未確証**。指示設計で改善できる公算が高い(司令官仮説)。

## 調査の問い（deep-research に渡す question 群）
1. Opus 4.8 / Claude 4.x で hallucination・confabulation を減らす **Anthropic 公式 prompting ガイド**は？（最新 docs・モデルカード・prompt engineering ページ）
2. **effort / extended thinking** の設定が出力精度・先走り(premature conclusion)に与える影響と推奨。max vs xhigh vs high の使い分け
3. 「主張の前に検証する(verify-then-write)」を促す **prompt パターンの外部事例**（agentic system での hallucination 抑制手法）
4. **長い/truncated な tool 出力**の扱いの推奨（context management・出力の信頼性検証）
5. **4.6 → 4.8 移行**で変わった prompting の勘所（モデル移行時に instruction を見直すポイント）
6. **マルチエージェント orchestration** での誤情報伝播を防ぐ設計（claim integrity の業界事例）

## 既知の事実（調査で再確認不要）
- GuP-v2 現状: Opus 4.8 中心 / effort xhigh / bloom_routing（config/settings.yaml）
- 反省会の打ち手: CLAUDE.md「Claim Integrity & Context Hygiene」+ SessionStart hook Step7（commit 3caede3 on feat/retrospective-improvements・ローカル）
- メタ教訓: 効く規律は instruction 層に置く [[feedback_rule_placement_instruction_over_memory]]

## 成果物
1. **cited 調査レポート**（公式 docs 優先・出典明記・反証込み）
2. **GuP-v2 への適用提案**: instruction/config 調整候補のリスト（採否は司令官判断）

## 実行手段
- `deep-research` skill（fan-out web search → 出典検証 → cited レポート）が第一候補
- または WebSearch/WebFetch の fan-out + adversarial verify

## 開始手順（/clear 後の anzu / 担当）
1. 本 doc を読む
2. memory [[project_gupv2_incident_retrospective]] で反省会の文脈を復元
3. 上記「調査の問い」で deep-research を起動 → レポート → 司令官に適用提案
