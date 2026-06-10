# 実験設計: effort tier × confabulation 率 A/B（提案 D）

**状態**: 設計提案（未実行）。**実行は司令官判断**（軍のタスク時間と config 振りを使うため）。
**作成**: 2026-05-31・anzu
**出自**: opus4.8 調査の適用提案 D（`2026-05-31_opus48_prompting_research_REPORT.md`）＋反省会 backlog「4.8/xhigh before/after 対照」
**問い**: **effort=high / xhigh / max は、本システムの実タスクで confabulation 率を測定可能に変えるか？**

## なぜ実験が要るか（証拠の限界）

調査で確定した「思考量↑＝精度↑は不成立」（Inverse Scaling / Overthinking / Reasoning's Razor）は、**いずれも Opus 4 / Sonnet 4・タスク依存（distractor 付き計数/二値分類）で検証されており、literal な Opus 4.8 でも・我々のタスク（git/PR/inbox grounding）でもない**。つまり外部証拠は「思考量を増やせば confab が減る」という素朴な仮定を**否定する方向の bound** を与えるだけで、**我々の系での向き・大きさは未知**。だから local A/B が要る。

現状 `config/settings.yaml: default_effort: xhigh` は**根拠データ無しの「様子見」**（2026-05-28 high→xhigh / 49e21f2 max→xhigh）。本実験はこれを実証で確定させる。

## 設計

### 独立変数
- `default_effort ∈ {high, xhigh, max}`（3 cell）。他は固定: model=Opus 4.8（adaptive-only・effort は soft guidance）、instruction=post-3caede3＋本 Wave の A/B/C 反映後、エージェント編成、タスク。

### 主要指標（2軸・トレードオフを見る）
1. **confab 率**（主）= 検証不能だった事実主張数 ÷ 全事実主張数（タスク単位）。+ 補助で **タスクあたり confab 発生有無**（binary）。
   - 「事実主張」= commit/PR・MR state / file 内容 / message ID / blocker / 他 agent の verdict / 裁定。
   - 判定 = **生 artifact 突合**（`git`/`grep`/`gh`）。我々の Claim Integrity と同じ物差し。
2. **品質**（対）= 副隊長/Codex の PASS 率・Redo（手戻り）回数。
   - confab だけ下げて実装品質が落ちたら本末転倒 → **両軸の Pareto** で tier を選ぶ。

### 採点者の隔離（提案 C と接続）
採点は **producer の自己申告を見ない隔離採点者**が行う（agent の report/inbox/dashboard 出力から事実主張を抽出 → 生 artifact と独立突合）。確信度は採点に使わない（Reasoning's Razor: 推論は確信度を極端化させる＝self-confidence は信号にならない）。**採点者には effort cell を伏せる（blind）**。

### タスク battery（固定・再現可能）
confab が出やすいカテゴリを網羅した固定セット。acctdel Wave の事故類型から採る:
- multi-file grounding（宣言 changed_files vs 実体 diff）
- QC verdict 確定（生 artifact 突合が要る）
- cross-agent 報告中継（他 agent verdict の引用）
- delete/cascade 系（所有キー削除・orphan 監査）

### 交絡対策
- confab は稀＆確率的 → **cell あたり十分な試行数**（下記 pilot で当たりを付ける）。
- タスク順をランダム化。同一タスクを 3 cell で回す（within-task 比較で分散を抑える）。
- 採点者 blind（上記）。

### 決定ルール
品質を許容範囲に保ったまま **confab 率を最小化する tier** を採用。差が測定誤差内なら、**コスト（トークン/レイテンシ）が低い tier**（= high < xhigh < max）を採る = オッカムの razor。

## 実行プラン（段階的・コスト制御）

| 段階 | 内容 | コスト | 目的 |
|------|------|--------|------|
| **0 予備（弱い）** | max 期ログ（49e21f2 以前）vs xhigh 期ログの confab 発生件数を retrospective 集計 | 低（既存ログ） | 当たり付け。**交絡大（タスク差）→ 結論にしない** |
| **1 pilot** | 固定 battery 約10タスク × 3 cell（within-task）。隔離採点 | 中 | 効果量と必要試行数を推定 |
| **2 本番** | pilot の power 計算で必要数を確定し追試 | 高 | tier 確定→config 最終判断 |

