# watcher idle-flag ライフサイクル設計（busy 判定根本強化 A）

- task: `cmd_watcher2_hardening_ab`（#2 incident deep hardening / A）
- 司令官 GO: 2026-06-10
- 設計正典参照: `multi-agent-shogun`（read-only）— `scripts/inbox_watcher.sh` / `scripts/stop_hook_inbox.sh`
- 関連 instruction: CLAUDE.md「Integration Smoke Gate」「Claim Integrity」/ incident fix commit `061a9b0`

## 1. 背景 — #2 incident と旧 busy 判定の限界

#2 は「tmux pane 走査の busy 判定が生成中 agent を idle 誤判定 → 破壊的 Escape+C-c が
mid-turn を殺し miho 連鎖 stall」。`061a9b0` で escalation(Escape+C-c) を既定 OFF にして
対症済み。さらに pane 走査自体を `esc to`(下5行) + `(Ns` 経過カウンタで hardening した
（`lib/agent_status.sh:156-198`）。

しかし pane 走査は本質的に脆い:
- status bar の文言ローテーション・テーマ別スピナー・Remote Control レイアウトで取りこぼす。
- 逆に **scroll-back の古いスピナー** を拾うと **false-busy** になり、nudge を永久スキップ＝
  配信 stall（shogun の教訓 **T-BUSY-008**：窓を広げるほど false-busy が増える）。

→ **走査の精度を上げる方向（窓拡大）は棄却**。shogun が #2 相当を回避している方式＝
**claude に対しては pane 走査をやめ、Stop hook 管理の idle flag ファイルで判定** を採用する。

## 2. 採用設計 — flag-based idle 判定（claude のみ）

### 読み取り側（本タスクで接続）
`scripts/inbox_watcher.sh` `agent_is_busy()`:

```
claude     → flag あり=idle(return 1) / flag なし=busy(return 0)
非 claude  → 従来の pane 走査 detect_agent_state（061a9b0 hardening 温存）
/clear cooldown → 送信後 30s は CLI 種別を問わず busy 固定
```

flag path は `idle_flag_path()` が **`stop_hook_inbox.sh:49-55` と同一ロジック**で解決する
（CLUSTER_ID 対応）。現行デプロイは CLUSTER_ID 未設定 → `/tmp/gup_idle_${AGENT_ID}`（flat）。

> ★不変条件: 読み取り側（watcher）と書き込み側（Stop hook）が **同じ CLUSTER_ID 解決**を
> 共有すること。両者は環境変数 `CLUSTER_ID` を継承する。現行は両者とも未設定＝flat で一致。
> 将来 cluster 運用するなら、Claude セッション env と watcher(supervisor) env の双方に
> 同じ `CLUSTER_ID` を設定する必要がある（これはデプロイ責務・コード責務外）。

### 書き込み側（既存 + 本タスクで startup touch 追加）
- `stop_hook_inbox.sh`: idle 到達（未読0 / inbox 不在 / stop_hook 再発火）時に `touch` flag。
  未読>0 で stop を block するときは **flag を維持**（削除しない）。
- `inbox_watcher.sh` startup（本タスク追加・shogun:54-59 準拠）: claude の watcher 起動時に
  flag を `touch`。CLI は welcome 画面=idle 起点であり、これを作らないと「flag なし=busy」で
  初回 nudge が永久スキップになる（fresh agent には Stop hook が未発火＝flag を書かない）。
  (re)start 時の touch は stale な cluster-prefixed flag との不一致も解消する。

### 削除パス
**通常運用では存在しない**（fail-toward-idle）。flag を消すのは全体停止系スクリプト
（例 shogun `shutsujin_departure.sh` の `rm -f /tmp/shogun_idle_*`）のみ。

## 3. 設計判断 — なぜ fail-toward-idle を許容し、staleness を入れないか

