# Claude Code Skills Install Guide

## Quick Install（推奨3件のみ）

```bash
# 1. playwright-skill — Design QCスクショ自動化
/plugin marketplace add lackeyjb/playwright-skill
/plugin install playwright-skill@playwright-skill
cd ~/.claude/plugins/marketplaces/playwright-skill/skills/playwright-skill && npm run setup

# 2. frontend-design — Anthropic公式、組み込み済み。インストール不要。

# 3. claude-reflect — セッション振り返り・学習蓄積
claude plugin marketplace add bayramannakov/claude-reflect
claude plugin install claude-reflect@claude-reflect-marketplace

# 4. claude-health — 設定ヘルスチェック
npx skills add tw93/claude-health -a claude-code -s health -g -y

# ★ 全インストール後、Claude Code を再起動
```

## 確認チェックリスト

- [ ] playwright-skill: テストスクショが撮れる
- [ ] frontend-design: 組み込み済み確認（デザイン系の依頼で自動発動）
- [ ] claude-reflect: `/reflect` コマンドが動作する
- [ ] claude-health: `/health` コマンドが動作する

---

## 各スキル詳細

### 1. playwright-skill（即入れ）
- **Repo**: https://github.com/lackeyjb/playwright-skill
- **用途**: ブラウザ操作、スクショ撮影、E2Eテスト、フォーム入力
- **GuP-v2での活用**: 移行タスクQCルール3（スクショ証跡）の自動化
- **注意**: tmux環境ではheadlessモード使用

```bash
# Option A: Plugin marketplace
/plugin marketplace add lackeyjb/playwright-skill
/plugin install playwright-skill@playwright-skill
cd ~/.claude/plugins/marketplaces/playwright-skill/skills/playwright-skill
npm run setup

# Option B: Manual install
git clone https://github.com/lackeyjb/playwright-skill.git /tmp/playwright-skill-temp
mkdir -p ~/.claude/skills
cp -r /tmp/playwright-skill-temp/skills/playwright-skill ~/.claude/skills/
cd ~/.claude/skills/playwright-skill
npm run setup
rm -rf /tmp/playwright-skill-temp
```

### 2. frontend-design（組み込み済み）
- **Repo**: https://github.com/anthropics/claude-code （公式プラグイン内）
- **用途**: UI品質向上、カラーパレット、タイポグラフィ、スペーシング
- **注意**: 移行タスク（v1踏襲）では使わない。新規デザイン・プロトタイプのみ。

### 3. claude-reflect（即入れ）
- **Repo**: https://github.com/BayramAnnakov/claude-reflect
- **用途**: セッション終了時に rules/skills/memory への追加提案を自動生成
- **GuP-v2での活用**: 大隊長（杏）ペインでの使用を推奨。全隊は要検討。

```bash
claude plugin marketplace add bayramannakov/claude-reflect
claude plugin install claude-reflect@claude-reflect-marketplace
```

### 4. claude-health（即入れ）
- **Repo**: https://github.com/tw93/claude-health
- **用途**: CLAUDE.md、settings.json、スキル構成の6層診断
- **GuP-v2での活用**: 30名規模のエージェント設定の整合性チェック

```bash
npx skills add tw93/claude-health -a claude-code -s health -g -y
```

---

## 保留・スキップ

### superpowers（保留）
- **Repo**: https://github.com/obra/superpowers（⭐112K）
- **理由**: 20+スキルのバンドルでワークフロー全体を変更する。GuP-v2のYAML/inboxタスク管理と競合リスク。
- **判断**: 隔離環境でテスト後に再検討

### planning-with-files（スキップ）
- **理由**: GuP-v2の既存YAMLタスク管理と完全に冗長

### humanizer-ja（スキップ）
- **理由**: 日本語版は存在しない（英語版のみ）。将来のカスタム開発候補。

### trailofbits/skills（保留）
- **Repo**: https://github.com/trailofbits/skills（⭐3.9K）
- **理由**: HP案件では不要。Webアプリセキュリティ監査時に再検討。
