# 調査レポート: Opus 4.8 / Claude 4.x confabulation 抑制 prompting ベストプラクティス

**状態**: 調査完了（cited・反証込み）
**実施**: 2026-05-31・anzu（deep-research harness: 6 angles / 26 sources fetched / 123 claims 抽出 → 25 検証 → **22 confirmed / 3 killed** / 9 synthesis 後）
**起点**: `2026-05-31_opus48_prompting_research_KICKOFF.md`（反省会の残タスク・別スコープ）
**位置づけ**: 反省会の打ち手①（commit 3caede3 = verify-then-write を CLAUDE.md/hook に昇格）の **外部知見による裏取り＋次の一手**。

---

## エグゼクティブ・サマリ

外部証拠（Anthropic 公式 docs 優先＋査読論文＋反証）は、**我々が既に打った verify-then-write をほぼ逐語で正当化**した。その上で、**まだ我々に無い 4 つの具体的追加策**を指し示している:

1. **公式の agentic-coding スニペット `<investigate_before_answering>` をほぼ逐語採用**（散文でなく明確な命令文として）
2. **cite-before-claim を必須化＋根拠なき主張の自動撤回**（「retract the claim」の運用化）
3. **QC/検証者の context を生成者の結論から隔離**（MARCH/CoVe の confirmation-bias 遮断 — これが構造的に一番大きい新知見）
4. **effort=xhigh/max を再検討**（「思考量↑＝confab↓」は成立しない。むしろ確信的 confab を増幅しうる）

加えて、我々の **生 artifact 突合（receipt 方式）は弱いベースラインでなく正攻法**であることが裏付けられた。

---

## 確定知見（confirmed claims）

### Q1. Anthropic 公式の anti-hallucination ガイダンス【確度: 高 / primary 複数】
公式 docs が一貫して推奨する小さく強力なテクニック群（我々の verify-then-write と直接一致）:
- **「分からない」を明示的に許可** → 公式原文「This simple technique can **drastically reduce false information**」
- **長文（>20k tokens）は逐語引用を先に抽出 → その引用からのみ回答**
- **主張ごとに支持引用を提示 → 引用が見つからなければ主張を撤回**（"retract the claim"）
- **生成後の self-check を付加**（"verify your answer against [criteria]" — coding/math で特に有効）

出典:
- https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations （primary）
- https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices （primary）
- https://github.com/anthropics/courses/.../08_Avoiding_Hallucinations.ipynb （primary・チュートリアル）

### Q1+. 公式 agentic-coding スニペット `<investigate_before_answering>`【確度: 高 / primary】
公式 prompt-engineering ガイドが **コードエージェント向けの literal サンプル命令文**を提供。我々の Claim Integrity に最も近い公式アナログ。逐語:
> `<investigate_before_answering>` Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. ... Never make any claims about code before investigating unless you are certain of the correct answer — give grounded and hallucination-free answers. `</investigate_before_answering>`

スコープは「コード/コードベース」だが、**最も移植性の高い公式パターン**。
出典: claude-prompting-best-practices（primary・Opus 4.8 を current model として参照）

### Q5. Opus 4.8 の thinking 設定デルタ（4.6→4.8 移行の核心）【確度: 高 / primary ×2】
- **adaptive thinking が唯一サポートされるモード**。`thinking:{type:"adaptive"}` を明示しないと OFF
- **手動 `budget_tokens` は 400 エラーで拒否**（4.6 以前と非互換）
- **effort は SOFT guidance**（hard token budget ではない）。tier: `high`(default) / `xhigh`(=4.8/4.7 限定) / `max`
- 公式原文「The effort level acts as **soft guidance** for Claude's thinking allocation」「Effort is a **behavioral signal, not a strict token budget**」

出典:
- https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking （primary）
- https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8 （primary）

### Q2. 「思考量↑＝精度↑」は不成立。confab を悪化させうる【確度: 高 / Anthropic 自身の研究含む】
- **Anthropic 自身の Inverse Scaling**: 推論長を伸ばすと精度が**劣化**しうる（test-time compute と accuracy の逆相関）。**Claude は推論が長いほど無関係情報に気を取られやすくなる**（Opus 4 で自明な計数タスクの精度が思考延長で低下した実例）
- **Overthinking 曲線**（arXiv 2506.04210「Does Thinking More Always Help?」): 改善→過剰思考で低下の非単調パターン
- ⚠️ **CAVEAT**: 検証は Opus 4 / Sonnet 4 で、**literal な 4.8 ではない**。タスク依存（distractor 付き計数/推論）。**bound（上限示唆）であって proof ではない** → 我々のタスクでの A/B が必要

