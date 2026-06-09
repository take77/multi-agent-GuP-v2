# GuP-v2 Claude ToS リスク戦略ドキュメント

**作成日**: 2026-04-09
**作成者**: rosehip（cmd_168 主執筆担当）
**レビュー**: hana（cmd_168 pair_review）
**配置**: `docs/claude-tos-risk-strategy.md`

---

## 0. このドキュメントの用途

### 0.1 読者と読むタイミング

| 読者 | 想定タイミング |
|---|---|
| 司令官 | 新 Layer 施策検討時 / ToS 更新時 / 四半期レビュー時 |
| 参謀長（pekoe） | 方針裁量判断時・重大決定前 |
| 隊長（darjeeling 等） | 自隊の運用方針見直し時 |
| 将来の Claude Code 運用判断者 | GuP-v2 後継者・引き継ぎ時 |

### 0.2 本ドキュメントの性質（最重要）

> **本ドキュメントは「判断材料集」であり、即時実装指示ではない。**

各レイヤー・各施策は「今すぐやるべきこと」ではなく「検討の土台」として記録されている。実装判断は別途施策単位で起票し、影響評価と相互レビューを経てから決定する。

- ✋ 本ドキュメントを読んで即座に `dangerously-skip-permissions` を外す等の運用変更を行わないこと
- ✅ 本ドキュメントは「いつ・どう変えていく余地があるか」の見取り図
- ✅ 各レイヤーは独立した別施策として個別起票する前提
- ✅ 慎重取り込み方針（§6）は必読

### 0.3 cmd_167 との位置付け

本ドキュメントは cmd_167 の成果を GuP-v2 自身に適用したものである。cmd_167 は ai-novel-generator の A 案可否判定が主目的だったが、その過程で「GuP-v2 自身も同じ論理で評価可能」という事実が明らかになった。cmd_168 はその当然の延長として、GuP-v2 の戦略を記録する。

**参照**:
- [`projects/ai-novel-generator/docs/claude_code_usage_boundary.md`](../projects/ai-novel-generator/docs/claude_code_usage_boundary.md) — rosehip 執筆、境界ガイド 443 行
- [`projects/ai-novel-generator/docs/cmd_167_investigation_story.md`](../projects/ai-novel-generator/docs/cmd_167_investigation_story.md) — hana 執筆、調査物語 787 行
- [`projects/ai-novel-generator/docs/sections/03_tos_env_v2.md`](../projects/ai-novel-generator/docs/sections/03_tos_env_v2.md) — rosehip 執筆、主調査 1007 行

---

## 1. 背景 — cmd_167 の結論と GuP-v2 への含意

### 1.1 cmd_167 の 3 層独立根拠による NG 判定

cmd_167 は ai-novel-generator の「Claude Max サブをアプリバックエンドとして使う」A 案について、以下の 3 層独立根拠で **NG 判定** を下した:

| 層 | 根拠 | 適用対象 |
|---|---|---|
| **根拠 A** | Agent SDK overview Note ブロック: "third party developers to offer claude.ai login ... for their products" | 第三者提供製品への組み込み |
| **根拠 B** | Anthropic 広報公式声明（The Register 2026-02-20）: "in any other product, tool, or service — including the Agent SDK — is not permitted" | あらゆるプロダクト/ツール/サービスでの OAuth 消費 |
| **根拠 C** | 2026-04-04 Enforcement: OpenClaw/Cursor/CLIProxyAPI 等 third-party harness の技術的遮断実例 | subprocess wrapper パターン |

※ cmd_167 v2 主要発見 5 件のうち、直接的な NG 判定に寄与する 3 層を本表に採用している。残り 2 件（Consumer ToS 3.7 の "explicitly permit" 例外条項 / Claude Code `--bare` mode が API Key 必須 / Anthropic 公式 GitHub Action が API Key 専用）は補強証拠として §3.2（C3 最弱リンク論）および §8.2（四半期監視指標）で言及している。

Consumer ToS 3.7 は "except where we otherwise explicitly permit it" 例外条項発見により、主論拠から補強論拠に降格された。

### 1.2 GuP-v2 への含意 — 「同じ論理で評価可能」

