# GuP v2 Web Dashboard

GuP-v2 マルチエージェントシステムの Web UI ダッシュボード。
既存の tmux 運用はそのまま維持し、ブラウザから全エージェントの状態を監視・操作できる「窓」を提供する。

## 前提条件

- Node.js 20+
- GuP-v2 の tmux セッションが起動済み（`gup_v2_launch.sh`）
- tmux の各ペインに `@agent_id` 等のカスタム変数が設定済み（launch スクリプトが自動設定）

## セットアップ

```bash
cd web
npm install
```

## 環境変数

`.env.local` を作成:

```bash
# 認証トークン（必須 — 未設定だと全APIが403）
WEB_UI_AUTH_TOKEN=your-secret-token-here

# 開発時に認証を無効化する場合（本番では絶対に使わない）
# AUTH_DISABLED=true

# GuP-v2 プロジェクトルート（デフォルト: web/ の親ディレクトリ）
# GUP_PROJECT_ROOT=/home/take77/Developments/Tools/multi-agent-GuP-v2
```

## 起動

```bash
# 開発サーバー
npm run dev

# ブラウザで開く
open http://localhost:3000
```

tmux セッションが起動していない状態でも Web UI 自体は起動するが、
エージェント一覧やターミナル出力は空になる。

## 5つのビュー

| ビュー | パス | 説明 |
|--------|------|------|
| Terminal (Chat) | `/` | エージェントのターミナル出力（capture-pane）+ コマンド送信 |
| Messages | `/messages` | inbox YAML の送受信をチャットバブル表示（フィルタ付き） |
| Agents | `/agents` | 全エージェント状態一覧（クラスタ別、stuck 検知） |
| Git | `/git` | マルチリポ対応ブランチツリー（コンフリクト検知） |
| Progress | `/progress` | タスク進捗カンバンボード（リポ別、隊別進捗バー） |

## API Routes

すべての API は Bearer トークン認証が必要（middleware.ts で一括制御）。

### SSE（リアルタイム配信）

| エンドポイント | 説明 |
|---------------|------|
| `GET /api/sse/agents` | エージェント状態の定期配信（tmux list-panes + capture-pane） |
| `GET /api/sse/messages` | inbox YAML 変更の即時配信（chokidar 監視） |
| `GET /api/agents/stream?agentId=xxx` | 特定エージェントのターミナル出力ストリーム |

SSE 接続時はクエリパラメータで認証: `?token=your-secret-token-here`

### REST

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/api/agents/list` | GET | 全エージェント一覧（tmux ペイン情報 + config/agents.yaml） |
| `/api/agents/command` | POST | エージェントにコマンド送信（send-keys） |
| `/api/git/[repoId]/branches` | GET | リポジトリのブランチツリー |
| `/api/git/conflicts` | GET | コンフリクト検知 |
| `/api/tasks` | GET | タスク一覧（queue/tasks/*.yaml） |
| `/api/usage` | GET | Claude 使用量（5h/7d 枠） |

### コマンド送信の安全設計

`POST /api/agents/command` は3層の安全機構を持つ:

1. **ホワイトリスト**: `/clear`, `/model sonnet|opus|haiku` は確認なしで送信可
2. **D001-D012 ブロック**: `rm -rf /`, `git push --force`, `sudo` 等の破壊コマンドは 403 で拒否
3. **Audit Log**: 全コマンド（許可/拒否）を `logs/web-ui-audit.jsonl` に記録

## ディレクトリ構成

```
web/
├── app/                    # Next.js App Router
│   ├── api/                # API Routes (SSE + REST)
│   │   ├── sse/            # Server-Sent Events
│   │   │   ├── agents/     # エージェント状態配信
│   │   │   └── messages/   # inbox メッセージ配信
│   │   ├── agents/         # エージェント操作
│   │   │   ├── list/       # 一覧取得
│   │   │   ├── command/    # send-keys（安全検証付き）
│   │   │   └── stream/     # ターミナル出力ストリーム
│   │   ├── git/            # Git 情報
│   │   ├── tasks/          # タスク進捗
│   │   └── usage/          # Claude 使用量
│   ├── chat/               # Terminal View ページ
│   ├── messages/           # Message View ページ
│   ├── agents/             # Agent View ページ
│   ├── git/                # Git View ページ
│   └── progress/           # Progress View ページ
├── components/
│   ├── agents/             # AgentCard, AgentGrid, StuckAlert
│   ├── chat/               # ChatSidebar, CommandInput, MessageList
│   ├── git/                # BranchTree, BranchDetail, BranchList
│   ├── layout/             # Sidebar, Header
│   ├── messages/           # MessageView, MessageFilter
│   ├── progress/           # KanbanBoard, TaskCard, SquadProgressBar
│   └── shared/             # Avatar, ProgressBar, StatusDot, UsagePanel
├── lib/
│   ├── auth.ts             # Bearer トークン認証
│   ├── command-sanitizer.ts # D001-D012 破壊コマンドブロッカー
│   ├── audit-log.ts        # 操作監査ログ
│   ├── tmux.ts             # tmux 操作（list-panes, capture-pane, send-keys）
│   ├── yaml-watcher.ts     # chokidar YAML ファイル監視
│   ├── pane-streamer.ts    # ターミナル出力ストリーミング
│   ├── usage-tracker.ts    # Claude 使用量取得（OAuth API）
│   ├── store.ts            # Zustand ストア（メイン）
│   ├── git-store.ts        # Zustand ストア（Git）
│   ├── progress-store.ts   # Zustand ストア（Progress）
│   ├── sse-client.ts       # SSE クライアントフック
│   ├── use-messages-sse.ts # メッセージ SSE フック
│   ├── event-bus.ts        # イベントバス
│   └── git.ts              # Git 操作ユーティリティ
├── types/                  # TypeScript 型定義
│   ├── agent.ts
│   ├── git.ts
│   ├── message.ts
│   └── progress.ts
└── middleware.ts            # API 認証ミドルウェア（Edge Runtime）
```

## tmux との関係

```
┌─────────────────────────────────────────────────┐
│  gup_v2_launch.sh (既存・変更なし)                │
│  tmux セッション + 20+ エージェントペイン          │
│  YAML inbox / queue / coordination               │
└──────────────┬──────────────────────┬────────────┘
               │ capture-pane        │ chokidar
               │ list-panes          │ (YAML監視)
               │ send-keys           │
┌──────────────▼──────────────────────▼────────────┐
│  Web UI (Next.js)                                 │
│  SSE でブラウザにリアルタイム配信                    │
│  コマンド送信は安全検証後に send-keys              │
└──────────────────────────────────────────────────┘
```

Web UI を停止しても tmux 運用には一切影響しない。
Web UI はあくまで tmux の「窓」であり、既存の運用フローを置き換えるものではない。
