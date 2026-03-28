# HP案件向け Claude Code Skill 選定・導入調査レポート

**task_id**: subtask_126a
**parent_cmd**: cmd_126
**作成日**: 2026-03-26
**作成者**: ナオミ

---

## 1. 調査概要

### 調査ソース
- skills.sh マーケットプレイス（累計90,142件インストール）
- awesome-claude-code (hesreallyhim, ⭐32,300)
- awesome-claude-code-toolkit (rohitg00, 135エージェント/35スキル/42コマンド)
- awesome-agent-skills (VoltAgent, 1,030+スキル)
- Zenn記事3件（用途別おすすめ、個人開発加速、2026年初頭まとめ）
- 各スキルのGitHubリポジトリ

### 選定基準
1. フロントエンド実装支援（CSS/アニメーション/レスポンシブ）
2. コードレビュー・品質管理
3. デザインQC自動化
4. HP案件での再利用性
5. 既存GuP-v2システムとの共存性

---

## 2. 司令官候補リスト評価

### 【即入れ候補】

#### 2.1 superpowers (obra/superpowers) ⭐112K

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/obra/superpowers |
| ライセンス | MIT |
| インストール | `/plugin install superpowers@claude-plugins-official` |

**機能:**
- ブレインストーミング（構造化思考）
- Git worktree 分離開発
- タスク計画策定
- サブエージェント駆動開発（並列実行+コードレビュー）
- TDDワークフロー
- コードレビュー / ブランチ完了処理
- メタスキル（新スキル自動作成）

**HP案件有用性: 中**
- サブエージェント駆動やworktree管理はGuP-v2の既存機能と重複する
- メタスキル（新スキル作成機能）は有用だが、GuP-v2独自のYAML/inbox構造との統合が必要

**注意事項:**
- 20+スキルがバンドルされており、導入するとワークフロー全体がsuperpowers流に変わる
- **GuP-v2のCLAUDE.md指示・YAMLベースタスク管理と競合する可能性が高い**
- 部分導入（個別スキルのみ）の可否要確認

**判定: 要慎重検討** — 全体導入はGuP-v2と競合。メタスキル部分のみ抜き出せるなら有用。

---

#### 2.2 frontend-design (Anthropic公式)

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design |
| 提供元 | Anthropic（claude-code内蔵） |
| インストール | 既にシステムに組み込み済み（Skill toolで利用可能） |

**機能:**
- 「統計的中央値デザイン」を回避し独自性のあるUI生成
- 大胆なタイポグラフィ・カラーパレット
- アニメーション・スクロール連動インタラクション
- 非対称レイアウト・グリッド破壊的空間構成

**HP案件有用性: 条件付き高**
- **新規LP・プロトタイプ作成**: 非常に有用（suzuki-tax プロトタイプ等）
- **既存デザイン踏襲の移行タスク**: 逆効果（fujimi-v2等、v1完全踏襲方針と矛盾）

**判定: 導入済み（条件付き使用）** — 新規デザイン時のみ使用。移行タスクでは使用禁止。

---

#### 2.3 playwright-skill (lackeyjb/playwright-skill) ⭐2.1K

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/lackeyjb/playwright-skill |
| インストール | `npx skillsadd lackeyjb/playwright-skill` + `npm run setup` |

**機能:**
- Playwrightコード自律生成・実行
- スクリーンショット取得・PDF生成
- フォーム入力、クリック、ダイアログ処理
- headless/headed モード切替

**HP案件有用性: 高**
- デザインQCのスクリーンショット取得自動化に直結
- 現在手動で行っているv1/v2比較を自動化できる
- 移行タスクのルール3（スクショ証跡添付）に対応

**注意事項:**
- Node.js必須、Chromiumインストールでディスク容量消費
- tmux内ではheadlessモード必須
- 既存の`npx playwright screenshot`コマンドとの使い分けが必要

**判定: 推奨** — デザインQC効率化に直結。

---

#### 2.4 trailofbits/skills ⭐3.9K

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/trailofbits/skills |
| ライセンス | CC BY-SA 4.0 |
| インストール | `/plugin marketplace add trailofbits/skills` |

**機能（40+プラグイン）:**
- Semgrep/CodeQL統合コード監査
- サプライチェーンリスク評価
- GitHub Actionsセキュリティ監査
- スマートコントラクト脆弱性スキャン
- タイミングサイドチャネル検出

**HP案件有用性: 低**
- セキュリティ監査特化のため、HP案件に直接的用途なし
- 本番デプロイパイプラインの検証時には活用可能だが優先度低い

**判定: 見送り** — HP案件での優先度は低い。ai-novel-generator等のWebアプリ案件では検討の余地あり。

---

### 【検討枠】

#### 2.5 claude-health (tw93/claude-health)

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/tw93/claude-health |
| インストール | `npx skills add tw93/claude-health -a claude-code -s health -g -y` |
| 使用 | `/health` |

