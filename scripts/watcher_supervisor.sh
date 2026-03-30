#!/bin/bash
set -euo pipefail

# watcher_supervisor.sh — 全エージェントのinbox_watcherを一括管理
# Keep inbox watchers alive in a persistent tmux-hosted shell.
# This script is designed to run forever.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs queue/inbox

# ═══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════════

ensure_inbox_file() {
    local agent="$1"
    if [ ! -f "queue/inbox/${agent}.yaml" ]; then
        printf 'messages: []\n' > "queue/inbox/${agent}.yaml"
    fi
}

pane_exists() {
    local pane="$1"
    tmux list-panes -a -F "#{session_name}:#{window_name}.#{pane_index}" 2>/dev/null | grep -qx "$pane"
}

# pane-base-index に依存しない、@agent_id プロパティによるペイン特定
find_pane_for_agent() {
    local session="$1"
    local agent="$2"
    tmux list-panes -t "$session" -F '#{session_name}:#{window_name}.#{pane_index}' \
        -f "#{==:#{@agent_id},$agent}" 2>/dev/null | head -1
}

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="$3"
    local cli
    local lock_file="/tmp/gup_watcher_${agent}.lock"

    ensure_inbox_file "$agent"
    if ! pane_exists "$pane"; then
        return 0
    fi

    # ハイブリッドモード判定: 隊長エージェントは watcher 起動をスキップ
    if [[ "${GUP_AGENT_TEAMS_ACTIVE:-0}" == "1" ]]; then
        local agent_role
        agent_role=$(tmux show-options -vp -t "$pane" @agent_role 2>/dev/null || true)
        if [[ "$agent_role" == "captain" ]]; then
            # ハイブリッドモードでは隊長の watcher をスキップ
            # 代わりに inbox_watcher.sh のハイブリッドブリッジが Agent Teams JSON inbox を処理する
            return 0
        fi
    fi

    # flock による排他制御: pgrep チェックと nohup 起動の TOCTOU 窓を閉じる
    (
        flock -n 9 || return 0  # ロック取得失敗 = 別プロセスが起動処理中 → skip

        if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
            return 0
        fi

        cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "claude")
        nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
    ) 9>"$lock_file"
}

# ═══════════════════════════════════════════════════════════════════════════════
# エージェント → セッション マッピング
# pane-base-index に依存しない @agent_id ベースのペイン特定に使用
# ═══════════════════════════════════════════════════════════════════════════════

declare -A SESSION_MAP=(
    # 司令部 (command session)
    ["anzu"]="command"
    ["miho"]="command"
    # ダージリン隊 (darjeeling cluster)
    ["darjeeling"]="darjeeling"
    ["pekoe"]="darjeeling"
    ["hana"]="darjeeling"
    ["rosehip"]="darjeeling"
    ["marie"]="darjeeling"
    ["oshida"]="darjeeling"
    ["andou"]="darjeeling"
    # カチューシャ隊 (katyusha cluster)
    ["katyusha"]="katyusha"
    ["nonna"]="katyusha"
    ["klara"]="katyusha"
    ["mako"]="katyusha"
    ["erwin"]="katyusha"
    ["caesar"]="katyusha"
    ["saori"]="katyusha"
    # ケイ隊 (kay cluster)
    ["kay"]="kay"
    ["arisa"]="kay"
    ["naomi"]="kay"
    ["anchovy"]="kay"
    ["pepperoni"]="kay"
    ["carpaccio"]="kay"
    ["yukari"]="kay"
    # 西住まほ隊 (maho cluster)
    ["maho"]="maho"
    ["erika"]="maho"
    ["mika"]="maho"
    ["aki"]="maho"
    ["mikko"]="maho"
    ["kinuyo"]="maho"
    ["fukuda"]="maho"
)

# ═══════════════════════════════════════════════════════════════════════════════
# Main Loop — Monitor and restart watchers for all agents
# ═══════════════════════════════════════════════════════════════════════════════

while true; do
    for agent in "${!SESSION_MAP[@]}"; do
        session="${SESSION_MAP[$agent]}"
        pane=$(find_pane_for_agent "$session" "$agent")
        if [ -n "$pane" ]; then
            start_watcher_if_missing "$agent" "$pane" "logs/inbox_watcher_${agent}.log"
        fi
    done

    sleep 5
done
