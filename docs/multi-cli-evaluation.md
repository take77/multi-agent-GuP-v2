# Multi-CLI対応 調査レポート（Codex副隊長構想）

**task_id**: subtask_126b
**parent_cmd**: cmd_126
**作成日**: 2026-03-26
**調査担当**: 秋山優花里（yukari）

---

## 1. エグゼクティブサマリー

GuP-v2の副隊長（QC専任）をOpenAI Codex CLIで動作させる構想について、技術的実現可能性・コスト・リスクを調査した。

**結論: 条件付き推奨（段階的導入）**

- shogunプロジェクトの`cli_adapter.sh`により、マルチCLI抽象化の設計パターンは確立済み
- Codex CLIはFull Autoモード・ファイルR/W・bash実行を備え、副隊長のQCワークフローは技術的に実現可能
- ただし、Linuxサンドボックス非搭載・セッション安定性・MCP制限等のリスクがあるため、限定的な試験運用から始めるべき

---

## 2. shogun cli_adapter.sh マルチCLI抽象化パターン分析

### 2.1 アーキテクチャ概要

[multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) は、4つのCLIツールを統一的に扱う抽象化レイヤーを`lib/cli_adapter.sh`（1000行超）で実装している。

**対応CLI一覧:**

| CLI | モデル例 | 特徴 |
|-----|---------|------|
| Claude Code | Opus/Sonnet/Haiku | Memory MCP、専用ファイルツール |
| OpenAI Codex | GPT-5.3, o4-mini | サンドボックス実行、JSONL出力 |
| GitHub Copilot | 専用エージェント | GitHub MCP内蔵 |
| Kimi Code | k2.5 (Moonshot) | 無料枠あり、多言語対応 |

### 2.2 設計パターン

**Strategy Pattern + Factory Pattern + Configuration-Driven の組み合わせ:**

```
settings.yaml → cli_adapter.sh → CLI固有コマンド生成
                                → CLI固有instruction選択
                                → CLI固有起動プロンプト生成
```

**CLI選択の解決順序:**
1. `cli.agents.{agent_id}.type`（エージェント個別設定）
2. `cli.agents.{agent_id}`（文字列値）
3. `cli.default`（グローバルデフォルト）
4. フォールバック: `"claude"`

### 2.3 主要API関数

| 関数 | 役割 |
|------|------|
| `get_cli_type(agent_id)` | エージェントのCLI種別を解決 |
| `build_cli_command(agent_id)` | CLI固有の起動コマンドを生成 |
| `get_instruction_file(agent_id)` | CLI＋ロール別のinstructionファイルを選択 |
| `validate_cli_availability(cli_type)` | CLIのインストール状態を検証 |
| `get_agent_model(agent_id)` | モデル名を3段階で解決 |
| `find_agent_for_model(model)` | 特定モデルのidle agentを検索 |

### 2.4 CLI固有コマンドパターン

```bash
# Claude Code
MAX_THINKING_TOKENS=0 claude --model sonnet --dangerously-skip-permissions

# OpenAI Codex
codex --model gpt-5.3-codex --search --dangerously-bypass-approvals-and-sandbox --no-alt-screen

# GitHub Copilot
copilot --yolo

# Kimi Code
kimi --yolo --model k2.5
```

### 2.5 Instruction分離設計

CLI種別ごとに専用のinstructionファイルを用意：

| エージェント | Claude用 | Codex用 |
|-------------|---------|---------|
| shogun | `instructions/shogun.md` | `instructions/codex-shogun.md` |
| ashigaru | `instructions/ashigaru.md` | `instructions/codex-ashigaru.md` |

**理由:** 各CLIでツール可用性が異なる（例: Claude → Memory MCP、Codex → `/review`コマンド）

### 2.6 Bloom Level動的ルーティング

タスク複雑度（L1-L6）に基づいてモデルを動的選択：

```yaml
capability_tiers:
  opus:
    max_bloom: 6
    cost_group: claude_max
  sonnet:
    max_bloom: 4
    cost_group: claude_max
  gpt-5.3-codex:
    max_bloom: 5
    cost_group: chatgpt_pro
```

### 2.7 GuP-v2への適用可能性

shogunの設計はGuP-v2に高い親和性がある：
- **YAML通信基盤**: 同様のYAMLベースタスクキュー+inbox方式
- **tmux多ペイン構成**: 同様のtmuxセッション管理
- **設定駆動**: YAMLの1行変更でCLI切替可能な設計