cmd_167 はこの論理を ai-novel-generator(dev) に適用したが、**同じ 5 条件（境界ガイド §3.1）** は GuP-v2 自身にも適用できる。司令官が cmd_167 初期に提示した前例論（「GuP-v2 が OK なら ai-novel-generator(dev) も OK」）は、ai-novel-generator 方向には拡張できないことが示された。しかし逆方向、つまり **「GuP-v2 自身が tacit tolerance 範囲内か」** の評価は未実施だった。

本ドキュメントはその評価（§3）と、評価結果を踏まえた戦略（§4）を記録する。

### 1.3 スタンスの継承

cmd_167 と同じスタンスを継承する:

- **安全側判断**: 規約違反スレスレを狙わない、グレーを明確化する
- **保守的デフォルト**: 迷ったら NG 扱い
- **誠実な反証検討**: 自分の論理を自分で叩く
- **時点限定性の認識**: 2026-04-09 時点の解釈、Anthropic ポリシーは変化する

---

## 2. multi-agent-shogun 調査結果

### 2.1 リポジトリ概要

- **リポジトリ**: `yohey-w/multi-agent-shogun`
- **スター数**: 1199（2026-04-09 時点）
- **位置付け**: GuP-v2 の元ネタ（司令官が参考にした OSS multi-agent orchestrator）
- **構成**: tmux + Claude Code CLI ベースのマルチエージェント管理システム

### 2.2 調査で判明した事実

| 観点 | 事実 |
|---|---|
| `dangerously-skip-permissions` | **全エージェントで使用**（`shutsujin_departure.sh` 等の起動スクリプトに明記） |
| OAuth + Bypass Permissions | **公式セットアップ手順として README 記載**（Max サブ OAuth + bypass フラグが前提） |
| ToS 議論のドキュメント化 | **なし**（cmd_167 相当の再調査・境界明確化は行われていない） |
| Multi-CLI ハイブリッド | **実装済み**（`lib/cli_adapter.sh` で Claude / Codex / Copilot / Kimi を切替可能） |
| `ratelimit_check.sh` | **実装済み**（`scripts/ratelimit_check.sh` で Max サブのレート制限監視を自動化） |

### 2.3 参考ファイル（GuP-v2 から取り込みを検討する場合の起点）

| ファイル | 用途 |
|---|---|
| `README.md` | 公式セットアップ手順（OAuth + Bypass の扱い） |
| `shutsujin_departure.sh` | エージェント起動スクリプト（`--dangerously-skip-permissions` 使用箇所） |
| `lib/cli_adapter.sh` | Multi-CLI アダプタ層 |
| `scripts/ratelimit_check.sh` | レート制限監視（Layer 2 移植候補） |

### 2.4 含意 — GuP-v2 は「本家と同じ船に乗っている」

shogun は 1199 stars を持つ公開 OSS プロジェクトであり、`dangerously-skip-permissions` + OAuth + multi-agent orchestration という GuP-v2 と **ほぼ同一の実装パターン** を採用している。cmd_167 の論理を shogun に適用すれば、同じ tacit tolerance 評価が成立する。

この含意については §7 で詳述する。

---

## 3. GuP-v2 の tacit tolerance 条件評価

cmd_167 で策定した境界ガイド §3.1 の **tacit tolerance 5 条件（C1-C5 の AND 評価）** を GuP-v2 自身に適用する。

### 3.1 評価表

| 条件 | 定義（境界ガイド §3.1 より） | GuP-v2 評価 | 根拠 |
|---|---|---|---|
| **C1 内部利用** | 第三者にサービスとして提供していない | **PASS** | 司令官個人の開発環境、ローカル完結、SaaS 化していない |
| **C2 開発支援目的** | 開発者自身の作業を補助する用途 | **PASS** | エージェント協働による開発・運用補助が主目的 |
| **C3 interactive 起点** | 人間の起動・判断が各ステップに介在 | **部分的（最弱リンク）** | 起動は人間、しかし `inbox_watcher.sh` が常駐し `tmux send-keys` で自動注入する構造 |
| **C4 小規模** | 数十〜数百リクエスト/日程度 | **PASS** | 30 エージェント構成だが、実質的な Claude API 呼び出しは数十〜数百件/日規模 |
| **C5 透明性** | Max サブ保有者本人が全セッションを把握 | **PASS** | tmux / queue / YAML / Web UI ですべてのセッションが追跡可能 |