**機能:**
- `.claude/` 配下の設定を6層で体系的に監査
- プロジェクト複雑度の自動検出（Simple/Standard/Complex）
- セキュリティ監査（プロンプトインジェクション、認証情報漏洩等）
- MCPオーバーヘッド監視

**HP案件有用性: 中**
- GuP-v2の設定が適切かどうかの定期チェックに有用
- 新メンバー（エージェント）追加時の設定検証に使える

**判定: 推奨（グローバル導入）** — 設定監査ツールとして定期実行に適切。

---

#### 2.6 planning-with-files (OthmanAdi/planning-with-files) ⭐17K

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/OthmanAdi/planning-with-files |
| インストール | `npx skills add OthmanAdi/planning-with-files --skill planning-with-files -g` |
| 使用 | `/plan`, `/plan:status` |

**機能:**
- 3ファイル（task_plan.md, findings.md, progress.md）自動生成
- セッション跨ぎのコンテキスト復元
- ツール使用前の計画再読込
- 進捗追跡

**HP案件有用性: 低**
- **GuP-v2のYAMLベースタスク管理と完全に重複する**
- task YAML + report YAML + dashboard.md で同等の機能を実現済み
- 導入するとファイル管理が二重化し混乱の元

**判定: 見送り** — 既存のGuP-v2タスクシステムで十分。単独プロジェクトで使う場合のみ検討。

---

#### 2.7 humanizer-ja

**調査結果: 存在しない**

- 英語版 humanizer (blader/humanizer) は存在（24パターンのAI文章特徴を検出・除去）
- 中国語版 Humanizer-zh (op7418/Humanizer-zh) も存在
- **日本語版は未開発**

**HP案件有用性: 潜在的に高**
- HP案件のコンテンツ文言は「v1完全踏襲」方針のため、現時点では不要
- 新規コンテンツ作成時に日本語AI臭さ除去は有用

**判定: 将来課題** — 英語版をフォークして日本語パターン（「〜と言えるでしょう」多用、箇条書き過多等）を追加するスキル開発候補。

---

## 3. 追加発見スキル（司令官候補外）

| スキル名 | リポ/ソース | 有用性 | 概要 |
|---------|-----------|--------|------|
| visual-regression | awesome-claude-code-toolkit | 高 | スクリーンショット比較による回帰テスト。v1→v2差分検出自動化 |
| lighthouse-runner | awesome-claude-code-toolkit | 高 | パフォーマンス・SEO・アクセシビリティ自動監査 |
| accessibility-checker | awesome-claude-code-toolkit | 中 | WCAG準拠チェック |
| document-skills | anthropics/skills ⭐103K | 中 | DOCX/PDF/PPTX/XLSX作成・編集 |
| Web Assets Generator | Alonw0 (awesome-claude-code) | 中 | favicon, PWAアイコン, OGP画像生成 |
| Design Review Workflow | OneRedOak (awesome-claude-code) | 中 | 自動UI/UXデザインレビュー |
| vercel-react-best-practices | Zenn記事 | 中 | Next.js/React自動診断 |
| ui-ux-pro-max | Zenn記事 | 中 | 参考URLからUI/UX解析 |

---

## 4. セッション振り返りskill 導入検討

### 4.1 候補

#### claude-reflect (BayramAnnakov/claude-reflect) — 推奨

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/BayramAnnakov/claude-reflect |
| インストール | `claude plugin marketplace add bayramannakov/claude-reflect` → `claude plugin install claude-reflect@claude-reflect-marketplace` |
| コマンド | `/reflect`, `/reflect --scan-history`, `/reflect-skills`, `/reflect --dedupe` |

**機能:**
- ユーザーの修正・フィードバックを自動キャプチャ
- CLAUDE.md/AGENTS.mdに永続化
- ワークフローパターン発見 → 再利用可能スキル化
- 重複統合機能（`--dedupe`）

#### claude-skill-session-retrospective (accidentalrebel) — 軽量代替

| 項目 | 内容 |
|------|------|
| リポURL | https://github.com/accidentalrebel/claude-skill-session-retrospective |
| インストール | `cp -r session-retrospective ~/.claude/skills/` |
| コマンド | `/session-retrospective` |

**機能:**
- セッションJSONL履歴を解析
- TL;DR、課題、判断経緯、教訓、テクニックをマークダウン出力
- 軽量・シンプル

### 4.2 既存システムとの共存分析

| 既存の仕組み | 役割 | 振り返りskillとの関係 |
|-------------|------|---------------------|
| **Memory MCP** | Knowledge Graphベース永続記憶（entities/relations/observations） | 別レイヤー。claude-reflectはCLAUDE.md/rules書き込み、MemoryはMCPサーバー書き込み。競合なし |
| **auto memory** | MEMORY.mdへの自動追記（user/feedback/project/reference型） | claude-reflectと目的が近い。ただしauto memoryはMEMORY.mdファイル、claude-reflectはCLAUDE.md/rules。対象ファイルが異なるため共存可能 |
| **skill_candidate** | 隊員の報告YAMLに含まれるスキル候補フィールド | claude-reflectの`/reflect-skills`と目的が近い（パターン発見→スキル化）。skill_candidateは手動報告、reflectは自動検出。補完関係 |