**差分:**
- shogunの階層は2層（将軍→足軽）、GuP-v2は4層（大隊長→参謀長→隊長→隊員）
- shogunはBloom Levelルーティングあり、GuP-v2はまだ未実装
- shogunのcli_adapter.shはPython依存（YAML解析）、GuP-v2はbash+yqベース

---

## 3. OpenAI Codex CLI 機能・制約一覧

### 3.1 基本情報

| 項目 | 内容 |
|------|------|
| リポジトリ | [openai/codex](https://github.com/openai/codex) |
| ライセンス | Apache-2.0 |
| 言語 | Rust（旧版TypeScript→Rust書き直し） |
| Stars | ~67,500 |
| 最新版 | v0.116.0 (2026-03-19) |
| デフォルトモデル | o4-mini |
| インストール | `npm install -g @openai/codex` |

### 3.2 承認モード

| モード | ファイル編集 | シェル実行 | 用途 |
|--------|------------|-----------|------|
| Suggest（デフォルト） | 承認必要 | 承認必要 | 対話的作業 |
| Auto Edit | 自動承認 | 承認必要 | ファイル編集のみ自動化 |
| Full Auto | 自動承認 | 自動承認 | 完全自律動作（副隊長向け） |

### 3.3 サンドボックス

| OS | サンドボックス方式 | 備考 |
|----|-------------------|------|
| macOS 12+ | Apple Seatbelt (`sandbox-exec`) | OS級の保護 |
| **Linux** | **なし** | Docker推奨（`run_in_container.sh`提供） |
| Windows | WSL2経由 | WSL2内の制約に依存 |

**⚠️ 重要**: GuP-v2はLinux環境で動作するため、Codex CLIのサンドボックスは効かない。

### 3.4 設定システム

| ファイル | 役割 | Claude Code対応 |
|---------|------|----------------|
| `~/.codex/config.yaml` | グローバル設定 | `~/.claude/settings.json` |
| `AGENTS.md` (リポルート) | プロジェクト指示 | `CLAUDE.md` |
| `AGENTS.override.md` | 一時的上書き | なし |
| `.env` | 環境変数 | `.env` |

**AGENTS.md マージ順序** (上から下、下が優先):
1. `~/.codex/AGENTS.md`（グローバル）
2. リポルート `AGENTS.md`（プロジェクト共通）
3. カレントディレクトリ `AGENTS.md`（サブフォルダ固有）
4. `AGENTS.override.md`（最高優先度）

### 3.5 セッション管理

| コマンド | 動作 | Claude Code対応 |
|---------|------|----------------|
| `/clear` | 会話リセット | `/clear` |
| `/new` | 新会話開始（画面維持） | なし |
| `/resume` | 過去セッション再開 | `/resume` |
| `/fork` | 会話分岐 | なし |
| `/review` | コードレビュー | なし |
| `/personality` | ペルソナ調整 | なし |

セッション履歴: `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`

### 3.6 MCP対応

- **stdio方式のみ対応**（HTTP/SSEエンドポイントは未対応）
- Claude Codeほどの充実したMCP統合ではない
- GuP-v2で使用中のMemory MCP等はstdio接続なら動作する可能性あり

### 3.7 マルチプロバイダー対応

10以上のプロバイダーをネイティブサポート:
OpenAI, Azure, OpenRouter, Gemini, Ollama, Mistral, DeepSeek, xAI, Groq, ArceeAI, 任意のOpenAI互換API

---

## 4. ペルソナ維持の実現可能性評価

### 4.1 GuP-v2副隊長のペルソナ要件

| 要件 | 内容 |
|------|------|
| キャラクター設定 | persona/*.md の口調・性格 |
| 行動指針 | instructions/vice_captain.md のQCルール |
| 禁止事項 | F001-F005（タスク分解禁止、実装禁止等） |
| 通信プロトコル | inbox_write.sh によるYAML通信 |

### 4.2 Codex CLIでのペルソナ実現手段

| 手段 | 実現度 | 備考 |
|------|--------|------|
| AGENTS.md | ◎ | CLAUDE.mdと同等。プロジェクトルートに配置でき、マージ順序も明確 |
| /personality コマンド | △ | セッション内の一時的な調整のみ |
| 起動プロンプト | ○ | shogun方式で初回に全コンテキストを注入可能 |

### 4.3 評価

**ペルソナ維持は「技術的に可能」だが「品質に懸念あり」**

- AGENTS.mdにペルソナ定義を記載すれば、基本的な口調維持は可能
- ただし、Claude CodeのCLAUDE.md + persona/*.md + instructions/*.mdの多層構造をCodexで完全再現するには、AGENTS.mdの容量制限（`project_doc_max_bytes`）に注意が必要
- Codex CLIは長時間セッションでの一貫性にやや難があるとの報告あり（コミュニティフィードバック）
- GuP-v2のペルソナは日本語が前提 — Codexの日本語対応品質はClaude Codeより劣る可能性

---

## 5. YAML inbox通信の互換性評価

### 5.1 副隊長のYAML通信フロー

```
隊長 → inbox_write.sh → queue/inbox/arisa.yaml (qc_request)
                          ↓
         副隊長がRead → 処理 → Edit(read: true)
                          ↓
         report読み込み → QC実行
                          ↓
         inbox_write.sh → queue/inbox/kay.yaml (qc_result)
```

### 5.2 Codex CLIでの互換性

| 操作 | Codex対応 | 備考 |
|------|-----------|------|
| ファイル読み取り (Read) | ✅ | 標準機能 |
| ファイル編集 (Edit) | ✅ | 標準機能 |
| bash実行 (inbox_write.sh) | ✅ | Full Autoモードで自動実行可能 |
| YAML解析 | ✅ | テキストとして読める |
| tmux操作 | ✅ | tmux内で動作可能 |
| inotifywait連携 | ✅ | inbox_watcherは外部プロセスなのでCLI非依存 |

### 5.3 評価

**YAML inbox通信は完全互換で動作する見込み**

- inbox_write.shはbashスクリプト → Codexのbash実行で問題なく呼べる
- YAML読み書きはテキストファイル操作 → CLI種別に依存しない
- inbox_watcherのinotifywait検知 → ファイル変更ベースなのでCLI非依存
- `/clear`送信によるエスカレーション → Codexも`/clear`をサポート

**唯一の懸念:** Codexの`/clear`後の復帰手順がClaude Codeと異なる可能性がある。CLAUDE.mdの自動読み込みの代わりにAGENTS.mdの自動読み込みが発生する。手順の調整は必要。

---

## 6. コスト比較表

### 6.1 Claude副隊長（現状）

| 項目 | 内容 |
|------|------|
| プラン | Claude Max ($100/月 or $200/月) |
| モデル | Sonnet（副隊長は分析系タスクなのでSonnetで十分） |
| 副隊長の利用量 | QCリクエスト時のみ起動（L4+タスクかつ移行タスク） |
| 月間コスト概算 | Max $100プランの1ペイン分（他エージェントと共有） |

### 6.2 Codex副隊長（提案）

**プランA: ChatGPT Plus ($20/月)**

| 項目 | 内容 |
|------|------|
| コスト | $20/月 |
| レート制限 | 30-150メッセージ/5時間窓 |
| メリット | 低コスト。副隊長のQC頻度なら十分な可能性 |
| デメリット | 重い利用で5時間制限に到達するリスク |

**プランB: ChatGPT Pro ($200/月)**

| 項目 | 内容 |
|------|------|
| コスト | $200/月 |
| レート制限 | 300-1,500メッセージ/5時間窓 |
| メリット | 制限に余裕あり |
| デメリット | Claude Maxと同額。コスト削減にならない |

**プランC: APIキー従量課金**

| モデル | 入力 | 出力 | 備考 |
|--------|------|------|------|
| o4-mini | 標準API料金 | 標準API料金 | 最安。QC程度なら十分か |
| GPT-5 Codex | $1.25/M | $10.00/M | 高品質だが高コスト |
| GPT-5.1-Codex-Mini | $0.25/M | $2.00/M | コスパ最良 |

### 6.3 コスト比較まとめ

| シナリオ | 月額コスト | 評価 |
|---------|-----------|------|
| 現状 (Claude副隊長 on Max) | Max$100プラン内 | ベースライン |
| Codex Plus ($20) + Claude Max減枠 | +$20（Max枠1つ解放可能） | ✅ コスト削減の可能性 |
| Codex API (GPT-5.1-Mini) | 従量（月数ドル程度） | ✅ 最もコスト効率が良い |
| Codex Pro ($200) | +$200 | ❌ コスト増 |

**最適解:** ChatGPT Plus ($20/月) または API従量課金（GPT-5.1-Codex-Mini）で副隊長を運用し、Claude Maxの枠を他のエージェントに回す。

---

## 7. 導入する場合のアーキテクチャ案

### 7.1 最小変更アーキテクチャ

```
┌─────────────────────────────────────┐
│  GuP-v2 tmux session (例: kay)       │
│                                     │
│  pane 0: kay (Captain)    [Claude]  │
│  pane 1: arisa (Vice Cap) [Codex]   │  ← ここだけCodex
│  pane 2: naomi (Member)   [Claude]  │
│  pane 3: yukari (Member)  [Claude]  │
│  ...                                │
└─────────────────────────────────────┘
```

### 7.2 必要な変更

| コンポーネント | 変更内容 | 工数 |
|---------------|---------|------|
| `gup_v2_launch.sh` | Codex CLI起動コマンドの分岐追加 | S |
| `config/settings.yaml` | CLI種別設定の追加 | S |
| `AGENTS.md` (新規) | Codex用のプロジェクト指示（CLAUDE.mdの変換） | M |
| `instructions/codex-vice_captain.md` (新規) | Codex用副隊長instruction | M |
| `persona/codex-arisa.md` (新規) | Codex用ペルソナ（AGENTS.mdに組み込み or 別ファイル） | S |
| `inbox_watcher.sh` | Codex固有の`/clear`送信パターン対応 | S |
| `scripts/cli_adapter.sh` (新規) | shogunから移植・簡略化したCLI抽象化レイヤー | M |

### 7.3 段階的導入計画

**Phase 1: PoC検証（1-2日）**
- 単一のtmuxペインでCodex CLIを手動起動
- AGENTS.mdにQCルール記載
- YAML読み書き・inbox_write.sh実行を手動テスト
- ペルソナ維持の品質を目視確認

**Phase 2: 自動化統合（2-3日）**
- gup_v2_launch.shにCodex起動分岐追加
- cli_adapter.sh（簡略版）の作成
- inbox_watcherのCodex対応

**Phase 3: 本番試験運用（1週間）**
- 実際のQCリクエストをCodex副隊長に流す
- Claude副隊長と並行運用（同じQCを両方に投げて品質比較）
- コスト・品質・安定性のデータ収集

---

## 8. リスク評価

| リスク | 深刻度 | 対策 |
|--------|--------|------|
| Linuxサンドボックスなし | 中 | Full Autoモードの副隊長はファイル変更を行わない（QC読取り専門）ためリスク限定的。Docker化も検討 |
| 長時間セッションの不安定性 | 中 | `/clear`による定期的なセッションリセット（既存のエスカレーション機構が利用可能） |
| 日本語ペルソナの品質低下 | 中 | AGENTS.mdで明示的に日本語指定。品質が許容範囲外なら英語QC出力に切替 |
| レート制限到達 | 低 | 副隊長はL4+移行タスクのQC時のみ起動。頻度は低い |
| MCP Memory非対応リスク | 低 | 副隊長はMemory MCPを多用しない。YAMLベースの状態管理で代替可能 |
| Codex CLI破壊的変更 | 低 | バージョン固定 + cli_adapter.shの抽象化で吸収 |

---

## 9. 結論と推奨

### 9.1 総合評価

| 評価軸 | スコア | コメント |
|--------|--------|---------|
| 技術的実現可能性 | ⭐⭐⭐⭐ (4/5) | YAML通信は完全互換。ペルソナ・instructionも移植可能 |
| コストメリット | ⭐⭐⭐⭐ (4/5) | Plus $20/月 or API従量で大幅削減の可能性 |
| 運用安定性 | ⭐⭐⭐ (3/5) | Linuxサンドボックスなし・セッション安定性に懸念 |
| 導入工数 | ⭐⭐⭐⭐ (4/5) | shogunのcli_adapter.shパターンで工数最小化可能 |
| 品質リスク | ⭐⭐⭐ (3/5) | QC品質がClaude比で劣化する可能性あり |

### 9.2 推奨

**条件付き推奨: Phase 1 PoC検証から開始**

1. **即座にPhase 1（PoC）を実施する価値あり** — 手動テストで技術的互換性を検証できる。工数は1-2日
2. **コスト削減が主目的なら有効** — ChatGPT Plus ($20) + API従量で副隊長コストを月$20以下に圧縮可能
3. **品質を重視するならClaude副隊長を維持** — QCの正確性・日本語品質ではClaude Codeが優位
4. **shogunのcli_adapter.shパターンは積極的に参考にすべき** — 将来的にCopilot/Kimi等への拡張も視野に入る

### 9.3 次のアクション案

- [ ] Phase 1 PoC: Codex CLI単体でのYAML R/W + inbox_write.sh実行テスト
- [ ] AGENTS.mdのドラフト作成（CLAUDE.md + vice_captain.md + persona からの変換）
- [ ] コスト実測: 実際のQCタスク1件あたりのトークン消費量を計測
- [ ] 品質比較: 同一QCタスクをClaude/Codex両方に投げて結果を比較