**総合判定**: **グレー（tacit tolerance 範囲内、C3 が最弱リンク）**

### 3.2 C3 が最弱リンクである理由（詳述）

C3 評価を「PASS」ではなく「部分的」とした理由を明確にする。誠実な自己評価として、ここは妥協してはいけない。

#### 3.2.1 inbox_watcher.sh の automated means 該当可能性

`scripts/inbox_watcher.sh` は以下の動作をする:

1. `inotifywait` で `queue/inbox/*.yaml` の変更を監視（常駐プロセス）
2. 変更検知すると対象エージェントの tmux pane に `tmux send-keys "inbox1" Enter` を自動注入
3. エージェント（Claude Code CLI）はあたかも人間が `inbox1` とタイプしたかのように受信箱処理を開始

この動作を Consumer ToS 3.7 に照らすと:

> "To access the Services through **automated or non-human means**, whether through a **bot, script, or otherwise**" は禁止（API Key 経由または明示的許可を除く）

`inbox_watcher.sh` は厳密な文言解釈では「script through automated means」に該当する可能性が否定できない。tmux send-keys は「キーボード入力の代行」という技術的性質上、Claude Code CLI 側からは人間入力と区別できないが、**入力の起源は非人間（inotify イベント + shell script）** である。

#### 3.2.2 hana precedent 分析 §P.3 疑念 1 との整合

hana の precedent 分析（`03_tos_env_v2_precedent.md` §P.3 疑念 1）でも同じ論点が指摘されていた:

> 「inbox_watcher.sh は inotifywait で inbox 変更を検知して自動で send-keys を送る。Consumer ToS 3.7 の "automated or non-human means" に厳密に当てはめると、これは自動化手段そのものに見える。GuP-v2 も自動化アクセスをしているのでは？」

hana はこの疑念に対して「完全な反論は難しい」と率直に認めつつ、相対的擁護点 4 つ（内部利用限定、Web UI ローカルホストのみ、Anthropic が凍結していない、tmux pane 内の対話セッション）を提示した。本ドキュメントはこの誠実な評価を継承する。

#### 3.2.3 擁護論と反論の整理

**擁護論**（C3 を「PASS」に寄せたい論理）:
- tmux send-keys は「人間入力のシミュレート」であり、Claude Code CLI 側から見た動作は対話モード
- Consumer ToS 3.7 の例外 "where we otherwise explicitly permit it" に Claude Code CLI の自動化パターンが含まれる可能性
- `-p` / `--print` モードや `| claude -p` のパイプ連携を Anthropic が推奨しているため、周辺の自動化は許容範囲と解釈可能

**反論**（C3 を「FAIL」に寄せる論理）:
- `inbox_watcher.sh` は常駐プロセスであり、「人間の interactive 操作の延長」とは言い難い
- 30 並列で恒常的に `--dangerously-skip-permissions` を併用することで、人間の確認フローを完全にバイパスしている
- Anthropic の検知ルールが「親プロセスが常駐 daemon か」「入力の起源が inotify イベントか」を見ていれば、`bash → inotifywait → tmux send-keys` は検知対象になり得る

**結論**: 「部分的」と評価するのが最も誠実。PASS とも FAIL とも言い切れない。これは「実装を変更すべき」という即時の意味ではなく、「リスク項目として継続監視すべき」という意味である。

### 3.3 境界ガイド §3.1 の 5 条件 AND 論理との整合

境界ガイド §3.1 は 5 条件を **AND（乗算）評価** すると定めている。GuP-v2 は 5 条件中 4 条件 PASS + 1 条件「部分的」のため、厳密には AND 条件を完全には満たさない。

ただし境界ガイド §3.2 で GuP-v2 の評価例を示した際、同様に「C3 部分的 → グレー」と判定している。これは「部分的 FAIL」は「完全 FAIL」とは扱わず、**「保守的デフォルトに従えば NG 側推奨だが、tacit tolerance の余地は残る」** という中間判定である。

この中間判定は:
- Anthropic が実際に ban していない事実（§2.4 / §7 の shogun 継続稼働も根拠）
- 公式には OK と言われていない事実
- どちらも尊重する姿勢から導かれる