出典: https://alignment.anthropic.com/2025/inverse-scaling/ （primary）, arXiv 2507.14417, arXiv 2506.04210

### Q2+. 推論は確信度を極端化させる【確度: 高 / 機構として転用可】
- **Reasoning's Razor**（arXiv 2510.21049): 推論は全体精度を上げるが、**厳格な動作点（low-FPR）で precision を悪化**。**推論は予測を極端な確信に偏らせ、誤りがほぼ確実な口調で出る → 正解と区別がつかなくなる**
- これは **context 劣化したエージェントが phantom ID を確信的に書く理由**を説明する機構。**self-confidence は信頼できないシグナル**という教訓
- ⚠️ **CAVEAT**: 対象は二値分類器（safety/hallucination 検出）で生成的 confab ではない。転用可なのは「確信度極端化の機構」であって「effort を下げろ」という literal な処方ではない

出典: https://arxiv.org/pdf/2510.21049 （primary）

### Q3/Q6. 検証者の構造的隔離が高レバレッジ【確度: 高 / primary ×4】
- **同一 context の self-check は構造的に弱い**（生成者と検証者が同じ失敗モードを共有するため）
- **Chain-of-Verification (CoVe)**: draft → 検証質問を計画 → **独立して回答（バイアス遮断）** → 検証済み最終回答。Wikidata/MultiSpanQA/長文で hallucination を実証的に削減
- **MARCH**（マルチエージェント版): Checker が**生成者の出力を見ずに（blinded）**、命題を retrieved evidence と隔離検証 → **self-confirmation bias の連鎖を断つ**。原文「verifiers ... inadvertently reproduce the errors of the original generation」
- **Cross-Context Verification**（arXiv 2603.21454): 「downstream agent が upstream の結論を見えると、sycophantic confirmation がフィルタ効果を消す」
- → **我々の「QC は agent verdict を信用せず生 artifact を突合」を最強に裏付ける。＋新処方: 検証者の context に生成者の結論を入れるな**

出典: arXiv 2309.11495 (CoVe), aclanthology 2024.findings-acl.212, arXiv 2603.24579 (MARCH), arXiv 2603.21454

### Q3/Q4. tool-agent の幻覚は「構造化実行証拠（receipt）」で検証【確度: 中 / 単著 preprint】
- 論文が**我々の観測した失敗モードをそのまま命名**: Fabricated Tool Call / Source Fabrication / **Inference-as-Fact** / **Count Mismatch**（= phantom hash / 存在しない message ID / 未確認なのに "confirmed"）
- 処方: **応答テキストではなく構造化実行証拠（receipt/生 artifact）に対して検証**。捏造 tool call・件数不一致・false-absence に対し決定論的
- ⚠️ **CAVEAT**: 単著・**非査読** preprint・自作 synthetic ベンチ。**定量検出率（94.2%/87.6%/91.3%）は反証 0-3 で棄却済 → 引用禁止**。taxonomy と「テキストでなく構造化 artifact を検証せよ」という設計原則は健全（我々の incident log と一致）

出典: arXiv 2603.10060（数値は使わない）

### Q3. cite-before-claim は grounding を改善【確度: 中 / ドメイン限定】
- 引用強制パラダイムが grounding を **+13.83%** 改善（Claim Grounding Rate）
- ⚠️ **CAVEAT**: e-commerce 会話エージェント限定・LLM-as-judge の自動評価。**+13.83% という数値は我々のドメイン（git/code）に転用不可**。方向（引用強制で grounding↑）は公式の「cite/retract」と収束し、cite-before-claim 採用の補強にはなる

出典: arXiv 2503.04830 (SIGIR 2025)

---

## 棄却された主張（反証 → レポートから除外）

| 主張 | 投票 | 出典 |
|------|------|------|
| 「推論を増やすと distractor に回帰して誤結論を出す」という推論軌跡の主張 | 1-2 | inverse-scaling |
| 「追加思考は出力分散を増やし、改善の錯覚を生むが精度を損なう」 | 1-2 | arXiv 2506.04210 |
| receipt 検出ベンチマークの数値（94.2%/87.6%/91.3%） | 0-3 | arXiv 2603.10060 |

---

## GuP-v2 への適用提案（採否＝司令官判断）

我々の commit 3caede3（verify-then-write / 生artifact突合 / truncation full再取得 / context hygiene）は**外部証拠で正当化された**。以下は **まだ我々に無い／弱い追加策**。インパクト順:

