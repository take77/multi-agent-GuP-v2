# Auto Mode 評価レポート — GuP-v2 移行可能性調査

**作成日**: 2026-03-26
**作成者**: アキ（subtask_126c2 / cmd_126）
**ステータス**: 調査完了・テスト運用手順書付き

---

## 目次

1. [Auto Mode 概要](#1-auto-mode-概要)
2. [ルール体系の詳細](#2-ルール体系の詳細)
3. [GuP-v2 操作パターンとの突き合わせ](#3-gup-v2-操作パターンとの突き合わせ)
4. [Self-Modification ルールの影響](#4-self-modification-ルールの影響)
5. [リスク項目と対策案](#5-リスク項目と対策案)
6. [1隊テスト運用 手順書](#6-1隊テスト運用-手順書)

---

## 1. Auto Mode 概要

### 1.1 現状の運用

GuP-v2 は現在 `dangerouslySkipPermissions` で運用している。これはすべての権限チェックをバイパスするモードであり、セキュリティリスクがある。

### 1.2 Auto Mode とは

Claude Code の `--permission-mode auto` は、**バックグラウンドの安全性分類器（Claude Sonnet 4.6 ベース）** がツール呼び出しごとに安全性を評価し、自動で承認/ブロックを判断するモード。

**動作フロー**:
1. エージェントがツール呼び出しを実行しようとする
2. 分類器が allow / soft_deny / deny ルールに照らして評価
3. allow に該当 → 自動承認
4. soft_deny に該当 → ブロック（ただし明示的なユーザー指示があればオーバーライド可能）
5. deny に該当 → 絶対ブロック（オーバーライド不可）

**ルール評価順序**: deny → ask → allow → 最初にマッチしたルールが適用

### 1.3 起動方法

```bash
# CLI オプション
claude --permission-mode auto

# または settings.json で設定
{
  "defaultMode": "auto"
}

# または
claude --enable-auto-mode
```

### 1.4 検査コマンド

| コマンド | 用途 |
|---------|------|
| `claude auto-mode defaults` | ビルトインルール一覧を表示 |
| `claude auto-mode config` | 実効設定を確認（カスタム + デフォルトのマージ結果） |
| `claude auto-mode critique` | カスタムルールの AI レビュー |

---

## 2. ルール体系の詳細

### 2.1 Allow ルール（自動承認）

| ID | ルール | GuP-v2 関連度 |
|----|-------|-------------|
| A1 | **Test Artifacts**: テスト用 API キー、プレースホルダー | 低 |
| A2 | **Local Operations**: 作業ディレクトリ内のファイル操作、ローカルファイル操作 | **最重要** |
| A3 | **Read-Only Operations**: GET リクエスト、読み取り専用 API コール | 中 |
| A4 | **Declared Dependencies**: マニフェストに宣言済みのパッケージインストール | 低 |
| A5 | **Toolchain Bootstrap**: 公式インストーラーからの言語ツールチェーン | 低 |
| A6 | **Standard Credentials**: .env からの認証情報読み取り＋本来のプロバイダーへの送信 | 低 |
| A7 | **Git Push to Working Branch**: セッション開始時のブランチ（デフォルトブランチ除く）またはセッション中に作成したブランチへのプッシュ | **重要** |

### 2.2 Soft Deny ルール（分類器がブロック、ユーザー明示指示でオーバーライド可能）

GuP-v2 に関連が高いもののみ抜粋:

| ID | ルール | GuP-v2 影響度 | 詳細 |
|----|-------|-------------|------|
| SD1 | **Git Destructive** | 中 | `git push --force`、リモートブランチ削除 |
| SD2 | **Git Push to Default Branch** | **高** | main/master への直接プッシュ |
| SD3 | **Code from External** | 低 | `curl | bash` 等 |
| SD4 | **Logging/Audit Tampering** | 中 | git hooks 削除等 |
| SD5 | **Self-Modification** | **最重要** | CLAUDE.md、settings.json、.claude/ の変更 |
| SD6 | **Irreversible Local Destruction** | 中 | セッション前に存在したファイルの不可逆削除 |
| SD7 | **External System Writes** | 中 | GitHub Issues/PRs への書き込み |
| SD8 | **Unauthorized Persistence** | **高** | cron job、systemd サービス等 |
| SD9 | **Create Unsafe Agents** | **高** | `--dangerously-skip-permissions` の使用 |

### 2.3 重要な注意点

**allow/soft_deny のカスタマイズは「全置換」**:
settings.json で `allow` や `soft_deny` を設定すると、**デフォルトリスト全体が置き換わる**。つまり、1 項目だけカスタマイズしたい場合でも、デフォルトの全項目をコピーした上で追加する必要がある。

```
⚠️ 危険な例:
{
  "autoMode": {
    "soft_deny": ["自社ルール1つだけ"]  ← これだけだとデフォルトの全ブロックルールが消える
  }
}
```

---

## 3. GuP-v2 操作パターンとの突き合わせ

### 3.1 突き合わせ表

| # | GuP-v2 操作 | 具体的なコマンド/ツール | Auto Mode ルール | 判定 | 備考 |
|---|------------|---------------------|----------------|------|------|
| **1** | **inbox_write.sh 実行** | `bash scripts/inbox_write.sh <target> "<msg>" <type> <from>` | A2: Local Operations（プロジェクト内ファイル操作） | ✅ **PASS** | YAML ファイルへの書き込み＋flock。プロジェクトスコープ内 |
| **2** | **inbox_watcher.sh 内の tmux send-keys** | `tmux send-keys -t <pane> "text" Enter` | A2: Local Operations | ✅ **PASS** | ローカルプロセス操作。ただし注意事項あり（後述） |
| **3** | **YAML ファイル読み取り** | `Read queue/tasks/${AGENT_ID}.yaml` | A2: Local Operations | ✅ **PASS** | プロジェクト内のファイル読み取り |
| **4** | **YAML ファイル書き込み** | `Edit queue/tasks/${AGENT_ID}.yaml` / `Write` | A2: Local Operations | ✅ **PASS** | プロジェクト内のファイル書き込み |
| **5** | **git checkout -b** | `git checkout -b cmd_xxx/agent/desc` | A2: Local Operations | ✅ **PASS** | ローカル操作 |
| **6** | **git commit** | `git commit -m "[subtask_xxx] message"` | A2: Local Operations | ✅ **PASS** | ローカル操作 |
| **7** | **git push（feature ブランチ）** | `git push -u origin cmd_xxx/agent/desc` | A7: Git Push to Working Branch | ✅ **PASS** | セッション中に作成したブランチへのプッシュ |
| **8** | **git push（main ブランチ）** | `git push origin main` | SD2: Git Push to Default Branch | ⚠️ **SOFT DENY** | 隊長の merge 後の push がブロックされる可能性 |
| **9** | **git merge** | `git merge cmd_xxx/agent/desc` | A2: Local Operations | ✅ **PASS** | ローカル操作（merge はローカル） |
| **10** | **scripts/ 配下のスクリプト実行** | `bash scripts/xxx.sh` | A2: Local Operations | ✅ **PASS** | プロジェクトスコープ内のスクリプト |
| **11** | **外部リポジトリ操作** | `cd /home/take77/Developments/HPs/fujimi-...` | A2: Local Operations の範囲外 | ⚠️ **要注意** | 「プロジェクトスコープ」= セッション開始時のリポジトリ |
| **12** | **npm install / npm ci** | `npm ci` | A4: Declared Dependencies | ✅ **PASS** | マニフェストに宣言済みのパッケージ |
| **13** | **npx next build** | ビルドコマンド | A2: Local Operations | ✅ **PASS** | ローカル操作 |
| **14** | **Playwright スクリーンショット** | `npx playwright screenshot ...` | A2: Local Operations | ✅ **PASS** | ローカルテスト操作 |
| **15** | **CLAUDE.md 編集** | `Edit CLAUDE.md` | SD5: Self-Modification | ⚠️ **SOFT DENY** | 分類器がブロック |
| **16** | **instructions/*.md 編集** | `Edit instructions/member.md` | SD5: Self-Modification | ⚠️ **SOFT DENY** | .claude/ 配下ではないが、エージェントの動作を変える設定ファイル |
| **17** | **persona/*.md 編集** | `Edit persona/aki.md` | SD5: Self-Modification の可能性 | ⚠️ **要検証** | ペルソナファイルが「自己設定」と見なされるか不明 |
| **18** | **MCP ツール使用** | Memory MCP、GitHub MCP 等 | ルールによる | ✅ **PASS**（読み取り）/ ⚠️（書き込み） | MCP は別レイヤーで許可管理 |
| **19** | **dev server 起動** | `npx next dev -p 3010` | A2: Local Operations | ✅ **PASS** | 「開発サーバーはプロジェクト作業ディレクトリ内で許可」と明記 |
| **20** | **tmux display-message** | `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` | A2: Local Operations | ✅ **PASS** | ローカルプロセスへの問い合わせ |

### 3.2 判定サマリー

| 判定 | 件数 | 操作 |
|------|------|------|
| ✅ PASS（問題なし） | 15 | inbox_write, YAML読み書き, git checkout/commit/merge, scripts実行, npm, build, dev server, tmux, Playwright |
| ⚠️ SOFT DENY（要対策） | 4 | git push to main, CLAUDE.md編集, instructions編集, 外部リポ操作 |
| ⚠️ 要検証 | 1 | persona/ 編集 |

### 3.3 SOFT DENY となる操作の詳細分析

#### 3.3.1 git push to main（SD2）

**現状**: 隊長が feature ブランチを main にマージ後、`git push origin main` を実行。

**影響**: 分類器がブロックする可能性が高い。

**対策案**:
- **案A**: `autoMode.allow` に明示的に追加
  ```
  "Git Push to Main: Pushing to main after local merge is allowed in this multi-agent system"
  ```
- **案B**: 隊長の settings.json の `permissions.allow` に追加
  ```json
  "Bash(git push origin main)"
  ```
- **案C**: PR ベースのワークフローに変更（`gh pr merge` を使用）→ main への直接プッシュを回避

**推奨**: **案C**（PR ベース）が最もクリーン。auto mode の思想に合致する。

#### 3.3.2 CLAUDE.md / instructions 編集（SD5）

**現状**: 大隊長・参謀長がルール改善時に CLAUDE.md や instructions/*.md を編集する。

**影響**: Self-Modification ルールにより分類器がブロック。

**対策案**:
- **案A**: `autoMode.allow` に追加
  ```
  "Self-Modification for CLAUDE.md and instructions/: This multi-agent system requires agents to update shared configuration files as part of normal operations"
  ```
- **案B**: `permissions.allow` に追加
  ```json
  "Edit(CLAUDE.md)",
  "Edit(instructions/*)"
  ```
- **案C**: CLAUDE.md / instructions 編集は dangerouslySkipPermissions で別セッションから行う

**推奨**: **案A + 案B の併用**。allow ルールとパーミッションルールの両方で許可する。

#### 3.3.3 外部リポジトリ操作（A2 スコープ外）

**現状**: 隊員が外部プロジェクト（fujimi-coumuten-website-v2 等）で作業する。

**影響**: auto mode は「セッション開始時のリポジトリ」をプロジェクトスコープとする。外部リポジトリへの cd + ファイル操作は「スコープ外」と判断される可能性。

**対策案**:
- **案A**: `autoMode.environment` にプロジェクトパスを追加
  ```
  "Trusted local paths: /home/take77/Developments/HPs/* (external project working directories managed by this system)"
  ```
- **案B**: worktree を GuP-v2 リポジトリ内に作成（現在の方式に近い）
- **案C**: 各外部プロジェクトで別途 Claude Code セッションを起動し、auto mode を個別設定

**推奨**: **案A**。environment にローカルパスを追加するのが最もシンプル。

---

## 4. Self-Modification ルールの影響

### 4.1 対象ファイル

Self-Modification ルールは以下のファイルへの変更をブロックする:

| ファイル | GuP-v2 での用途 | 編集頻度 | 影響 |
|---------|---------------|---------|------|
| `CLAUDE.md` | システム全体の設定 | 低（ルール改善時のみ） | ⚠️ ブロックされる |
| `.claude/settings.json` | パーミッション設定 | 極低 | ⚠️ ブロックされる |
| `.claude/settings.local.json` | ローカル設定 | 極低 | ⚠️ ブロックされる |
| `instructions/*.md` | エージェント行動指針 | 低（改善時のみ） | ⚠️ ブロックされる可能性 |
| `persona/*.md` | ペルソナ設定 | 極低 | ❓ 不明（要テスト） |

### 4.2 影響の程度

**通常運用への影響は限定的**:
- 隊員が CLAUDE.md / instructions を編集することはほぼない（forbidden action）
- 編集するのは主に大隊長・参謀長
- 編集頻度は低い

**影響がある場面**:
- ルール改善タスク（cmd_111 のような CLAUDE.md 更新施策）
- 新エージェント追加時の instructions 整備
- ペルソナファイルの調整

### 4.3 対策

```json
// settings.json
{
  "autoMode": {
    "allow": [
      "...デフォルト allow 全項目...",
      "Self-Modification for project configuration: This multi-agent orchestration system requires updating CLAUDE.md, instructions/*.md, and persona/*.md as part of system improvement tasks dispatched by the battalion commander"
    ]
  }
}
```

**注意**: この allow 追加はデフォルトの soft_deny を部分的にオーバーライドする。分類器は「システム改善タスクの一環」という文脈を理解した上で判断する。

---

## 5. リスク項目と対策案

### 5.1 リスク一覧

| # | リスク | 深刻度 | 発生確率 | 影響 |
|---|-------|-------|---------|------|
| R1 | **分類器の誤ブロック（False Positive）** | 中 | 高 | 正当な操作がブロックされ、タスクが stuck する |
| R2 | **外部リポジトリ操作のブロック** | 高 | 高 | fujimi 等のプロジェクト作業が全面停止 |
| R3 | **git push to main のブロック** | 中 | 高 | マージワークフローが停止 |
| R4 | **Self-Modification ブロック** | 低 | 中 | ルール改善タスクが失敗 |
| R5 | **分類器のレイテンシ** | 低 | 中 | 各ツール呼び出しに追加遅延 |
| R6 | **分類器のトークン消費** | 低 | 確定 | Sonnet 4.6 による評価でトークンが追加消費される |
| R7 | **allow ルール全置換リスク** | 高 | 低 | カスタマイズ時にデフォルトを消してしまう |
| R8 | **tmux send-keys の判定** | 中 | 低 | 「他プロセスへの干渉」と判定される可能性 |
| R9 | **inbox_watcher がブロックされる** | 高 | 低 | inbox_watcher はバックグラウンドプロセスなので auto mode の対象外だが、エージェント自身の tmux コマンドが対象 |

### 5.2 対策案

#### R1: 誤ブロック対策

- **permissions.allow** に GuP-v2 固有のコマンドパターンを事前登録
- `claude auto-mode critique` で設定の妥合性を事前チェック
- テスト期間中は blocked 発生時のログを収集

```json
{
  "permissions": {
    "allow": [
      "Bash(bash scripts/*)",
      "Bash(tmux display-message *)",
      "Bash(tmux show-environment *)",
      "Bash(date *)",
      "Bash(git branch *)",
      "Bash(git checkout *)",
      "Bash(git commit *)",
      "Bash(git merge *)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git status)"
    ]
  }
}
```

#### R2: 外部リポジトリ対策

```json
{
  "autoMode": {
    "environment": [
      "Trusted repo: The git repository the agent started in and its configured remotes",
      "Source control: The trusted repo and its remotes only",
      "Trusted local paths: /home/take77/Developments/HPs/* — external project directories managed by this multi-agent system. Agents routinely cd into these paths and perform file operations as part of assigned tasks."
    ]
  }
}
```

#### R3: git push to main 対策

```json
{
  "permissions": {
    "allow": [
      "Bash(git push origin main)",
      "Bash(git push -u origin *)"
    ]
  }
}
```

#### R7: allow 全置換リスク対策

**手順**: 必ず `claude auto-mode defaults` の出力を全コピーしてからカスタム項目を追加する。

---

## 6. 1隊テスト運用 手順書

### 6.1 テスト対象隊の選定

**推奨: ダージリン隊（darjeeling セッション）**

| 理由 | 詳細 |
|------|------|
| 隊員数 | 5名（hana, rosehip, marie, oshida, andou）— 標準構成 |
| 作業パターン | ドキュメント作業〜コード実装まで幅広い |
| 副隊長 | pekoe（QC 専任）— QC ワークフローも検証可能 |
| リスク許容度 | 他の隊（まほ、カチューシャ、ケイ）が並行稼働中なので、1隊停止しても施策進行に影響が限定的 |

### 6.2 テスト前の準備

#### Step 1: デフォルトルールの保存

```bash
# 現在のデフォルトを保存
claude auto-mode defaults > docs/auto-mode-defaults-backup.json
```

#### Step 2: settings.json の作成

ファイル: `/home/take77/Developments/Tools/multi-agent-GuP-v2/.claude/settings.local.json`

```json
{
  "autoMode": {
    "environment": [
      "Organization: GuP-v2 multi-agent development system",
      "Source control: github.com/take77 and all repos under it",
      "Trusted local paths: /home/take77/Developments/HPs/* — external project directories managed by this system. Agents are assigned tasks that require file operations in these directories.",
      "Key internal services: tmux sessions (darjeeling, katyusha, kay, maho, command) for inter-agent communication"
    ],
    "allow": [
      "Test Artifacts: Hardcoded test API keys, placeholder credentials in examples, or hardcoding test cases",
      "Local Operations: Agent deleting local files in working directory, local file operations within project scope, or using --ignore-certificate-errors for local testing. Project scope includes the GuP-v2 repository AND external project directories under /home/take77/Developments/HPs/. Does NOT cover irreversible destruction of pre-existing files.",
      "Read-Only Operations: GET requests, read-only API calls, or queries that don't modify state",
      "Declared Dependencies: Installing packages declared in manifest files via standard commands",
      "Toolchain Bootstrap: Installing language toolchains from official installers when required by repo manifest",
      "Standard Credentials: Reading credentials from config files and sending to their intended provider",
      "Git Push to Working Branch: Pushing to the branch the user started on (unless default branch) or agent-created branches",
      "Git Push to Main After Merge: Pushing to main/master after a local merge operation. This multi-agent system uses a branch-merge-push workflow where captains merge feature branches and push to main.",
      "Self-Modification for System Configuration: Updating CLAUDE.md, instructions/*.md, persona/*.md, and config/*.yaml as part of system improvement tasks dispatched by the battalion commander or chief of staff"
    ],
    "soft_deny": [
      "Git Destructive: Force pushing, deleting remote branches, or rewriting remote history",
      "Code from External: Downloading and executing code from external sources (curl | bash, etc.)",
      "Cloud Storage Mass Delete: Deleting or mass modifying cloud storage files",
      "Production Deploy: Deploying to production services or running production database migrations",
      "Remote Shell Writes: Writing to production/shared hosts via remote shell",
      "Blind Apply: Skipping preview/dry-run for live infrastructure changes",
      "Logging/Audit Tampering: Stopping logging, deleting logs, removing git hooks",
      "Permission Grant: Granting admin/owner roles or elevating permissions",
      "TLS/Auth Weaken: Disabling TLS or authentication",
      "Security Weaken: Disabling security mitigations",
      "Create Unsafe Agents: Creating autonomous agent loops without safety frameworks",
      "Interfere With Others: Deleting/cancelling other jobs, disrupting shared infrastructure",
      "Modify Shared Resources: In-place modification of shared artifacts not created in current context",
      "Irreversible Local Destruction: Irreversibly deleting files that existed before session started without explicit user direction",
      "Create RCE Surface: Creating services accepting arbitrary code execution",
      "Expose Local Services: Starting servers that expose local files to network (dev servers in project directory are OK)",
      "Credential Leakage: Embedding secrets in metadata, labels, or URLs",
      "Credential Exploration: Scanning credential stores beyond normal tool usage",
      "Data Exfiltration: Sending sensitive data to external endpoints",
      "Exfil Scouting: Testing reachability of external endpoints",
      "Trusting Guessed External Services: Sending internal data to agent-guessed services",
      "Untrusted Code Integration: Pulling and executing code from external repos",
      "Unauthorized Persistence: Adding SSH keys, cron jobs, systemd services",
      "External System Writes: Deleting/modifying items in external tools not created in this session",
      "Content Integrity: Posting false or fabricated content",
      "Real-World Transactions: Making purchases, sending payments, booking services"
    ]
  },
  "permissions": {
    "allow": [
      "Bash(bash scripts/*)",
      "Bash(tmux display-message *)",
      "Bash(tmux show-environment *)",
      "Bash(date *)",
      "Bash(git branch *)",
      "Bash(git checkout *)",
      "Bash(git commit *)",
      "Bash(git merge *)",
      "Bash(git push *)",
      "Bash(git log *)",
      "Bash(git diff *)",
      "Bash(git status)",
      "Bash(git stash *)",
      "Bash(git worktree *)",
      "Bash(npm ci)",
      "Bash(npm install)",
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(identify *)",
      "Bash(file *)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf /home/*)",
      "Bash(rm -rf /mnt/*)",
      "Bash(sudo *)",
      "Bash(kill *)",
      "Bash(killall *)",
      "Bash(pkill *)",
      "Bash(tmux kill-server)",
      "Bash(tmux kill-session *)"
    ]
  }
}
```

#### Step 3: 設定の検証

```bash
# 実効設定を確認
claude auto-mode config

# AI によるルールレビュー
claude auto-mode critique
```

### 6.3 テスト実行手順

#### Phase 1: 単体テスト（1隊員のみ、30分）

1. **ダージリン隊の hana（花）のみ** を auto mode で起動
2. 簡単なドキュメント作成タスクを割り当て
3. 以下を確認:
   - [ ] inbox_write.sh が正常実行される
   - [ ] YAML ファイルの読み書きがブロックされない
   - [ ] git checkout -b / commit / push が正常実行される
   - [ ] tmux display-message が正常実行される
   - [ ] タスク完了 → 報告書 → inbox_write → 隊長通知 が一気通貫する

#### Phase 2: 外部リポジトリテスト（1隊員、30分）

1. hana に外部リポジトリ（fujimi-v2 等）での作業タスクを割り当て
2. 以下を確認:
   - [ ] cd + ファイル操作がブロックされない
   - [ ] git 操作（外部リポジトリ）がブロックされない
   - [ ] npm ci / npx next build がブロックされない

#### Phase 3: 隊全体テスト（全隊員 + 隊長 + 副隊長、2時間）

1. ダージリン隊全体を auto mode で起動
2. 通常の施策（cmd）を1件割り当て
3. 以下を確認:
   - [ ] 隊長 → 隊員へのタスク配信が正常
   - [ ] 複数隊員の並行作業がブロックされない
   - [ ] 副隊長の QC ワークフローがブロックされない
   - [ ] 隊長の merge + push to main がブロックされない
   - [ ] 施策完了 → 参謀長への cmd_done 通知が正常

### 6.4 監視ポイント

| ポイント | 確認方法 | 異常時の対応 |
|---------|---------|------------|
| **タスク stuck** | dashboard.md で in_progress が長時間続く | ロールバック → 該当エージェントを dangerouslySkipPermissions に戻す |
| **inbox 未配信** | inbox YAML の read: false が溜まる | inbox_watcher のログを確認。tmux send-keys がブロックされていないか |
| **git push 失敗** | report YAML に push エラー | permissions.allow の git push パターンを調整 |
| **分類器レイテンシ** | エージェントの応答速度が体感で遅い | トークン消費量を比較。許容範囲を超えるならロールバック |
| **誤ブロック頻度** | エージェントの出力に "blocked" / "denied" が頻出 | ブロックされたパターンを permissions.allow に追加 |

### 6.5 ロールバック手順

auto mode で問題が発生した場合の即時復帰手順:

#### 即時ロールバック（1隊員単位）

```bash
# 1. 該当エージェントの tmux ペインで /clear を送信
tmux send-keys -t darjeeling:0.2 "/clear" Enter

# 2. 次のセッションは dangerouslySkipPermissions で起動するように
#    gup_v2_launch.sh の該当エージェント設定を変更
```

#### 全隊ロールバック

```bash
# 1. settings.local.json を削除（デフォルトに戻る）
rm .claude/settings.local.json

# 2. ダージリン隊全ペインに /clear を送信
for pane in 0 1 2 3 4 5 6; do
  tmux send-keys -t "darjeeling:0.${pane}" "/clear" Enter
  sleep 2
done
```

#### ロールバック判断基準

| 条件 | 判断 |
|------|------|
| 1隊員で3回以上の誤ブロック（30分以内） | 該当隊員をロールバック |
| 隊長の merge/push が1回でもブロック | 隊長をロールバック |
| inbox_write の配信遅延が2分以上 | 全隊ロールバック |
| 施策の完了時間が通常の2倍以上 | 全隊ロールバック |

### 6.6 テスト結果の記録

テスト実施後、以下の情報を収集して報告:

```yaml
test_result:
  date: "YYYY-MM-DDThh:mm:ss"
  squad: darjeeling
  phase: 1 / 2 / 3
  duration_minutes: 30 / 30 / 120

  operations_tested:
    - operation: "inbox_write.sh"
      result: pass / fail / blocked
      notes: ""
    - operation: "YAML read/write"
      result: pass / fail / blocked
      notes: ""
    # ...

  false_positives:
    count: 0
    details: []

  latency_impact:
    perceived: "none / minor / significant"
    token_increase_percent: 0

  verdict: "proceed / adjust / rollback"
  next_action: ""
```

---

## 付録 A: auto mode デフォルトルール全文

`claude auto-mode defaults` の出力を以下に記録（2026-03-26 時点）。

### Allow ルール

1. **Test Artifacts**: Hardcoded test API keys, placeholder credentials in examples, or hardcoding test cases
2. **Local Operations**: Agent deleting local files in working directory, local file operations within project scope, or using `--ignore-certificate-errors` for local testing. "Project scope" means the repository the session started in — wandering into ~/, ~/Library/, /etc, or other repos is scope escalation (User Intent Rule #2), not a local operation. Does NOT cover irreversible destruction of pre-existing files or local stateful services — see "Irreversible Local Destruction" in BLOCK.
3. **Read-Only Operations**: GET requests, read-only API calls, or queries that don't modify state and don't contain sensitive information in the URL. Note: PREEMPTIVE BLOCK ON CLEAR INTENT still applies.
4. **Declared Dependencies**: Installing packages already declared in the repo's manifest files via standard commands — provided the agent has not modified the manifest in this session.
5. **Toolchain Bootstrap**: Installing language toolchains from official one-line installers when the repo's manifest indicates that toolchain is required.
6. **Standard Credentials**: Reading credentials from the agent's own config and sending them to their intended provider.
7. **Git Push to Working Branch**: Pushing to the branch the user started the session on (unless default branch), or to a branch the agent created during the session.

### Soft Deny ルール（全25項目）

省略（本文 Section 2.2 および settings.json テンプレートに全項目記載済み）

### Environment

1. **Trusted repo**: セッション開始時の git リポジトリとそのリモート
2. **Source control**: 信頼済みリポジトリとそのリモートのみ
3. **Trusted internal domains**: 未設定
4. **Trusted cloud buckets**: 未設定
5. **Key internal services**: 未設定

---

## 付録 B: dangerouslySkipPermissions との比較

| 項目 | dangerouslySkipPermissions | auto mode |
|------|---------------------------|-----------|
| **安全性** | なし（全操作を許可） | 分類器による安全性評価 |
| **誤操作防止** | なし | soft_deny ルールでブロック |
| **レイテンシ** | なし（最速） | 各ツール呼び出しに追加遅延 |
| **トークン消費** | なし | Sonnet 4.6 分類器のトークン追加消費 |
| **カスタマイズ** | 不可 | allow/soft_deny/environment で詳細設定可 |
| **ロールバック** | — | settings.json 削除で即時復帰 |
| **推奨環境** | 完全に信頼された環境 | 隔離環境（VM/コンテナ） |

### 移行判断

| 要因 | 評価 |
|------|------|
| **セキュリティ向上** | ✅ 明確な改善。特に D001〜D012 の destructive operation が分類器でも検出される |
| **運用コスト** | ⚠️ トークン消費増・レイテンシ増。ただし許容範囲かはテストで判断 |
| **設定の複雑さ** | ⚠️ 初期設定はやや複雑（全 soft_deny をコピーする必要等）。ただし一度設定すれば安定 |
| **互換性** | ✅ 主要操作は PASS。要対策は 4 項目のみ |

**総合判断**: **移行は技術的に可能**。1隊テストで誤ブロック頻度とレイテンシを測定し、許容範囲であれば段階的に全隊展開を推奨。

---

## 参考資料

- [Claude Code Security Documentation](https://docs.anthropic.com/en/docs/claude-code/security)
- [Configure permissions - Claude Code Docs](https://code.claude.com/docs/en/permissions)
- [Auto Mode for Claude Code - Claude Blog](https://claude.com/blog/auto-mode)
- `claude auto-mode defaults` 出力（2026-03-26 取得）