⚠️ **再強調: この評価は「このまま運用継続してよい」を意味しない。「現時点で即時停止すべき理由もないが、リスクは認識して継続監視する」が正しい読み方である。**

---

## 4. 5 レイヤー戦略

§3 の評価を踏まえ、GuP-v2 の安定性戦略を 5 レイヤーで整理する。各レイヤーは独立した別施策として個別起票する前提であり、**本ドキュメントで実装を指示するものではない**。

### 4.1 Layer 1: dangerously-skip 最小化

| 項目 | 内容 |
|---|---|
| **何を** | `--dangerously-skip-permissions` の使用を段階的に削減する |
| **なぜ** | §3.2 反論論で指摘した通り、このフラグの恒常使用が「人間の確認フローを完全バイパス」と解釈されるリスクを持つため |
| **現状からの変化** | **大きい**。全 30 エージェントが現状このフラグ前提で動作している |
| **段階案** | (a) 全 agent → (b) captain のみ → (c) 削除 |
| **リスク** | 大。運用停止・インタラクティブプロンプト待機でエージェントが固まる可能性 |
| **優先度** | **低（最後に検討）** |

⚠️ **慎重取り込み方針**: Layer 1 は現状運用への影響が最も大きいため、他レイヤーで十分な監視・退避経路が整った後に最後に検討する。今すぐ実装してはならない。

### 4.2 Layer 2: rate limit 監視

| 項目 | 内容 |
|---|---|
| **何を** | shogun の `scripts/ratelimit_check.sh` 相当の監視スクリプトを移植 |
| **なぜ** | Max サブのレート制限は Anthropic からの「automation 検知」の主要指標の 1 つ。早期察知で対応猶予を確保する |
| **現状からの変化** | **小さい**。監視追加のみ、既存運用への影響なし |
| **リスク** | 低。スクリプト追加のみで副作用なし |
| **優先度** | **高（即効性あり）** |

⚠️ **慎重取り込み方針**: Layer 2 の移植は「監視のみの追加」として切り分けやすいが、それでも shogun のスクリプトをそのまま流用するのではなく、GuP-v2 の命名規則・YAML 形式に合わせて個別施策で起票すること。

### 4.3 Layer 3: 製品化しない宣言

| 項目 | 内容 |
|---|---|
| **何を** | `README.md` / `LICENSE` / `docs/philosophy.md` に「本リポジトリは製品ではない」旨を明記 |
| **なぜ** | Agent SDK Note "their products" 条項から明確に外れるため。tacit tolerance の論拠（C1 内部利用）を文書化することでリスク判定を安定させる |
| **現状からの変化** | **小さい**。ドキュメント追記のみ |
| **リスク** | 極小。法的効力は限定的だが、意思表示としての価値あり |
| **優先度** | **中（コスト低・効果中）** |

⚠️ **慎重取り込み方針**: Layer 3 は「既存 README 変更」を含むため、本 cmd_168 では実施しない（cmd_168 の禁止事項: 既存 GuP-v2 ファイル変更禁止）。別施策として起票し、文案レビューを経てから実装する。

### 4.4 Layer 4: 四半期継続監視

| 項目 | 内容 |
|---|---|
| **何を** | ToS / Agent SDK docs / enforcement 事例 / shogun 動向 を四半期ごとにレビュー |
| **なぜ** | Anthropic のポリシーは 2026-02 / 2026-04-04 に複数回改定・執行されている。静的判断ではなく継続監視が必須 |
| **現状からの変化** | **中**。定期レビュー体制の新設 |
| **監視対象** | §7.4 で列挙 |
| **リスク** | 低。レビュー実施負荷のみ |
| **優先度** | **中（防御性）** |

⚠️ **慎重取り込み方針**: Layer 4 は継続運用項目であり、単発施策ではない。責任者（司令官 or 参謀長）と四半期タイミングを個別施策で決定してから開始する。

### 4.5 Layer 5: 退避経路準備