### 4.3 共存設計案

```
┌─────────────────────────────────────────────────────────┐
│ セッション中の学習                                        │
│                                                         │
│  auto memory → MEMORY.md（feedback/project/reference型） │
│  Memory MCP → Knowledge Graph（entities/relations）      │
│                                                         │
│ セッション終了時の振り返り                                  │
│                                                         │
│  claude-reflect → CLAUDE.md / .claude/rules/（ルール化）  │
│  skill_candidate → report YAML（パターン報告）            │
│                                                         │
│ 定期的な統合                                              │
│                                                         │
│  /reflect --dedupe → 重複除去                            │
│  /reflect-skills → パターン→スキル化提案                   │
└─────────────────────────────────────────────────────────┘
```

**共存の結論:** claude-reflectは既存の3つの仕組み（Memory MCP, auto memory, skill_candidate）と異なるレイヤー（CLAUDE.md/rules書き込み）で動作するため、共存可能。ただしGuP-v2では複数エージェントが同一CLAUDE.mdを参照するため、reflectによるCLAUDE.md書き換えは全エージェントに影響する点に注意。**大隊長（杏）またはセッション終了時の司令官レビューでのみ使用することを推奨。**

---

## 5. 推奨スキル一覧（優先度順）

| # | スキル名 | 導入区分 | 理由 |
|---|---------|---------|------|
| 1 | **playwright-skill** | 即入れ | デザインQCスクショ自動化。移行タスクのルール3に直結 |
| 2 | **frontend-design** | 導入済み | 新規LP/プロトタイプ用。移行タスクでは使用禁止 |
| 3 | **claude-reflect** | 即入れ | セッション振り返り。既存システムと共存可能。大隊長限定使用推奨 |
| 4 | **claude-health** | 即入れ | 設定診断。グローバル導入し定期チェック |
| 5 | **visual-regression** | 検討 | v1→v2デザイン差分自動検出。playwright-skillとの組み合わせで効果大 |
| 6 | **lighthouse-runner** | 検討 | パフォーマンス・SEO監査。Netlifyデプロイ前チェック |
| 7 | **accessibility-checker** | 検討 | WCAG準拠チェック。HP案件の品質底上げ |

### 見送り

| スキル名 | 理由 |
|---------|------|
| superpowers | GuP-v2のタスク管理と競合。部分導入の可否要検証 |
| trailofbits/skills | HP案件での優先度低 |
| planning-with-files | GuP-v2のYAMLタスク管理と完全重複 |
| humanizer-ja | 存在しない。将来のスキル開発候補 |

---

## 6. 導入手順

### 即入れスキルのインストール

```bash
# 1. playwright-skill
npx skillsadd lackeyjb/playwright-skill
cd ~/.claude/plugins/marketplaces/playwright-skill/skills/playwright-skill
npm run setup

# 2. claude-reflect（大隊長環境のみ）
claude plugin marketplace add bayramannakov/claude-reflect
claude plugin install claude-reflect@claude-reflect-marketplace

# 3. claude-health（グローバル）
npx skills add tw93/claude-health -a claude-code -s health -g -y
```

### GuP-v2への統合方法

1. **playwright-skill**: 隊員のデザインQCタスクで`/playwright`コマンドを使用。スクショ取得をスキル経由に統一
2. **claude-reflect**: 大隊長（杏）のセッション終了時に`/reflect`を実行。提案内容を司令官がレビューしてからCLAUDE.mdに反映
3. **claude-health**: 定期的に`/health`を実行し、設定の健全性を確認。結果をdashboard.mdに記載

### CLAUDE.mdへの追記案

```markdown
# Installed Skills
- playwright-skill: デザインQCスクショ自動化（全エージェント使用可）
- claude-reflect: セッション振り返り（大隊長のみ使用）
- claude-health: 設定診断（全エージェント使用可）
- frontend-design: 新規UI生成（移行タスクでは使用禁止）
```

---

## 7. 参考リソース

- [skills.sh](https://skills.sh) — スキルディレクトリ
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) ⭐32.3K
- [awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) — 1,030+スキル
- [anthropics/skills](https://github.com/anthropics/skills) ⭐103K — Anthropic公式
- [Zenn: Claude Code Skills用途別おすすめ9選](https://zenn.dev/kg_filled/articles/50f762610d48c7)
- [Zenn: 個人開発がチート級に加速するSkillsまとめ](https://zenn.dev/imohuke/articles/claude-code-mcp-skills-summary)