flag は **削除パスを持たない**。ゆえに一度 idle になった agent は、その後 busy に戻っても
flag が残り「idle」と見え続ける（＝ false-idle が常態）。これを **意図的に許容**する。

### 安全である理由（多層）
1. **escalation 既定 OFF**（`ASW_DISABLE_ESCALATION=1` / `061a9b0`）。false-idle で起きるのは
   **plain nudge（`inboxN` + Enter）だけ**。Escape/C-c のような破壊的操作は走らない。
2. **将来 per-CLI gate**（論点 c の決着）。escalation を将来再有効化する場合も、shogun 同様
   **claude へは Escape を永久に撃たない** per-CLI gate を条件とする（`shogun inbox_watcher.sh:1002`）。
3. **plain nudge は非破壊・自己訂正**。busy 中の `inboxN` 送信はテキストが queue され Enter が
   失われ得るだけ。次の nudge か **Stop hook の turn 終了時 inbox block 再配信**で確実に回収する。

→ flag は **「配信タイミングの最適化」であって安全装置ではない**（shogun NOTE と同旨）。
本丸の安全層は 1) escalation OFF と 2) per-CLI gate。flag の最大の失敗（誤判定）でも被害は
「無害な余分 nudge 1 発」に bounded される。

### staleness（mtime 等）を入れない理由
- 「今まさに生成中だから nudge を抑止する」ニーズが claude には無い（nudge が非破壊なため）。
  staleness は本来 busy 検知を厳密化する仕組みだが、ここでは厳密化の **利得が無い**。
- 逆に threshold/clock skew のチューニング点を増やし、**false-busy（nudge 永久スキップ＝stall）**
  という #2 で最も避けたい失敗モードを再導入するリスクがある（T-BUSY-008）。
- よって **純粋な存在チェック（presence-only）** を採用。複雑性ゼロで安全側に倒れる。

### /clear cooldown（30s）だけは別建て
flag は残るため /clear の reload(10-30s)中も idle と見え、reload 完了前に `inbox1` が届く race を
生む。これを防ぐため `LAST_CLEAR_TS`（`/clear` 送信時に `send_cli_command` が記録）から 30s は
**CLI 種別を問わず busy 固定**する（`agent_is_busy` 冒頭・shogun 準拠）。これは「最適化」ではなく
reload 窓の整合のための明示ガード。

## 4. 検証（再現手順）— SKIP=FAIL 不可

harness: `tests/watcher2_hardening_a_busy.sh`(8 PASS) / `tests/watcher2_hardening_a_sendwakeup.sh`(2 PASS)
/ `tests/watcher2_hardening_b_fd9.sh`(4 PASS)。実行ログ: `tests/watcher2_hardening_verification.log`。

### A 両方向（agent_is_busy + send_wakeup・8+2 PASS）
- claude flag **なし → busy → `send_wakeup` が SKIP**（`is busy ... deferring nudge`・send-keys 0）。
- claude flag **あり → idle → nudge `inboxN`+Enter 配信**。
- /clear cooldown 内 → flag あっても busy 固定 / 31s 後 → idle 復帰。
- 非 claude(codex) → flag を無視し pane 走査 fallback（busy/idle 双方向）。

> harness 注: testing mode は `timeout` polyfill / fswatch loop を読み込まないため、PATH に
> `timeout`/`tmux` shim を置いて `send_wakeup` の send-keys 分岐を観測した。

## 5. 影響範囲・非回帰
- `agent_is_busy` を呼ぶ全箇所（`send_wakeup` / `send_wakeup_with_escape` / fast-path C-u）で、
  claude は flag 判定・非 claude は従来走査。**非 claude の挙動は不変**（detect_agent_state 無改変）。
- `061a9b0` の pane 走査 hardening（`lib/agent_status.sh`）は **非 claude fallback として load-bearing
  のまま温存**。last-line-only 方式へは退行させない。
- escalation 既定 OFF は不変（本タスクで再有効化しない）。
