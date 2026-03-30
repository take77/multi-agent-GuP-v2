# scripts/ ディレクトリガイド

## 破壊的操作の安全ルール

ルート CLAUDE.md の「Destructive Operation Safety」セクション（D001-D008）に準拠すること。

scripts/ 固有の注意点:
- **`kill`, `killall`, `pkill` は D006 で絶対禁止** — inbox_watcher や supervisor を止めると全エージェントが通信不能になる
- **`tmux kill-server`, `tmux kill-session` も D006** — 全エージェントのセッションが消失する
- スクリプトの修正後は必ず構文チェック: `bash -n scripts/xxx.sh`

## スクリプト一覧

### 通信基盤（最重要 — 修正時は細心の注意）

| スクリプト | 役割 | 注意点 |
|-----------|------|--------|
| **inbox_write.sh** | メールボックスへのメッセージ書き込み（flock 排他ロック付き） | 並行安全性の要。flock の仕組みを壊すと全通信が破綻する。YAML 構造の変更は inbox_watcher.sh との整合性を要確認 |
| **inbox_watcher.sh** | メールボックス監視 + 起動シグナル配信（inotifywait ベース） | 長時間稼働デーモン。send-keys のタイミング・エスカレーション閾値を変更する場合は全エージェントに影響 |
| **watcher_supervisor.sh** | 全エージェントの inbox_watcher を一括管理・自動再起動 | supervisor を止めると watcher が死んでも復活しなくなる |

### タスク・通知

| スクリプト | 役割 |
|-----------|------|
| **ntfy.sh** | ntfy 経由でスマホにプッシュ通知送信（Bearer token / Basic auth 対応） |
| **ntfy_listener.sh** | ntfy ストリーミングエンドポイントから受信 → inbox YAML に書き込み |
| **check_inbox_on_stop.sh** | Claude Code Stop Hook: 未読 inbox メッセージの確認 |

### ビルド・メンテナンス

| スクリプト | 役割 |
|-----------|------|
| **build_instructions.sh** | テンプレート（`instructions/templates/*.md.tmpl`）+ 共通パーツ（`instructions/common/*.md`）→ `instructions/generated/*.md` を生成 |
| **slim_yaml.sh** / **slim_yaml.py** | YAML ファイルの肥大化防止。古い read:true メッセージを圧縮 |
| **inbox_archive.sh** | inbox の read:true メッセージをアーカイブに退避 |
| **init_runtime_data.sh** | git pull 後に必要な運用データファイルを初期構造で生成（既存ファイルは上書きしない） |

### Agent Teams 関連（--agent-teams モード専用）

| スクリプト | 役割 |
|-----------|------|
| **bridge_relay.sh** | Agent Teams ↔ YAML 変換ブリッジ（down: Teams→YAML, up: YAML→Teams） |
| **fallback_to_tmux.sh** | Agent Teams → tmux フォールバック処理 |

### UI・表示

| スクリプト | 役割 |
|-----------|------|
| **statusline.sh** | tmux ステータスライン表示スクリプト（JSON stdin → ANSI 3行出力） |

### monitor/ サブディレクトリ

TypeScript 製のモニタリングツール群:

| ファイル | 役割 |
|---------|------|
| **start.ts** | モニタープロセスのエントリポイント |
| **lib/state_manager.ts** | エージェント状態の管理 |
| **lib/cost_tracker.ts** | API コスト追跡 |
| **hooks/** | Claude Code フック |
| **queue/** | キュー処理 |

## スクリプト修正時の共通ルール

1. **inbox_write.sh の flock を絶対に壊さない** — 排他ロックが並行書き込みの整合性を保証している。ロック取得・解放のロジックを変更する場合は、全エージェントが同時に書き込むシナリオでテストすること

2. **inbox_watcher.sh の send-keys タイミング** — テキスト送信と Enter 送信の間に 0.3 秒の gap がある。これは Claude Code の入力バッファ処理に必要。短縮するとコマンドが分断される

3. **build_instructions.sh の INCLUDE 構文** — テンプレート内の `{{INCLUDE:common/xxx.md}}` を展開する。新しい共通パーツを追加する場合は `instructions/common/` に配置し、テンプレートから参照する

4. **環境変数の依存** — 多くのスクリプトは tmux セッション内での実行を前提とし、`$TMUX_PANE` 等の環境変数に依存する。セッション外からの実行時は適切な引数指定が必要

5. **ShellCheck** — 可能であれば `shellcheck scripts/xxx.sh` でリントすること
