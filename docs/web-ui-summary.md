# Web UI ダッシュボード — 実装サマリー

## 概要

multi-agent-GuP-v2 の全30エージェントを監視・操作するための Web UI ダッシュボード。
cmd_134（2026-03-28）で基盤構築を開始し、cmd_154（2026-03-29）まで21施策・134コミットで完成。

- **160ファイル**, **18,000行超**の新規コード
- 全4隊（ダージリン/カチューシャ/ケイ/まほ）が並列で実装

## 技術スタック

| 技術 | バージョン | 用途 |
|------|-----------|------|
| Next.js | 16.2 | フレームワーク（App Router） |
| React | 19.2 | UI |
| Tailwind CSS | v4 | スタイリング |
| Zustand | 5.x | クライアント状態管理 |
| SSE (Server-Sent Events) | — | リアルタイム更新 |
| Vitest | 4.x | テスト |

## 5つのビュー

### 1. チャットビュー（メイン画面）

エージェントの Claude Code 出力をチャット形式で表示。左サイドバーで全30エージェントを切り替え。

- **capture-pane パーサー**: tmux の capture-pane 出力をトークナイズ → ブロック分類（マークダウン吹き出し / ツール実行通知 / ユーザー入力 / フォールバック）
- **コマンド送信**: 入力欄からエージェントに直接コマンドを送信（send-keys -l 方式）
- **画像添付**: ドラッグ&ドロップ or クリップボード貼り付け → /uploads/ に永続保存
- **割り込みボタン**: Escape キー送信でエージェントを中断
- **クイックアクション**: /clear, モデル切替（Sonnet/Opus）のワンクリック実行

### 2. メッセージビュー（連絡タブ）

inbox YAML の全メッセージを SSE でリアルタイム表示。

- 隊別フィルタ（全体/司令部/ダージリン隊/カチューシャ隊/ケイ隊/まほ隊）
- メッセージタイプ別アイコン（タスク配信/完了報告/施策完了/QC依頼 等）
- アーカイブ機能（既読メッセージの整理）
- YAML Write/Edit 操作は要約+アコーディオン表示

### 3. 状態ビュー

全4クラスタ × 各7エージェントのステータスカード一覧。

- ステータス判定: 稼働中(緑) / 待機中(灰) / 停滞(オレンジ) / エラー(赤)
- pane-streamer による capture-pane 差分検知 → プロンプト(❯)有無で idle/active 判定
- stuck 判定: 5分以上変化なしで停滞扱い
- 各カードからターミナルログ展開可能

### 4. Git ビュー

リポジトリの Git 状態を可視化。

- worktree 一覧（アクティブブランチ表示）
- 隊別コミット履歴
- ブランチツリー表示

### 5. 進捗ビュー

タスク YAML ベースのカンバンボード。

- 3列構成: 待機中 / 実行中 / 完了
- squads.yaml に存在するエージェントのみ表示（残骸排除）
- 完了タスクは4時間後に自動非表示
- サマリーカード（全タスク数/実行中/完了率）

## アーキテクチャ

### データフロー

```
tmux pane (各エージェントの Claude Code)
  │
  ├─ capture-pane ──→ pane-streamer.ts ──→ SSE /api/agents/stream ──→ クライアント
  │                   (3秒間隔ポーリング、アクティブエージェントは優先)
  │
  ├─ @agent_id 等 ──→ listPanes() ──→ SSE /api/sse/agents ──→ クライアント
  │   tmux変数          (5秒間隔)      (クラスタ/ステータス情報)
  │
  └─ inbox YAML ───→ yaml-watcher.ts ─→ SSE /api/sse/messages ──→ クライアント
      (queue/inbox/)   (chokidar監視)    (新着メッセージ)
```

### セキュリティ

- **認証**: トークンベース（Cookie: auth_token）。middleware.ts で全 API ルートを保護
- **コマンドサニタイズ**: D001-D012 の破壊的操作パターンを command-sanitizer.ts でブロック
- **監査ログ**: 全コマンド送信を audit-log.ts に記録（許可/拒否/IP/タイムスタンプ）

### 主要ライブラリファイル

| ファイル | 役割 |
|---------|------|
| `lib/tmux.ts` | tmux 操作（listPanes, capturePaneContent, sendKeys） |
| `lib/pane-streamer.ts` | capture-pane ポーリング + 差分検知 + ステータス判定 |
| `lib/capture-pane-parser.ts` | capture-pane テキスト → セグメント分割（トークナイザ） |
| `lib/segment-to-block.ts` | セグメント → UI ブロック変換（ブロックビルダー） |
| `lib/store.ts` | Zustand グローバルストア |
| `lib/sse-client.ts` | SSE 接続管理（クライアント側） |
| `lib/agent-names.ts` | エージェントID → 表示名マッピング |
| `lib/command-sanitizer.ts` | 破壊的操作ブロック |

## 施策履歴

### Phase 1: 基盤構築（cmd_134）
- P1: Next.js scaffold + レイアウト + 認証
- P2: チャットビュー（MessageList + capture-pane パーサー）+ 状態ビュー（AgentGrid）
- P3: Git ビュー + 進捗ビュー
- P4: send-keys API + 使用量パネル

### Phase 2: 品質改善（cmd_135〜cmd_143）
- チャットパーサーの抜本改善（トークナイザ+ブロックビルダー書き直し）
- send-keys のプロンプト待ち検知 + 強制送信
- ステータス判定ロジックの見直し
- UI 微調整多数

### Phase 3: コンテンツ充実（cmd_144〜cmd_148）
- inbox アーカイブ機能
- Git 画面 worktree 対応
- 全30キャラ公式画像差し替え + 顔中心クロップ

### Phase 4: 最終仕上げ（cmd_149〜cmd_154）
- turbopack.root 再発防止
- 表示名統一（captain_XXX → キャラクター名）
- YAML 表示の要約化
- アバター品質追い込み
- send-keys の bracketed paste 問題根本修正（paste-buffer -p → send-keys -l）
- 初回チャット読み込み修正
- タスク YAML クリーンアップ

## 起動方法

```bash
cd web
npm run dev    # http://localhost:3000
```

認証トークンは環境変数または `.env.local` で設定。
