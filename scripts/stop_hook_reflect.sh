#!/usr/bin/env bash
# stop_hook_reflect.sh — Phase 2: 最小 PoC reflect hook（トリガのみ）
#
# 目的: Stop 時に agent へ自己振り返りプロンプトを 1 回だけ注入する。
# ★設計: hook=トリガのみ・content 判定しない・注入=decision=block+reason 一択
# ★安全: 1session1回 二重ガード / 完全 fail-open / 未読優先 / compaction 非干渉 / 真完了のみ
#
# GO条件5（spike §3-§5 準拠）:
#   1. stop_hook_active==True → exit 0（連鎖 block 禁止）
#   2. session flag /tmp/gup_reflect_done_${AGENT_ID}_${SESSION_ID} 在れば exit 0
#   3. compaction lock queue/inbox/.compaction_lock_${AGENT_ID} 在れば exit 0
#   4. 未読>0 → exit 0（inbox hook に譲る）
#   5. background_tasks/session_crons が非空 → exit 0（真完了のみ発火）
#   6. 上記全 pass → flag セット → block+reason 注入（1 回限り）
#
# 注意:
#   - set -e 不使用（fail-open 徹底）
#   - 全エラーパスは exit 0（判断不能なら止めない）
#   - stdout には block JSON のみ（それ以外は空）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || SCRIPT_DIR="$(pwd)"

# ─── stdin 取得 ───
INPUT=$(cat 2>/dev/null) || INPUT=""

# ─── エージェント特定 ───
if [ -n "${__STOP_HOOK_AGENT_ID+x}" ]; then
    AGENT_ID="$__STOP_HOOK_AGENT_ID"
elif [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)
else
    AGENT_ID=""
fi
[ -z "$AGENT_ID" ] && exit 0   # 特定不能 → fail-open

# ─── enable-gate（最上位・既定 off） ───
# flag 不在なら発火しない。Phase3 で test agent のみ flag を作成して限定試験。
ENABLE_FLAG="${SCRIPT_DIR}/queue/inbox/.reflect_enabled_${AGENT_ID}"
[ -f "$ENABLE_FLAG" ] || exit 0

# ─── ① stop_hook_active ガード（multi-block 連鎖禁止） ───
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('stop_hook_active', False))
except Exception:
    print(False)
" 2>/dev/null || echo "False")
[ "$STOP_HOOK_ACTIVE" = "True" ] && exit 0

# ─── ② session スコープ flag（1session1回） ───
SESSION_ID=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    v = json.load(sys.stdin).get('session_id', '')
    print(v if v else '')
except Exception:
    print('')
" 2>/dev/null || echo "")
[ -z "$SESSION_ID" ] && exit 0   # session_id 不明 → flag 設定不能 → fail-open

REFLECT_FLAG="/tmp/gup_reflect_done_${AGENT_ID}_${SESSION_ID}"
[ -f "$REFLECT_FLAG" ] && exit 0   # 当 session で既に振り返り済み

# ─── ③ compaction 非干渉（compaction_lock.sh 無改変・読むだけ） ───
LOCKFILE="${SCRIPT_DIR}/queue/inbox/.compaction_lock_${AGENT_ID}"
[ -f "$LOCKFILE" ] && exit 0

# ─── ④ 未読優先（未読>0 → inbox hook に譲る） ───
if [ -n "${CLUSTER_ID:-}" ]; then
    INBOX="${SCRIPT_DIR}/clusters/${CLUSTER_ID}/queue/inbox/${AGENT_ID}.yaml"
else
    INBOX="${SCRIPT_DIR}/queue/inbox/${AGENT_ID}.yaml"
fi
if [ -f "$INBOX" ]; then
    UNREAD=$(grep -c 'read: false' "$INBOX" 2>/dev/null || echo "0")
    UNREAD="${UNREAD:-0}"
    [ "${UNREAD}" -gt 0 ] 2>/dev/null && exit 0
fi

# ─── ⑤ 真完了のみ（background_tasks/session_crons が空の場合のみ発火） ───
# Phase1 ログ確認済: background_tasks=[] / session_crons=[] が clean stop（推測でない）
IS_TRUE_STOP=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    bg = d.get('background_tasks', [])
    sc = d.get('session_crons', [])
    print('true' if (not bg and not sc) else 'false')
except Exception:
    print('false')
" 2>/dev/null || echo "false")
[ "$IS_TRUE_STOP" != "true" ] && exit 0

# ─── ⑥ 振り返りプロンプトを block + reason で 1 回注入 ───
# flag を先にセット → 次 Stop 発火時に ② でガード
touch "$REFLECT_FLAG" 2>/dev/null || true

REASON="停止前チェック(auto_stophook): 直近で司令官/QCから明示訂正(違う/そうじゃない/やり直し/却下/それは誤り 等)があったか。あれば現物引用のうえ feedback メモ1件作成(metadata.source:auto_stophook, provisional:true)し MEMORY.md に1行 Edit append(full write 禁止)。無ければ何もせず停止してよい。"

printf '%s' "$REASON" | python3 -c "
import json, sys
reason = sys.stdin.read()
print(json.dumps({'decision': 'block', 'reason': reason}, ensure_ascii=False))
" 2>/dev/null || exit 0
