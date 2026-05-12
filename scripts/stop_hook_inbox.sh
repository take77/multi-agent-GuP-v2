#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# stop_hook_inbox.sh — Claude Code Stop Hook for GuP-v2 inbox delivery
# ═══════════════════════════════════════════════════════════════
# Claude Code エージェントが停止する直前、本 hook は以下を行う:
#   1. last_assistant_message を解析しタスク完了/エラーを検知
#   2. captain に inbox_write で自動通知（非同期・非ブロッキング）
#   3. 未読 inbox を集計
#   4. 未読 > 0 の場合、停止をブロック (decision=block) し未読要約を返す
#
# 適用: .claude/settings.json の Stop hook に登録
#   stdin から JSON を受け、stdout へ JSON または空を返す。
#
# 環境変数:
#   TMUX_PANE                 — 実行エージェント特定（必須）
#   CLUSTER_ID                — マルチクラスタ運用時の inbox パス分離
#   __STOP_HOOK_SCRIPT_DIR    — テスト用 SCRIPT_DIR override
#   __STOP_HOOK_AGENT_ID      — テスト用 AGENT_ID override
#   IDLE_FLAG_DIR             — idle flag 配置ディレクトリ（既定 /tmp）
#
# 由来: multi-agent-shogun/scripts/stop_hook_inbox.sh を GuP-v2 適合
#   - karo → captain 動的解決 (config/squads.yaml)
#   - inotifywait/fswatch 経由の待機は廃止（macOS 専用・60s 内完結）
#   - CLUSTER_ID-aware inbox パス（check_inbox_on_stop.sh 機能を包含）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="${__STOP_HOOK_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── stdin から hook 入力 JSON 取得 ───
INPUT=$(cat || true)

# ─── エージェント特定 ───
if [ -n "${__STOP_HOOK_AGENT_ID+x}" ]; then
    AGENT_ID="$__STOP_HOOK_AGENT_ID"
elif [ -n "${TMUX_PANE:-}" ]; then
    AGENT_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}' 2>/dev/null || true)
else
    AGENT_ID=""
fi

# 特定不能 → 承認（exit 0 出力なし）
[ -z "$AGENT_ID" ] && exit 0

# ─── INBOX / idle flag パス解決（CLUSTER_ID 対応） ───
if [ -n "${CLUSTER_ID:-}" ]; then
    INBOX="$SCRIPT_DIR/clusters/$CLUSTER_ID/queue/inbox/${AGENT_ID}.yaml"
    IDLE_FLAG="${IDLE_FLAG_DIR:-/tmp}/gup_${CLUSTER_ID}_idle_${AGENT_ID}"
else
    INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
    IDLE_FLAG="${IDLE_FLAG_DIR:-/tmp}/gup_idle_${AGENT_ID}"
fi

# ─── 無限ループ防止 ───
# stop_hook_active=True は「前回 block でこの hook が再発火している」状態。
# 既に未読をフィードバック済みなので exit 0 で停止を許可（連鎖ブロック禁止）。
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | python3 -c "import sys,json;
try: print(json.load(sys.stdin).get('stop_hook_active', False))
except Exception: print(False)" 2>/dev/null || echo "False")

if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
    touch "$IDLE_FLAG" 2>/dev/null || true
    exit 0
fi

# ─── captain 動的解決 (config/squads.yaml) ───
# squads 外（chief_of_staff/shogun/anzu 等）や captain 本人 → 空文字
get_captain_for_agent() {
    local agent="$1"
    AGENT_INPUT="$agent" SQUADS_PATH="$SCRIPT_DIR/config/squads.yaml" \
    python3 -c '
import os, sys
try:
    import yaml
except Exception:
    sys.exit(0)
agent = os.environ.get("AGENT_INPUT", "")
path = os.environ.get("SQUADS_PATH", "")
try:
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    for _, sq in (data.get("squads") or {}).items():
        cap = sq.get("captain")
        vice = sq.get("vice_captain")
        members = sq.get("members") or []
        if agent == cap:
            return_cap = ""  # captain 本人 → 自己通知禁止
        elif agent == vice or agent in members:
            return_cap = cap or ""
        else:
            continue
        print(return_cap)
        sys.exit(0)
    print("")
except Exception:
    print("")
' 2>/dev/null || true
}

