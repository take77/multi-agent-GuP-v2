#!/usr/bin/env bash
# lib/agent_status.sh — エージェント状態検出・squad構成解決の共有ライブラリ
#
# 提供関数:
#   get_squad_member_ids [squad_name]       → スペース区切りのメンバーID一覧
#   get_captain_for_agent <agent_id>        → 所属隊長のID（隊長本人・不在は空文字）
#   detect_agent_state <agent_id>           → busy / idle / not_found
#   get_pane_metadata <pane_target> <key>   → tmux pane の @key 値
#
# 使用例:
#   source lib/agent_status.sh
#   members=$(get_squad_member_ids maho)
#   captain=$(get_captain_for_agent fukuda)
#   state=$(detect_agent_state maho)
#   model=$(get_pane_metadata "gup:0.1" agent_cli)

# _agent_status_script_dir: lib を含むプロジェクトルートを返す内部ヘルパー
_agent_status_project_root() {
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        echo "$SCRIPT_DIR"
    else
        cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
    fi
}

# get_squad_member_ids [squad_name]
# config/squads.yaml からメンバーIDを取得する。
# 引数: squad名（省略時は全squad）
# 出力: スペース区切りのID一覧（captain + vice_captain + members）
get_squad_member_ids() {
    local squad_filter="${1:-}"
    local squads_path
    squads_path="$(_agent_status_project_root)/config/squads.yaml"

    SQUAD_FILTER="$squad_filter" SQUADS_PATH="$squads_path" \
    python3 -c '
import os, sys
try:
    import yaml
except ImportError:
    sys.exit(0)

squad_filter = os.environ.get("SQUAD_FILTER", "")
path = os.environ.get("SQUADS_PATH", "")
try:
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    ids = []
    for squad_name, sq in (data.get("squads") or {}).items():
        if squad_filter and squad_name != squad_filter:
            continue
        cap = sq.get("captain")
        vice = sq.get("vice_captain")
        members = sq.get("members") or []
        if cap:
            ids.append(cap)
        if vice:
            ids.append(vice)
        ids.extend(m for m in members if m)
    print(" ".join(ids))
except Exception:
    print("")
' 2>/dev/null || true
}

# get_captain_for_agent <agent_id>
# config/squads.yaml からエージェントの所属隊長を解決する。
# 隊長本人・squad外（chief_of_staff等）は空文字を返す。
# 引数: agent_id
# 出力: captain名（見つからなければ空文字）
get_captain_for_agent() {
    local agent="${1:-}"
    local squads_path
    squads_path="$(_agent_status_project_root)/config/squads.yaml"

    AGENT_INPUT="$agent" SQUADS_PATH="$squads_path" \
    python3 -c '
import os, sys
try:
    import yaml
except ImportError:
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
            print("")  # 隊長本人 → 自己通知禁止
            sys.exit(0)
        elif agent == vice or agent in members:
            print(cap or "")
            sys.exit(0)
    print("")
except Exception:
    print("")
' 2>/dev/null || true
}

# _find_pane_for_agent <agent_id>
# tmux の全 pane から @agent_id が一致するものを探す内部ヘルパー。
# CLUSTER_ID が設定されている場合はセッション名プレフィックスで絞り込む。
# 出力: pane_target（例: gup:0.1）。見つからなければ空文字。
_find_pane_for_agent() {
    local agent_id="$1"
    local cluster_prefix="${CLUSTER_ID:-}"

    tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}' \
        2>/dev/null \
    | awk -v id="$agent_id" -v pfx="$cluster_prefix" '
        $2 == id && (pfx == "" || index($1, pfx) == 1) {print $1; exit}
    '
}

# detect_agent_state <agent_id>
# tmux pane のコンテンツからエージェントの稼働状態を判定する。
#
# 判定戦略（shogun v4 準拠）:
#   1. pane 存在確認: display-message で確実に存在チェック
#   2. ステータスバーチェック: 最後の非空行に 'esc to' → busy確定
#      （古いスピナーテキストの誤検知回避のため最終行のみ参照）
#   3. idle チェック: Codex/Claude の idle プロンプトパターン
#   4. テキストベースの busy マーカー: 下5行のスピナーキーワード
#
# 引数: agent_id
# 出力: busy / idle / not_found
detect_agent_state() {
    local agent_id="$1"
    local pane_target

    pane_target=$(_find_pane_for_agent "$agent_id")

    if [[ -z "$pane_target" ]]; then
        echo "not_found"
        return
    fi

    if ! tmux display-message -t "$pane_target" -p '#{pane_id}' &>/dev/null; then
        echo "not_found"
        return
    fi

    local full_capture pane_tail
    full_capture=$(timeout 2 tmux capture-pane -t "$pane_target" -p 2>/dev/null)
    pane_tail=$(echo "$full_capture" | tail -5)

    if [[ -z "$pane_tail" ]]; then
        echo "idle"
        return
    fi

    # ── ステータスバーチェック（最終行のみ）──
    local last_line
    last_line=$(echo "$pane_tail" | grep -v '^[[:space:]]*$' | tail -1)
    if echo "$last_line" | grep -qiF 'esc to'; then
        echo "busy"
        return
    fi

    # ── idle チェック ──
    if echo "$pane_tail" | grep -qE '(\? for shortcuts|context left)'; then
        echo "idle"
        return
    fi
    if echo "$pane_tail" | grep -qE '^(❯|›)\s*$'; then
        echo "idle"
        return
    fi

    # ── テキストベースの busy マーカー（下5行）──
    if echo "$pane_tail" | grep -qiF 'background terminal running'; then
        echo "busy"
        return
    fi
    if echo "$pane_tail" | grep -qiE '(Working|Thinking|Planning|Sending|task is in progress|Compacting conversation|thought for|思考中|考え中|計画中|送信中|処理中|実行中)'; then
        echo "busy"
        return
    fi

    echo "idle"
}

# get_pane_metadata <pane_target> <metadata_key>
# tmux pane の @metadata_key オプション値を返す。
# 引数: pane_target（例: gup:0.1）、metadata_key（例: agent_id, model_name, agent_cli）
# 出力: metadata値（未設定・エラー時は空文字）
get_pane_metadata() {
    local pane_target="${1:-}"
    local metadata_key="${2:-}"
    [[ -z "$pane_target" || -z "$metadata_key" ]] && return 0

    timeout 2 tmux show-options -p -t "$pane_target" -v "@${metadata_key}" 2>/dev/null \
        | tr -d '\r' | head -n1 || true
}