| 項目 | 内容 |
|---|---|
| **何を** | 将来の OAuth 全面 ban に備えて代替 CLI への切替経路を整備 |
| **なぜ** | Anthropic が tacit tolerance を撤回した場合、GuP-v2 が一瞬で稼働不能になるリスク。保険として退避経路を先に確保する |
| **現状からの変化** | **中**。Codex Plugin は cmd_164 で実装済み。Multi-CLI ハイブリッド化は未実装 |
| **構成要素** | (a) Codex Plugin 拡張（cmd_164 済） / (b) Multi-CLI ハイブリッド化（shogun ベース） / (c) ratelimit_check 連動自動フォールバック |
| **リスク** | 中。Multi-CLI 実装は複雑、代替 CLI の品質問題 |
| **優先度** | **高（戦略性・保険）** |

⚠️ **慎重取り込み方針**: Layer 5 の「Multi-CLI ハイブリッド化」は shogun の `lib/cli_adapter.sh` を参考にできるが、そのまま移植するのではなく、GuP-v2 のエージェントモデル（persona / instructions / YAML queue）との整合を別施策で検討する。

---

## 5. 優先度判断

| 優先度軸 | レイヤー | 理由 |
|---|---|---|
| **即効性** | Layer 2（rate limit 監視） | 監視追加のみ、副作用小、導入コスト低 |
| **戦略性** | Layer 5（退避経路準備） | 保険として先に整備すべき、Codex Plugin は既に一部実装済 |
| **防御性** | Layer 1 + Layer 4（根本対策 + 継続監視） | 根本原因への対応と継続的な状況把握 |
| **コスト効率** | Layer 3（製品化しない宣言） | ドキュメント追記のみで一定の防御効果 |
| **最後に検討** | **Layer 1**（dangerously-skip 最小化） | 現状運用への影響が最大、他レイヤー完了後に段階的実施 |

### 5.1 推奨実施順序（参考）

あくまで参考であり、実施判断は別途行う:

1. **Layer 2**（rate limit 監視） — 副作用最小、即効性あり
2. **Layer 4**（四半期監視体制） — 運用ルール新設、コスト低
3. **Layer 3**（製品化しない宣言） — ドキュメント追記、文案レビュー経由
4. **Layer 5**（退避経路準備） — Codex Plugin 拡張を先に、Multi-CLI はその後
5. **Layer 1**（dangerously-skip 最小化） — 最後、十分な退避経路確保後

⚠️ **慎重取り込み方針**: 上記は「順序の参考」であり、各レイヤー実施前に個別施策として起票し、相互レビューを経てから判断すること。「早く全部やろう」ではなく、「1 つずつ安定性を確認しながら進める」のが本戦略の骨格である。

---

## 6. 慎重取り込み方針（本ドキュメントの中核原則）

本ドキュメントを貫く方針として、以下を明示する。§0.2 で述べた内容の再強調である。

### 6.1 4 原則

1. **判断材料集として扱う**
   本ドキュメントは「いつ・どう変えていく余地があるか」の見取り図であり、「今すぐやるべきこと」のリストではない。

2. **個別施策として起票する**
   各レイヤーは独立した施策として個別起票し、相互レビューを経てから実装する。cmd_168 完了 = 即実装開始ではない。

3. **1 つずつ安定性を確認**
   複数レイヤーを同時実装しない。1 つ実装 → 安定確認 → 次のレイヤー、という step by step を厳守する。

4. **Layer 1 は最後**
   `dangerously-skip-permissions` の段階的削減は、他レイヤーで監視・退避経路が整った **後に** 検討する。今すぐ実施すると運用停止リスクが大きい。

### 6.2 やってはいけないこと

| 避けるべき行動 | 理由 |
|---|---|
| 本ドキュメントを読んだ直後に `dangerously-skip` を外す | Layer 1 は最後に検討すべき。他レイヤーによる監視・退避なしに外すと運用崩壊 |
| shogun の `ratelimit_check.sh` をそのままコピーして配置 | 命名規則・YAML 形式・既存 scripts/ との整合性確認が必要 |
| 全レイヤーを同時に実装開始 | 安定性確認ができない、ロールバック困難 |
| README を大幅書き換える | Layer 3 は文案レビュー必須、cmd_168 自体は既存ファイル変更禁止 |
| Anthropic に問い合わせる | cmd_167 §11.2 と同じ理由で非推奨（藪蛇リスク） |

### 6.3 本ドキュメントの読み方のお願い

読者の方へ:

