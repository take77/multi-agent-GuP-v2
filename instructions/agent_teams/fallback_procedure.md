# Agent Teams フォールバック手順書

Agent Teams モード（WebSocket通信）から従来の tmux 直接通信モードへのフォールバック手順を記載します。

---

## 1. 自動フォールバック

参謀長プロセスが異常を検知した場合、自動的にフォールバックが実行されます。

### 1.1. 検知トリガー

- WebSocket接続の切断検出
- タスク配信失敗の連続発生
- Agent Teams API の応答タイムアウト

### 1.2. 自動フォールバックフロー

1. 参謀長プロセスが異常を検知
2. 参謀長が `queue/hq/session_state.yaml` に異常ステータスを記録
3. 参謀長が大隊長（command セッション）に通知
4. 大隊長が `scripts/fallback_to_tmux.sh` を実行
5. 各隊長に inbox_write.sh 経由でフォールバック通知を送信

### 1.3. 完了条件

- 全隊長セッションの `GUP_BRIDGE_MODE` が `0` に設定される
- `queue/hq/session_state.yaml` の `agent_teams_active` が `false` になる

---

## 2. 手動フォールバック

大隊長または運用者が手動でフォールバックを実行する場合の手順です。

### 2.1. 実行手順

1. **フォールバックスクリプトの実行**
   ```bash
   bash scripts/fallback_to_tmux.sh
   ```

2. **実行内容の確認**
   - スクリプトは以下の処理を自動実行します：
     - 各隊長セッション（darjeeling, katyusha, kay, maho）の `GUP_BRIDGE_MODE` を `0` に設定
     - command セッションの `GUP_AGENT_TEAMS_ACTIVE` を `0` に設定
     - command セッションの `CLAUDE_CODE_TASK_LIST_ID` を削除
     - `queue/hq/session_state.yaml` の `agent_teams_active` を `false` に更新
     - 各隊長に inbox_write.sh 経由でフォールバック通知を送信

3. **完了メッセージの確認**
   ```
   ✅ Agent Teams → tmux フォールバック完了
   ```

### 2.2. フォールバック後の確認項目

- [ ] `tmux showenv -t darjeeling GUP_BRIDGE_MODE` が `0` を返すこと
- [ ] `tmux showenv -t command GUP_AGENT_TEAMS_ACTIVE` が `0` を返すこと
- [ ] `queue/hq/session_state.yaml` の `agent_teams_active` が `false` であること

---

## 3. 作業層への影響

### 3.1. 影響範囲

**影響なし** — Phase 0 の仕組みにより、作業層（各隊員）は安定動作を継続します。

### 3.2. 理由

- 作業層は `inbox_write.sh` + `inbox_watcher.sh` で動作（Phase 0 実装）
- 通信層の切替（WebSocket ⇔ tmux）は作業層から完全に分離されている
- 隊長の通信モード切替は作業層の inbox 配信に影響しない

### 3.3. 作業継続性の保証

- フォールバック中も inbox への配信は継続
- 隊長が従来モードに切り替わっても、inbox_watcher.sh は変わらず動作
- 作業中のタスクは中断されない

---

## 4. 参謀長プロセス再起動手順

参謀長プロセスが停止した場合、`queue/hq/session_state.yaml` から状態を復元して再起動します。

### 4.1. 再起動手順

1. **session_state.yaml の確認**
   ```bash
   cat queue/hq/session_state.yaml
   ```
   - `agent_teams_active: true/false` を確認

2. **参謀長プロセスの再起動**
   ```bash
   # Agent Teams モードで再起動する場合
   # （session_state.yaml で agent_teams_active: true の場合）
   npm run chief-of-staff -- --restore
   ```

3. **状態復元の確認**
   - 参謀長が `session_state.yaml` から以下を復元：
     - `agent_teams_active` ステータス
     - 最終タスクID
     - セッションタイムスタンプ

4. **動作確認**
   - 参謀長のログ出力を確認
   - タスク配信が正常に動作することを確認

### 4.2. 復元失敗時の対処

- `session_state.yaml` が破損している場合：
  1. バックアップから復元（存在する場合）
  2. または新規初期化（`npm run chief-of-staff -- --init`）

---

## 5. Agent Teams 再起動手順

Agent Teams モードを再度有効化する手順です。

### 5.1. 再起動手順

1. **前提条件の確認**
   - [ ] 参謀長プロセスが正常に動作していること
   - [ ] WebSocket 通信が利用可能であること
   - [ ] `queue/hq/session_state.yaml` が存在すること

2. **Agent Teams モードで再起動**
   ```bash
   npm run chief-of-staff -- --agent-teams
   ```

3. **設定の自動更新**
   - 参謀長が以下を自動実行：
     - 各隊長セッションの `GUP_BRIDGE_MODE` を `1` に設定
     - command セッションの `GUP_AGENT_TEAMS_ACTIVE` を `1` に設定
     - `queue/hq/session_state.yaml` の `agent_teams_active` を `true` に更新

4. **動作確認**
   ```bash
   tmux showenv -t darjeeling GUP_BRIDGE_MODE  # 1 を返すこと
   tmux showenv -t command GUP_AGENT_TEAMS_ACTIVE  # 1 を返すこと
   cat queue/hq/session_state.yaml  # agent_teams_active: true であること
   ```

### 5.2. 再起動失敗時の対処

- WebSocket 接続エラーが発生した場合：
  1. ネットワーク接続を確認
  2. Claude API の状態を確認
  3. 自動フォールバックが作動し、tmux モードに戻る

- 設定更新エラーが発生した場合：
  1. `scripts/fallback_to_tmux.sh` を実行して一度クリーンな状態に戻す
  2. 再度 `--agent-teams` フラグで再起動

---

## 6. トラブルシューティング

### 6.1. フォールバックが完了しない

**症状**: `scripts/fallback_to_tmux.sh` 実行後も `GUP_BRIDGE_MODE` が `1` のまま

**対処**:
```bash
# 手動で各セッションに設定
tmux setenv -t darjeeling GUP_BRIDGE_MODE 0
tmux setenv -t katyusha GUP_BRIDGE_MODE 0
tmux setenv -t kay GUP_BRIDGE_MODE 0
tmux setenv -t maho GUP_BRIDGE_MODE 0
tmux setenv -t command GUP_AGENT_TEAMS_ACTIVE 0
```

### 6.2. session_state.yaml が更新されない

**症状**: フォールバック後も `agent_teams_active: true` のまま

**対処**:
```bash
# yq がインストールされている場合
yq eval '.agent_teams_active = false' -i queue/hq/session_state.yaml

# yq がない場合
sed -i 's/agent_teams_active: true/agent_teams_active: false/' queue/hq/session_state.yaml
```

### 6.3. 作業層がタスクを受信しない

**症状**: フォールバック後、隊員が inbox を受信しない

**原因**: 作業層は Phase 0 で動作しているため、フォールバック自体が原因ではない

**対処**:
1. `inbox_watcher.sh` プロセスの動作確認
2. `queue/inbox/{隊員ID}.yaml` にメッセージが書き込まれているか確認
3. tmux セッションの動作確認

---

## 7. まとめ

| 項目 | 自動フォールバック | 手動フォールバック |
|------|-------------------|-------------------|
| トリガー | 参謀長の異常検知 | 運用者の判断 |
| 実行主体 | 参謀長 → 大隊長 | 運用者 |
| 実行コマンド | 自動実行 | `bash scripts/fallback_to_tmux.sh` |
| 作業層への影響 | なし | なし |
| 復旧方法 | `--agent-teams` フラグで再起動 | 同左 |