| # | 提案 | 根拠 | 新規度 | コスト |
|---|------|------|--------|--------|
| **A** | **`<investigate_before_answering>` 相当を CLAUDE.md に逐語追加**（"code" を「commit hash / message ID / PR・MR state / 他 agent の verdict」に一般化） | 公式スニペット（Q1+） | 既存 Claim Integrity の散文を**公式の明確な命令文に格上げ** | 低（instruction 数行） |
| **B** | **cite-before-claim 必須化＋根拠なき主張の自動撤回**（全事実主張に裏取り出力を添付・無ければ削除） | 公式 "retract the claim"（Q1）＋cite論文（Q3） | verify-then-write はあるが「撤回」明文化は未 | 低 |
| **C** | **QC/検証者の context を生成者の結論から隔離**（QC agent には生 artifact＋タスクのみ渡し、生成者の verdict/要約は渡さない） | CoVe / MARCH / Cross-Context Verification（Q3/Q6） | **構造的に最大の新知見**。現状は「verdict を信用するな」止まりで隔離は未実装 | 中（orchestration 設計変更） |
| **D** | **effort=xhigh/max の再検討（A/B 取得）**「思考量↑＝confab↓」は不成立。確信的 confab を増幅しうる。thinking budget は安全レバーでなく要実証のチューニング変数 | Inverse Scaling / Overthinking / Reasoning's Razor（Q2/Q2+） | 現状 xhigh は「様子見で開始」（commit 49e21f2）→ 根拠データ無し | 中（対照実験） |
| **E** | **「未検証/分からない」を許可された終端状態として明示**（context 劣化 agent が穴を confab で埋めるのを止める） | 公式 allow-IDK（Q1） | 部分的にあるが明文の terminal-state 化は未 | 低 |
| **F** | **生 artifact（receipt 方式）突合を継続・強化**（テキスト self-consistency は弱いベースライン） | tool-receipt 設計原則（Q3/Q4）＋自軍 incident log | 既存方針の裏付け（数値は使わない） | — |

### 推奨アクション
- **即採用候補（低コスト・公式根拠）**: A / B / E → instruction 数行で、肥大も最小。commit 3caede3 の自然な強化
- **設計判断が要る**: C（検証者隔離）— harness で「生成者の結論を見ない QC agent」を spawn できるか＋orchestration コストの検討が必要
- **データ駆動で決める**: D（effort）— 現状 xhigh は根拠データ無しの「様子見」。我々のタスクでの confab 率 A/B を取ってから config 最終判断（反省会の backlog「4.8/xhigh before/after 対照」と接続）

---

## オープン・クエスチョン（未解決・要追加調査）

1. **effort=xhigh vs high vs max は本システムの実タスク（git/PR/inbox grounding）で confab 率を測定可能に変えるか？** 逆スケーリング証拠は旧 Claude・タスク依存。**Opus 4.8 では local A/B のみが答えを出す**
2. thinking-config デルタ以外の公式 4.6→4.8 移行 prompt 指針は？ 確定したのは adaptive-thinking と effort tier のみ
3. Claude Code harness 内で**真の検証者 context 隔離**（MARCH 式: 生 artifact＋タスクのみ受領、生成者 verdict は確実に非受領）を実装できるか＋orchestration コスト
4. **Anthropic ネイティブ**のマルチエージェント claim-integrity 指針はあるか？ 最強の隔離証拠（CoVe/MARCH/Cross-Context）は Meta/Qwen/独立ラボ由来で Anthropic 純正は未確認

---

## 全体的 CAVEAT（レポートの信頼境界）

- **公式の anti-hallucination prompting**（引用先出し / cite-and-retract / allow-IDK / self-check / agentic スニペット）は **model 非依存で現行（Opus 4.8 を参照）→ 耐久性高い**
- **Opus 4.8 thinking-config 事実**（adaptive 限定 / 手動 budget 400 / effort tier）は **version 固有 → 将来モデルで変わりうる。依存前に再確認**
- **inverse-scaling / overthinking**（思考量）は **タスク条件付き・Opus 4/Sonnet 4 で検証・literal 4.8 ではない → bound であって proof でない**
- **Reasoning's Razor** は二値分類器の話 → 転用可なのは確信度極端化の機構のみ
- **tool-receipt / citation 論文**は非査読/ドメイン限定 → アーキ原則は健全だが**数値は転用不可**（receipt 検出率は反証棄却済）
- **self-check の限界**: 公式は self-check を推奨するが、同一 context の self-check は生成者と検証者が失敗モードを共有すると弱い → **cross-agent / 隔離 context 検証**の重要性（提案 C）に接続