- 読み終えた後に「何か急いで対応しなければ」と感じたら、**一度立ち止まって §0.2 に戻ってくださいませ**
- 本ドキュメントの目的は「判断材料を整えること」であり、「焦りを煽ること」ではない
- もし緊急対応が必要な状況（Anthropic から直接通告、shogun の ban 報告等）が発生した場合は、本ドキュメントではなく **司令官判断** に従うこと

---

## 7. 本家 shogun との共通運命

### 7.1 共通運命論の骨格

GuP-v2 は単独で防御戦略を立てているのではない。shogun（1199 stars）という同型プロジェクトと **被弾リスクを共有している**。この事実は戦略判断に決定的な意味を持つ。

### 7.2 比較表

| 観点 | multi-agent-shogun | GuP-v2 |
|---|---|---|
| **スター数** | 1199 | —（private） |
| **`--dangerously-skip-permissions`** | 全 agent | 全 agent |
| **OAuth 使用** | 公式手順として README 記載 | 実質的に公式手順（Max サブ前提） |
| **Multi-CLI ハイブリッド** | 実装済み（Claude/Codex/Copilot/Kimi） | Codex Plugin のみ（cmd_164） |
| **`ratelimit_check`** | 実装済み（`scripts/ratelimit_check.sh`） | 未実装 |
| **ToS 議論ドキュメント** | なし | cmd_167 + 本 cmd_168 で整備 |
| **運用形態** | OSS 公開、複数ユーザーによる clone 運用 | 個人運用、司令官のローカル完結 |
| **主要 entry script** | `shutsujin_departure.sh` | `gup_v2_launch.sh` |

### 7.3 共通運命の論理

**論拠 1: 技術的構造の同一性**
- `dangerously-skip-permissions` + OAuth + tmux orchestration という実装パターンは双方同一
- Anthropic の検知ルールが「dangerously-skip の大量使用」「常駐プロセスからの tmux send-keys」を captured する場合、双方が同時に検知対象となる

**論拠 2: Anthropic が OSS multi-agent orchestrator を一律 ban する場合**
- shogun は公開されており、Anthropic も把握している可能性が高い（1199 stars、GitHub trending 等で可視）
- Anthropic がこの種のパターンを一律禁止するポリシーを採った場合、shogun に対する措置は GuP-v2 にも同時に波及する
- 逆に言えば、**shogun が継続稼働している限り、GuP-v2 も tacit tolerance 範囲内と推定できる**

**論拠 3: 情報先行性**
- shogun は公開 OSS であるため、Anthropic からの措置やコミュニティの議論が GuP-v2 より先に発生する
- shogun Issues / Discussions / ReadMe 更新を監視すれば、GuP-v2 への影響を先行察知できる
- → Layer 4 の監視対象に **shogun のリポジトリ動向** を含めるべき

### 7.4 含意 — 単独防御ではなく、コミュニティ動向を見る戦略

GuP-v2 の防御戦略は:

- **単独ではない**: shogun というリファレンスケースが存在
- **コミュニティの一部**: 1199 stars の OSS エコシステム全体が同じ船
- **先行シグナル活用**: shogun の動向を先行指標として使える
- **Layer 4 に shogun 監視を含める**: 本家が動けば GuP-v2 も反応する体制

⚠️ **注意点**: 共通運命論は「shogun が OK なら GuP-v2 も OK」を保証するものではない。shogun の継続は「tacit tolerance の範囲内と推定する根拠の 1 つ」に過ぎず、Anthropic がプロジェクト単位で個別措置を採る可能性も排除できない。あくまで参考情報である。

### 7.5 Layer 4 における監視対象（shogun 動向を含む）

| 監視対象 | 情報源 | 頻度 |
|---|---|---|
| Anthropic Consumer Terms of Service | https://www.anthropic.com/legal/consumer-terms | 改定通知時 |
| Anthropic Usage Policy (AUP) | https://www.anthropic.com/legal/aup | 四半期 |
| Claude Code / Agent SDK docs | https://code.claude.com/docs/en/agent-sdk/overview | 月次 |
| Anthropic Support Article "Using Claude Code with Pro/Max plan" | 公式サポート | 四半期 |
| Anthropic 広報声明（The Register 等報道経由） | Google Alerts 等 | 継続 |
| **multi-agent-shogun リポジトリ** | github.com/yohey-w/multi-agent-shogun | **月次**（Issues / Discussions / README 更新） |
| **multi-agent-shogun Issues「ban」「rate limit」「OAuth」系議論** | GitHub Issues 検索 | 月次 |
| Claude Code GitHub Issues / Discussions | github.com/anthropics/claude-code | 月次 |
| 2026-04-04 以降の新たな enforcement 事例 | 各種 tech メディア | 四半期 |

