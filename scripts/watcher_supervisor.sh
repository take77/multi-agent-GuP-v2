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

start_watcher_if_missing() {
    local agent="$1"
    local pane="$2"
    local log_file="$3"
    local cli

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

    if pgrep -f "scripts/inbox_watcher.sh ${agent} " >/dev/null 2>&1; then
        return 0
    fi

    cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "claude")
    nohup bash scripts/inbox_watcher.sh "$agent" "$pane" "$cli" >> "$log_file" 2>&1 &
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main Loop — Monitor and restart watchers for all agents
# ═══════════════════════════════════════════════════════════════════════════════

while true; do
    # ─────────────────────────────────────────────────────────────────────────
    # 司令部 (command session)
    # ─────────────────────────────────────────────────────────────────────────
    start_watcher_if_missing "anzu" "command:main.0" "logs/inbox_watcher_anzu.log"
    start_watcher_if_missing "miho" "command:main.1" "logs/inbox_watcher_miho.log"

    # ─────────────────────────────────────────────────────────────────────────
    # ダージリン隊 (darjeeling cluster)
    # ─────────────────────────────────────────────────────────────────────────
    start_watcher_if_missing "darjeeling" "darjeeling:agents.0" "logs/inbox_watcher_darjeeling.log"
    start_watcher_if_missing "pekoe" "darjeeling:agents.1" "logs/inbox_watcher_pekoe.log"
    start_watcher_if_missing "hana" "darjeeling:agents.2" "logs/inbox_watcher_hana.log"
    start_watcher_if_missing "rosehip" "darjeeling:agents.3" "logs/inbox_watcher_rosehip.log"
    start_watcher_if_missing "marie" "darjeeling:agents.4" "logs/inbox_watcher_marie.log"
    start_watcher_if_missing "oshida" "darjeeling:agents.5" "logs/inbox_watcher_oshida.log"
    start_watcher_if_missing "andou" "darjeeling:agents.6" "logs/inbox_watcher_andou.log"

    # ─────────────────────────────────────────────────────────────────────────
    # カチューシャ隊 (katyusha cluster)
    # ─────────────────────────────────────────────────────────────────────────
    start_watcher_if_missing "katyusha" "katyusha:agents.0" "logs/inbox_watcher_katyusha.log"
    start_watcher_if_missing "nonna" "katyusha:agents.1" "logs/inbox_watcher_nonna.log"
    start_watcher_if_missing "klara" "katyusha:agents.2" "logs/inbox_watcher_klara.log"
    start_watcher_if_missing "mako" "katyusha:agents.3" "logs/inbox_watcher_mako.log"
    start_watcher_if_missing "erwin" "katyusha:agents.4" "logs/inbox_watcher_erwin.log"
    start_watcher_if_missing "caesar" "katyusha:agents.5" "logs/inbox_watcher_caesar.log"
    start_watcher_if_missing "saori" "katyusha:agents.6" "logs/inbox_watcher_saori.log"

    # ─────────────────────────────────────────────────────────────────────────
    # ケイ隊 (kay cluster)
    # ─────────────────────────────────────────────────────────────────────────
    start_watcher_if_missing "kay" "kay:agents.0" "logs/inbox_watcher_kay.log"
    start_watcher_if_missing "arisa" "kay:agents.1" "logs/inbox_watcher_arisa.log"
    start_watcher_if_missing "naomi" "kay:agents.2" "logs/inbox_watcher_naomi.log"
    start_watcher_if_missing "anchovy" "kay:agents.3" "logs/inbox_watcher_anchovy.log"
    start_watcher_if_missing "pepperoni" "kay:agents.4" "logs/inbox_watcher_pepperoni.log"
    start_watcher_if_missing "carpaccio" "kay:agents.5" "logs/inbox_watcher_carpaccio.log"
    start_watcher_if_missing "yukari" "kay:agents.6" "logs/inbox_watcher_yukari.log"

    # ─────────────────────────────────────────────────────────────────────────
    # 西住まほ隊 (maho cluster)
    # ─────────────────────────────────────────────────────────────────────────
    start_watcher_if_missing "maho" "maho:agents.0" "logs/inbox_watcher_maho.log"
    start_watcher_if_missing "erika" "maho:agents.1" "logs/inbox_watcher_erika.log"
    start_watcher_if_missing "mika" "maho:agents.2" "logs/inbox_watcher_mika.log"
    start_watcher_if_missing "aki" "maho:agents.3" "logs/inbox_watcher_aki.log"
    start_watcher_if_missing "mikko" "maho:agents.4" "logs/inbox_watcher_mikko.log"
    start_watcher_if_missing "kinuyo" "maho:agents.5" "logs/inbox_watcher_kinuyo.log"
    start_watcher_if_missing "fukuda" "maho:agents.6" "logs/inbox_watcher_fukuda.log"

    sleep 5
done
