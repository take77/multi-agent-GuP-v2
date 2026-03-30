# Instructions ディレクトリ ガイド

このディレクトリはエージェントの指示書を管理するテンプレートシステムを格納している。

## テンプレートシステム概要

```
instructions/
├── templates/          # テンプレートファイル（*.md.tmpl）— 編集はここ
│   ├── battalion_commander.md.tmpl
│   ├── captain.md.tmpl
│   ├── chief_of_staff.md.tmpl
│   ├── member.md.tmpl
│   └── vice_captain.md.tmpl
├── common/             # 共通セクション（テンプレートから {{INCLUDE:}} で参照）
│   ├── forbidden_actions.md
│   ├── language.md
│   ├── migration_task_rules.md
│   ├── protocol.md
│   ├── report_format_v2.md
│   ├── self_identification.md
│   ├── task_flow.md
│   └── timestamp.md
├── generated/          # 自動生成された指示書（手動編集禁止）
│   ├── battalion_commander.md
│   ├── captain.md
│   ├── chief_of_staff.md
│   ├── member.md
│   ├── vice_captain.md
│   └── {cli}-{role}.md  # CLI別バリアント（codex, copilot, kimi）
└── roles/              # CLI バリアント用ロール定義（Phase 2 用）
```

## ビルドコマンド

```bash
bash scripts/build_instructions.sh
```

このスクリプトは4フェーズで動作する:

1. **Phase 1: テンプレートベース生成** — `templates/*.md.tmpl` → `generated/{role}.md`
2. **Phase 2: CLI バリアント生成** — `roles/` + `common/` → `generated/{cli}-{role}.md`
3. **Phase 3: CLI 自動読み込みファイル** — CLAUDE.md → AGENTS.md, copilot-instructions.md 等
4. **Phase 4: Drift 検知** — `generated/` と既存ファイルの差分チェック

## テンプレート変数

テンプレートファイル（`.md.tmpl`）で使用できるマーカー:

| マーカー | 説明 | 例 |
|---------|------|-----|
| `{{INCLUDE:common/xxx.md}}` | 共通セクションの埋め込み | `{{INCLUDE:common/protocol.md}}` |

`{{INCLUDE:}}` は `instructions/` からの相対パスで解決される。
ネストは1階層までサポート。

## Drift 検知

`generated/` 内のファイルを手動編集すると、次回の `build_instructions.sh` 実行で上書きされる。

- `build_instructions.sh` は Phase 4 で `instructions/{role}.md`（もし存在すれば）と `generated/{role}.md` を比較
- 差分があれば `⚠️ DRIFT` 警告を出力し、exit 1 で終了
- drift が検出された場合: テンプレート（`templates/`）か共通セクション（`common/`）を修正して再ビルド

## テンプレート修正の手順

1. `templates/{role}.md.tmpl` または `common/{section}.md` を編集
2. `bash scripts/build_instructions.sh` を実行
3. `generated/{role}.md` の内容を確認
4. 変更をコミット（テンプレート + generated 両方）

**注意**: `generated/` のファイルだけを編集してはならない。次回ビルドで上書きされる。