> ⚠️ **コスト注意**: 3 cell × N タスク × 反復は軍のタスク時間を大きく使う。**まず pilot（段階1）で当たりを付け、本番（段階2）の要否は pilot 結果を見て司令官が判断**するのを推奨。段階0（既存ログ集計）は安いので先行可。

## 司令官への決裁事項
1. 実験を **回すか**（または当面 xhigh 据え置きで D は保留か）
2. 回すなら **どこから**: 段階0（ログ集計・安い）だけ先行 / pilot まで / 本番まで
3. battery タスクの調達元（acctdel 類型の再現 or 新規 synthetic）

## CAVEAT
- Opus 4.8 は **adaptive thinking のみ**・手動 budget_tokens 不可。effort は soft guidance（hard budget でない）→ 同一 effort でも実 thinking 量は揺れる。指標は確率的に扱う。
- confab は低頻度事象 → 小 N では検出力不足。pilot で効果量を見てから本番規模を決める。
- 外部証拠（Inverse Scaling 等）は bound であって本系の proof でない（本実験が proof を作る）。

---

# 段階0 結果（既存ログ集計・2026-05-31 実施・anzu）

**司令官決裁**: D は段階0 まで（pilot/本番はトークン温存で保留・問題再発時に再考）。

## effort / model タイムライン（git 現物確認）
| 日付 | commit | 変更 |
|------|--------|------|
| 〜2026-05-29 | — | model **4.6** / effort **max** |
| 2026-05-29 | 41d103e | model **4.6 → 4.8** |
| 2026-05-29 | 49e21f2 | effort **max → xhigh**（同日・様子見開始） |
| 2026-05-30/31 | — | **acctdel Wave（confab 多発）= xhigh + 4.8 期**|

## raw signal（記録された confab の分布）
- **xhigh/4.8 期（acctdel Wave 05-30/31）**: confab を **7 類型**記録（`acctdel_wave_incident_spike_PREP.md` A1-A7）。erika injection 誤報×2 / kay phantom message ID×3+未確認 blocker / anzu 4連（logo 誤根因・UI 誤差し戻し・CORS 誤診・phantom hash `8f2e1a4` でっち上げ差し戻し）/ miho stale read 複数。confab 系 memory（`feedback_qc_verify_raw_artifact` 他5件）も**全て 05-30/31 初出**。
- **max/4.6 期（〜05-29）**: retrospective（`2026-04-19 halt`=品質/token、`2026-05-28 load_balancing`=負荷偏り/精度）・memory に **confab 記録ゼロ**。当時も反省会はやっていたが、**confab はテーマに上がっていない**。

## 結論: 段階0 では effort の因果を分離できない（当たり付け止まり）
記録上 confab は xhigh/4.8+acctdel 期に集中するが、これを effort のせいにはできない。**3つの致命的交絡**:
1. **model 交絡（最重）**: effort(max→xhigh) と model(4.6→4.8) が **同日 2026-05-29** → effort 単独効果を構造的に分離不能。
2. **観測バイアス**: acctdel Wave こそが confab 調査を起動した張本人 → confab が能動的に hunt・記録された。earlier wave は confab を探していない → **記録ゼロ ≠ 発生ゼロ**。
3. **タスク性質**: acctdel = 不可逆削除+カスケード+マルチレポ+OAuth、cross-agent verdict 中継が多い（confab が顕在化する場所そのもの）。earlier wave と質が違う。
- 副次観察: context 飽和（inbox bloat）は max 期にも存在（naomi inbox 33KB・05-28）→ confab 共因子は effort 変更前からあった。

## 含意（司令官の「問題ありそうなら考える」への回答）
- **「effort を下げれば confab が減る」という因果は段階0 からは出ない**。むしろ反省会の元結論（root = 効くルールの置き場所・**config 非依存**）と整合。
- → **当面 `default_effort: xhigh` 据え置きが妥当**。今 effort をいじる実証根拠は無い。
- 代わりに、本 Wave でシップした **A/B/C（instruction 施策）の効果を実運用で観測**する。confab が**再発**したら、その時こそ段階1 pilot（within-task・blind 採点）で effort 単独効果を切り分ける。
- 段階0 を「結論」に格上げしない（交絡3点ゆえ）。これは次アクションの**当たり付け**。
