# T10: shogun バックポート コンテキスト

## 概要
multi-agent-shogun (v4.6.0) からインフラ機能を multi-agent-GuP-v2 にバックポートする。
機能のコピーではなく、GuP-v2 の構造（4隊制、24メンバー、CLUSTER_ID対応）に適合させること。

## ソースプロジェクト
- パス: /Users/take77.mac-mini/Developments/tools/multi-agent-shogun
- バージョン: v4.6.0 (2026-05-12 時点)
- 参照のみ。shogun 側のファイルは変更しない。

## ターゲットプロジェクト
- パス: /Users/take77.mac-mini/Developments/tools/multi-agent-GuP-v2
- ブランチ: feat/T10-shogun-backport

## GuP-v2 固有の注意点

### エージェント構成の違い
- shogun: 9 ashigaru + gunshi (10エージェント)
- GuP-v2: 4隊 × (captain + vice_captain + 5 members) = 28エージェント
- CANONICAL_MEMBERS は slim_yaml.py に定義済み（24名）

### 環境の違い
- shogun: Linux (inotifywait) + macOS (fswatch) 両対応
- GuP-v2: macOS 専用（darwin）でOK。inotifywait フォールバック不要
- GuP-v2: CLUSTER_ID 環境変数でマルチクラスタ対応（shogun にはない）

### 既存インフラの違い
- GuP-v2 の slim_yaml.py は shogun より高度（keep-last-N + backup + daily rollup）
- GuP-v2 の inbox_archive.sh / archive_coordination.py は shogun にない
- GuP-v2 の SessionStart hook は T9 で実装済み

## タスク一覧

### Phase 1（並行）
| ID | タスク | 担当隊 | shogun ソース | GuP-v2 ターゲット |
|----|--------|--------|---------------|-------------------|
| T10-1 | Stop Hook 自動報告 | Katyusha | scripts/stop_hook_inbox.sh (195行) | scripts/stop_hook_inbox.sh (新規) + .claude/settings.json 更新 |
| T10-3 | Dashboard Live Viewer | Kay | scripts/dashboard-viewer.py (323行) | scripts/dashboard-viewer.py (新規) |
| T10-4 | Auto Branch Merge | Darjeeling | scripts/auto_merge_short_lived.sh (151行) + lib/branch_policy.sh (136行) | scripts/ + lib/ + config/settings.yaml 追記 |

### Phase 2（Phase 1 完了後）
| ID | タスク | 担当隊 | shogun ソース | GuP-v2 ターゲット |
|----|--------|--------|---------------|-------------------|
| T10-5 | Pre-Deploy 検証 | Darjeeling | scripts/pre_deploy_verify.sh (49行) | scripts/pre_deploy_verify.sh (新規) |
| T10-6 | lib/ 整理 | Maho | (内部リファクタ) | lib/ 再構成 |

### Phase 3（全体依存）
| ID | タスク | 担当隊 | shogun ソース | GuP-v2 ターゲット |
|----|--------|--------|---------------|-------------------|
| T10-2 | Rate Limit モニタリング | Katyusha | scripts/ratelimit_check.sh (601行) | scripts/ratelimit_check.sh (新規) |
| T10-7 | テストインフラ拡充 | Maho | tests/ (100+ tests) | tests/ 拡充 |

## 共通ルール
- shogun のコードをそのままコピーしない。GuP-v2 の構造に適合させる
- エージェント名のハードコードは避け、config/squads.yaml から動的取得を推奨
- macOS (darwin) 専用で OK。Linux フォールバックは不要
- CLUSTER_ID 対応を維持（既存スクリプトとの整合性）
- .gitignore への追加を忘れないこと
