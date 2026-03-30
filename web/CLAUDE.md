# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.

## turbopack.root — PROHIBITED

**NEVER set `turbopack.root` in `next.config.ts`.**

### Why it is forbidden

Setting `turbopack.root: path.resolve(__dirname)` causes Turbopack to resolve module imports starting from the monorepo root instead of `web/`. This breaks CSS `@import "tailwindcss"` because Tailwind CSS is installed in `web/node_modules/`, not the root `node_modules/`.

### Error you will see

```
Module not found: Can't resolve 'tailwindcss'
```

### Correct approach

Do **not** set `turbopack.root`. Even in a monorepo layout, Turbopack works correctly without it — leave the option unset and let Next.js resolve modules from `web/node_modules/` as normal.

## Web UI 開発ガイド

このセクションは Web UI（`web/` ディレクトリ）を修正するタスクを受けた隊員向けのガイド。

### ディレクトリ構成

```
web/
├── app/                    # Next.js App Router ページ + API ルート
│   ├── page.tsx            # ルートページ（全ビューの統合、SSE接続）
│   ├── layout.tsx          # ルートレイアウト
│   ├── chat/page.tsx       # チャットビュー
│   ├── agents/page.tsx     # 状態ビュー
│   ├── git/page.tsx        # Git ビュー
│   ├── messages/page.tsx   # メッセージビュー
│   ├── progress/page.tsx   # 進捗ビュー
│   └── api/                # API ルート
│       ├── agents/
│       │   ├── active/     # アクティブエージェント設定
│       │   ├── command/    # send-keys コマンド送信
│       │   ├── list/       # エージェント一覧（REST）
│       │   ├── stream/     # capture-pane SSE ストリーム
│       │   └── upload/     # 画像アップロード
│       ├── sse/
│       │   ├── agents/     # エージェントステータス SSE
│       │   └── messages/   # inbox メッセージ SSE
│       ├── git/            # Git 情報 API
│       ├── image/          # アップロード画像配信
│       ├── queue/          # キュー操作
│       ├── tasks/          # タスク一覧
│       └── usage/          # 使用量トラッカー
├── components/
│   ├── shared/             # 共通コンポーネント（Avatar, ProgressBar, StatusDot）
│   ├── chat/               # チャットビュー用
│   ├── agents/             # 状態ビュー用
│   ├── git/                # Git ビュー用
│   ├── messages/           # メッセージビュー用
│   ├── progress/           # 進捗ビュー用
│   └── layout/             # Sidebar, Header
├── lib/                    # ビジネスロジック・ユーティリティ
│   ├── tmux.ts             # tmux 操作（listPanes, sendKeys 等）
│   ├── pane-streamer.ts    # capture-pane ポーリング + ステータス判定
│   ├── capture-pane-parser.ts  # テキスト → セグメント（トークナイザ）
│   ├── segment-to-block.ts     # セグメント → UIブロック（ブロックビルダー）
│   ├── store.ts            # Zustand グローバルストア
│   ├── sse-client.ts       # SSE 接続（クライアント側）
│   ├── agent-names.ts      # エージェントID → 表示名マッピング
│   ├── command-sanitizer.ts # D001-D012 破壊的操作ブロック
│   ├── audit-log.ts        # コマンド監査ログ
│   ├── auth.ts             # 認証
│   └── use-messages-sse.ts # inbox SSE フック
├── types/                  # TypeScript 型定義
├── public/avatars/         # キャラクターアバター画像（200x200 PNG）
├── middleware.ts           # 認証ミドルウェア
└── __tests__/              # テスト
```

### データフロー

```
[tmux pane] ──capture-pane──→ [pane-streamer.ts] ──SSE──→ [sse-client.ts] ──→ [store.ts] ──→ [UI]
                                 3秒間隔                    EventSource          Zustand
                                 差分検知
```