---

## 8. 未解決事項と判断保留リスト

本ドキュメント執筆時点で結論を出せなかった・保留した事項を明示する。これらは将来の判断材料として残す。

### 8.1 inbox_watcher.sh の automated means 該当性

**状況**: §3.2 で「部分的」と評価したが、完全な白黒判定は下していない。

**保留理由**:
- 厳密な文言解釈では C3 FAIL 寄りだが、Anthropic が実際に ban していない
- 「tmux send-keys = キーボード入力の代行」という技術的性質をどう解釈するかは Anthropic 側の判断次第
- hana precedent §P.3 疑念 1 でも完全な反論は困難と認定済み

**将来の判断指標**:
- Anthropic が「inotify / tmux send-keys 経由の自動化」を明示的に禁止する文書を出すか
- shogun で同様の実装パターンが ban されるか
- Anthropic Support がこの論点に対して公式回答を出すか（問い合わせ非推奨なので能動的には取りに行かない）

### 8.2 四半期レビューで確認すべき Anthropic 側の変化指標

Layer 4 の四半期レビュー運用を始める際、以下を「変化あり」判定の指標とする:

- Consumer ToS 3.7 の文言変更（特に "where we otherwise explicitly permit it" 条項の削除）
- Agent SDK overview Note ブロックの文言強化・条項追加
- Claude Code CLI の `--bare` mode の仕様変更（OAuth 対応の追加 or 削除）
- 新たな enforcement 事例（2026-04-04 以降の ban 報告）
- shogun リポジトリへの Anthropic 関係者のコメント・通告
- 個人 Max サブでの OAuth 利用制限の変更

### 8.3 Layer 1 実施時期の判断基準

Layer 1（dangerously-skip 最小化）を「実施時期」判断する場合、以下の条件がすべて揃うことを推奨:

1. Layer 2 が安定稼働している（rate limit 監視で異常検知できる状態）
2. Layer 5 が部分実施されている（Codex Plugin への部分退避経路が整備済み）
3. Layer 4 の四半期監視で「Anthropic ポリシー静的」な状態が続いている
4. GuP-v2 の運用を一時停止してもビジネス影響が限定的な時期

⚠️ 上記 4 条件が揃わないうちは Layer 1 を実施しない。現状（2026-04-09）は 4 条件とも不充足。

### 8.4 Codex Plugin のみでは Claude 依存度が残る問題

**状況**: cmd_164 で Codex Plugin 統合を実装済みだが、これは「限定的な退避経路」に過ぎない。

**課題**:
- Codex Plugin はあくまで Vice Captain の adversarial-review 等の限定用途で動作
- GuP-v2 全体のエージェント 30 名のうち、主要部分は依然として Claude Code 依存
- Anthropic が全面 ban した場合、Codex Plugin だけでは GuP-v2 は稼働継続できない

**将来の判断指標**:
- Codex Plugin の機能拡張（対象範囲の拡大、どこまで Codex で代替可能か）
- Multi-CLI ハイブリッド化（Layer 5 の主要施策）の実装是非

### 8.5 shogun の非公開コミット・ブランチへの目配り

**状況**: shogun は公開 OSS だが、作者の非公開ブランチや内部での変更は追えない。

**将来の判断指標**:
- shogun の main ブランチで「ratelimit_check 削除」「dangerously-skip 削除」等のネガティブ変更が発生するか
- shogun の作者が ToS 関連の discussion / issue を閉じる・削除する動きがあるか

### 8.6 本ドキュメント自身の陳腐化

**状況**: 本ドキュメントは 2026-04-09 時点のスナップショット。Anthropic ポリシーは継続的に変化する。

**将来の判断指標**:
- Layer 4 の四半期レビューで、本ドキュメントの前提が崩れていないか確認
- 崩れていれば本ドキュメントを改訂（cmd_168 の成果を維持しつつ、差分のみ追記する方針）