# ─── last_assistant_message 解析 → captain 通知 ───
LAST_MSG=$(printf '%s' "$INPUT" | python3 -c "import sys,json;
try: print(json.load(sys.stdin).get('last_assistant_message', ''))
except Exception: print('')" 2>/dev/null || echo "")

if [ -n "$LAST_MSG" ]; then
    NOTIFY_TYPE=""
    NOTIFY_CONTENT=""

    # 完了検知（日英両対応）
    if echo "$LAST_MSG" | grep -qiE '任務完了|完了でござる|完遂|報告YAML.*(更新|作成)|report.*(updated|written)|task completed|タスク完了|完了報告'; then
        NOTIFY_TYPE="report_received"
        NOTIFY_CONTENT="[auto-notify] ${AGENT_ID}: タスク完了。queue/reports/${AGENT_ID}_report.yaml を確認されたし。"
    # エラー検知（動詞 + 文脈で限定し誤検知を抑制）
    elif echo "$LAST_MSG" | grep -qiE 'エラー.*中断|失敗.*中断|見つからない.*中断|処理を中止|abort|error.*abort|failed.*stop'; then
        NOTIFY_TYPE="task_failed"
        NOTIFY_CONTENT="[auto-notify] ${AGENT_ID}: エラーで停止。確認されたし。"
    fi

    if [ -n "$NOTIFY_TYPE" ]; then
        CAPTAIN=$(get_captain_for_agent "$AGENT_ID")
        if [ -n "$CAPTAIN" ] && [ "$CAPTAIN" != "$AGENT_ID" ]; then
            # バックグラウンド非ブロッキング送信。エラーは無視（hook 自体は遅延させない）
            bash "$SCRIPT_DIR/scripts/inbox_write.sh" "$CAPTAIN" \
                "$NOTIFY_CONTENT" "$NOTIFY_TYPE" "$AGENT_ID" >/dev/null 2>&1 &
            disown 2>/dev/null || true
        fi
    fi
fi

# ─── 未読 inbox 集計 ───
if [ ! -f "$INBOX" ]; then
    touch "$IDLE_FLAG" 2>/dev/null || true
    exit 0
fi

UNREAD_COUNT=$(grep -c 'read: false' "$INBOX" 2>/dev/null || true)
UNREAD_COUNT="${UNREAD_COUNT:-0}"

if [ "$UNREAD_COUNT" -eq 0 ] 2>/dev/null; then
    touch "$IDLE_FLAG" 2>/dev/null || true
    exit 0
fi

# ─── 未読あり: block JSON 出力（最大 5 件のサマリ付き） ───
# 注: idle flag は維持する（shogun 同等）。理由はソース冒頭コメント参照。
if [ -n "${CLUSTER_ID:-}" ]; then
    INBOX_REL="clusters/${CLUSTER_ID}/queue/inbox/${AGENT_ID}.yaml"
else
    INBOX_REL="queue/inbox/${AGENT_ID}.yaml"
fi
__STOP_HOOK_INBOX="$INBOX" __STOP_HOOK_INBOX_REL="$INBOX_REL" \
__STOP_HOOK_AGENT_ID_OUT="$AGENT_ID" \
__STOP_HOOK_UNREAD_COUNT="$UNREAD_COUNT" \
python3 -c '
import json, os
try:
    import yaml
except Exception:
    yaml = None

inbox = os.environ["__STOP_HOOK_INBOX"]
inbox_rel = os.environ["__STOP_HOOK_INBOX_REL"]
agent_id = os.environ["__STOP_HOOK_AGENT_ID_OUT"]
count = int(os.environ["__STOP_HOOK_UNREAD_COUNT"])

summary = ""
if yaml is not None:
    try:
        with open(inbox, "r") as f:
            data = yaml.safe_load(f) or {}
        msgs = data.get("messages", []) if isinstance(data, dict) else []
        unread = [m for m in msgs if isinstance(m, dict) and not m.get("read", True)]
        parts = []
        for m in unread[:5]:
            frm = m.get("from", "?")
            typ = m.get("type", "?")
            content = str(m.get("content", ""))[:80].replace("\n", " ")
            parts.append(f"[{frm}/{typ}] {content}")
        summary = " | ".join(parts)
    except Exception:
        summary = f"inbox未読{count}件あり"

reason = (
    f"inbox未読{count}件あり。{inbox_rel} を読み、"
    f"read:false を処理してから停止せよ。要約: {summary}"
)
print(json.dumps({"decision": "block", "reason": reason}, ensure_ascii=False))
' 2>/dev/null || printf '{"decision":"block","reason":"inbox未読%s件あり。%s を読んで処理せよ。"}\n' "$UNREAD_COUNT" "$INBOX_REL"