1. **pane-streamer.ts**: サーバー側で tmux の capture-pane を3秒間隔でポーリング。アクティブエージェント（選択中）は優先ポーリング
2. **SSE**: agent-output イベントで capture-pane の全文を送信（差分ではなくスナップショット）
3. **store.ts**: `latestOutput[agentId]` に格納
4. **MessageList.tsx**: `latestOutput` を capture-pane-parser → segment-to-block でパースして UI ブロックに変換

### チャットパーサーの仕組み（重要）

capture-pane テキストの表示は 2段階パイプライン:

1. **capture-pane-parser.ts**（トークナイザ）: テキスト → セグメント配列
   - プロンプト行（`❯`）で発話者を識別
   - ツール呼び出し行（`Bash(...)`, `Read(...)` 等）を検出
   - ツール結果行を対応するツール呼び出しに紐付け
2. **segment-to-block.ts**（ブロックビルダー）: セグメント → UI ブロック
   - `markdown-bubble`: エージェントのテキスト出力（吹き出し表示）
   - `tool-execution`: ツール呼び出し＋結果（折りたたみ表示）
   - `user-input`: ユーザーからの入力
   - `fallback`: パースできなかったテキスト

**パーサーを修正する場合は必ず `__tests__/capture-pane-parser.test.ts` を実行すること。**

### send-keys の仕組み（重要）

`lib/tmux.ts` の `sendKeys()` でエージェントにコマンドを送信。

```
send-keys -l "コマンドテキスト"  → 50ms wait → send-keys Enter
```

**禁止事項:**
- `paste-buffer -p` を使わないこと（bracketed paste モードで送られ、Claude Code が「貼り付けテキスト」と解釈してコマンド実行されない）
- `send-keys` で `-l` フラグなしでテキストを送らないこと（特殊キー名として解釈される可能性）

### エージェント表示名

内部ID（`darjeeling`, `captain_darjeeling`, `chief_of_staff` 等）は UI に直接表示しない。
必ず `lib/agent-names.ts` の `getAgentDisplayName()` を経由する。

API レスポンスで `name` フィールドを返す場合も同様に表示名を使用する。

### アバター画像

- **格納場所**: `public/avatars/{agent_id}.png`（200x200, RGBA）
- **コンポーネント**: `components/shared/Avatar.tsx`
- **objectPosition**: AVATARS 定数で各キャラの顔位置を調整
- **複合ID対応**: `captain_darjeeling` → `darjeeling.png`, `chief_of_staff` → `miho.png` に自動マッピング（`normalizeAgentId()` in Avatar.tsx）
- **画像の基準**: みほ・マリー・ケイ・エリカが良い例（顔〜肩上のクロップ）

### 状態判定ロジック

`pane-streamer.ts` + `api/agents/list/route.ts` + `api/sse/agents/route.ts`:

| 状態 | 条件 |
|------|------|
| active | paneStates に記録あり & active=true |
| idle | hasPrompt=true（❯ が表示されている） |
| stuck | 5分以上変化なし & active でも idle でもない |
| error | pane が存在しない |

**注意**: idle 時は `stuckMin: 0` を返すこと。idle なのに stuck 分数を返すと UI が停滞扱いにする。

### YAML 表示

Write/Edit/Update ツールで `.yaml` / `.yml` ファイルを操作した場合、チャットビューでは全文展開せず要約表示+アコーディオン折りたたみにする。これは `BlockRenderer.tsx` で処理。

### テスト

```bash
cd web
npx vitest run              # 全テスト
npx vitest run __tests__/capture-pane-parser.test.ts  # パーサーのみ
```

### よくあるミス

1. **turbopack.root を設定する** → ビルドエラー。上記「turbopack.root — PROHIBITED」参照
2. **paste-buffer -p を使う** → コマンドが貼り付けになる。send-keys -l を使う
3. **agent ID をそのまま表示する** → getAgentDisplayName() を使う
4. **idle 時に stuckMin > 0 を返す** → 待機中が停滞扱いになる
5. **パーサー修正後にテストを実行しない** → リグレッション発生