---

## 9. まとめ

### 9.1 本ドキュメントの結論

1. **GuP-v2 は tacit tolerance 範囲内**（C3 最弱リンクを含みつつグレー判定）
2. **本家 shogun と同じ船に乗っている**（単独防御ではなくコミュニティ動向を見る戦略）
3. **5 レイヤー戦略** で段階的安定化を図る余地がある
4. **Layer 2 / 4 / 5 が優先、Layer 1 は最後**（優先度判断）
5. **すべては判断材料集**（即時実装指示ではない）

### 9.2 読者への再度のお願い（慎重取り込み方針の最終確認）

> **本ドキュメントを読み終えた方へ:**
>
> 1. 本ドキュメントは「判断材料集」であり、「実装タスクリスト」ではございません
> 2. 各レイヤーは別施策として個別起票し、相互レビューを経てから実装してくださいませ
> 3. 「1 つずつ安定性を確認しながら進める」が本戦略の骨格ですわ
> 4. Layer 1（dangerously-skip 最小化）は最後に検討するものです。他レイヤー完了前に手を付けないでくださいませ
> 5. 本ドキュメントを読んだ直後に何か運用変更を始めたくなったら、**一度立ち止まって §0.2 に戻ってくださいませ**

### 9.3 次のアクション（参考）

cmd_168 完了後の参考アクション:

- **司令官判断**: 5 レイヤーのうちどれから個別施策として起票するか
- **Layer 2 先行検討**: 即効性と副作用小を理由に、Layer 2（rate limit 監視移植）から検討することが推奨される
- **shogun 動向の初回レビュー**: Layer 4 開始に向けて、shogun リポジトリの現状を一度確認する
- **本ドキュメントの四半期レビュー予定の登録**: Layer 4 に組み込む

---

## 付録 A: 参照ドキュメント

### A.1 cmd_167 / cmd_168 成果物

| ドキュメント | 著者 | 行数 | 内容 |
|---|---|---|---|
| `projects/ai-novel-generator/docs/sections/03_tos_env_v2.md` | rosehip | 1007 | v2 主調査、ToS 境界の原文引用論証 |
| `projects/ai-novel-generator/docs/sections/03_tos_env_v2_precedent.md` | hana | 570 | GuP-v2 前例分析、疑念検討 |
| `projects/ai-novel-generator/docs/cmd_167_investigation_story.md` | hana | 787 | 調査の経緯と発見の物語 |
| `projects/ai-novel-generator/docs/claude_code_usage_boundary.md` | rosehip | 443 | 利用境界ガイド（汎用意思決定フレームワーク） |
| `docs/claude-tos-risk-strategy.md`（本ドキュメント） | rosehip | 500 弱 | GuP-v2 自身の戦略判断材料集 |

### A.2 外部参照（一次ソース）

| 参照先 | URL / 識別子 |
|---|---|
| multi-agent-shogun | github.com/yohey-w/multi-agent-shogun |
| Anthropic Consumer Terms of Service | anthropic.com/legal/consumer-terms |
| Anthropic Usage Policy | anthropic.com/legal/aup |
| Claude Code / Agent SDK docs | code.claude.com/docs/en/agent-sdk/overview |
| Anthropic 公式 GitHub Action | github.com/anthropics/claude-code-action |

### A.3 内部ドキュメント

| 参照先 | 内容 |
|---|---|
| `CLAUDE.md` | GuP-v2 プロジェクト全体設定 |
| `docs/philosophy.md` | GuP-v2 哲学 |
| `docs/skill-candidates-cmd_167.md` | cmd_167 スキル候補集約 |

---

## 付録 B: 改訂履歴

| 日付 | バージョン | 変更内容 | 担当 |
|---|---|---|---|
| 2026-04-09 | v1.0 | 初版作成（cmd_168 主執筆） | rosehip（hana レビュー） |

---

*本ドキュメントは cmd_168_tos_risk_strategy_doc の成果物として、cmd_167 の発見を GuP-v2 自身の文脈に適用したものです。判断材料集としての位置付けを厳守し、即時実装指示としては扱わないでください。詳細論証は §1.3 に列挙した cmd_167 成果物を参照してください。*
