#!/usr/bin/env bash
# launch_common.sh — Common launch utilities for gup_v2_launch*.sh
# Provided functions:
#   log_info(), log_success(), log_war()    — Logging
#   generate_prompt()                        — PS1 prompt generation
#   check_dependencies()                     — Dependency validation
#   show_battle_cry()                        — Startup banner
#   launch_squad_cluster()                   — Cluster launch (parameterized)
#   launch_command_server()                  — Command session launch

# 色付きログ関数
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# プロンプト生成関数（bash/zsh対応）
# ───────────────────────────────────────────────────────────────────────────────
# 使用法: generate_prompt "ラベル" "色" "シェル"
# 色: red, green, blue, magenta, cyan, yellow
# ═══════════════════════════════════════════════════════════════════════════════
generate_prompt() {
    local label="$1"
    local color="$2"
    local shell_type="$3"

    if [ "$shell_type" == "zsh" ]; then
        # zsh用: %F{color}%B...%b%f 形式
        echo "(%F{${color}}%B${label}%b%f) %F{green}%B%~%b%f%# "
    else
        # bash用: \[\033[...m\] 形式
        local color_code
        case "$color" in
            red)     color_code="1;31" ;;
            green)   color_code="1;32" ;;
            yellow)  color_code="1;33" ;;
            blue)    color_code="1;34" ;;
            magenta) color_code="1;35" ;;
            cyan)    color_code="1;36" ;;
            *)       color_code="1;37" ;;  # white (default)
        esac
        echo "(\[\033[${color_code}m\]${label}\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ "
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# 依存ツールチェック関数（macOS / Linux 両対応）
# ═══════════════════════════════════════════════════════════════════════════════
check_dependencies() {
    local missing=()
    local os_type
    os_type="$(uname -s)"

    # ファイル監視ツール: macOS=fswatch, Linux=inotifywait
    if [ "$os_type" = "Darwin" ]; then
        command -v fswatch >/dev/null 2>&1 || missing+=("fswatch (brew install fswatch)")
    else
        command -v inotifywait >/dev/null 2>&1 || missing+=("inotifywait (sudo apt install inotify-tools)")
    fi

    # xxd: macOS は vim に同梱、Linux は別パッケージ
    command -v xxd >/dev/null 2>&1 || missing+=("xxd (sudo apt install xxd / brew install vim)")

    # Python3 + PyYAML
    command -v python3 >/dev/null 2>&1 || missing+=("python3")
    python3 -c "import yaml" 2>/dev/null || missing+=("PyYAML (pip3 install pyyaml)")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "必須ツールが不足しています:"
        printf '  - %s\n' "${missing[@]}"
        echo ""
        echo "これらが無い場合、inbox通知が届かず「サイレント・デス」が発生します。"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# 発進バナー表示（CC0ライセンスASCIIアート使用）
# ───────────────────────────────────────────────────────────────────────────────
# 【著作権・ライセンス表示】
# 忍者ASCIIアート: syntax-samurai/ryu - CC0 1.0 Universal (Public Domain)
# 出典: https://github.com/syntax-samurai/ryu
# "all files and scripts in this repo are released CC0 / kopimi!"
# ═══════════════════════════════════════════════════════════════════════════════
show_battle_cry() {
    clear

    echo -e "                    \033[1;36m「「「 了解！！ パンツァー・フォー！！ 」」」\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # システム情報
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-captain\033[0m  〜 \033[1;36mマルチエージェント統率システム\033[0m 〜           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m隊長\033[0m: プロジェクト統括 + タスク管理    \033[1;34m隊員\033[0m: 実働部隊×6          \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# 汎用クラスタ起動関数（全隊共通）
# ───────────────────────────────────────────────────────────────────────────────
# 使用法:
#   launch_squad_cluster <cluster_id> <emoji> <label>
#     <agent_ids_csv> <agent_names_csv> <agent_roles_csv> <agent_colors_csv>
#     [agent_teams_mode]
#
# 例:
#   launch_squad_cluster "darjeeling" "🫖" "ダージリン隊" \
#     "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
#     "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
#     "captain,member,member,member,member,member,member" \
#     "magenta,red,blue,blue,blue,blue,blue"
#     true  # ← 8番目: agent_teams_mode（省略時 false）
# ═══════════════════════════════════════════════════════════════════════════════
launch_squad_cluster() {
    local CLUSTER_ID="$1"
    local EMOJI="$2"
    local LABEL="$3"

    # CSV を配列に変換
    IFS=',' read -ra AGENT_IDS <<< "$4"
    IFS=',' read -ra AGENT_NAMES <<< "$5"
    IFS=',' read -ra AGENT_ROLES <<< "$6"
    IFS=',' read -ra AGENT_COLORS <<< "$7"
    local AGENT_TEAMS_MODE="${8:-false}"  # Agent Teams モード（省略時 false）

    local AGENT_COUNT=${#AGENT_IDS[@]}

    # Agent Teams: クラスタキューディレクトリ作成
    if [ "$AGENT_TEAMS_MODE" = true ]; then
        mkdir -p "$SCRIPT_DIR/clusters/$CLUSTER_ID/queue/"{tasks,reports,briefings,inbox}
    fi

    log_war "${EMOJI} ${LABEL}クラスタを起動中..."

    # 既存セッションをクリーンアップ
    tmux kill-session -t "$CLUSTER_ID" 2>/dev/null || true

    # tmuxセッション作成
    if ! tmux new-session -d -s "$CLUSTER_ID" -n "agents"; then
        echo "エラー: tmuxセッション '$CLUSTER_ID' の作成に失敗しました"
        exit 1
    fi

    # pane-base-index を取得
    local PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

    # 7ペイン作成（2x4グリッドの7ペイン使用）
    # 最初に2列に分割
    tmux split-window -h -t "${CLUSTER_ID}:agents"

    # 左列を4行に分割（4ペイン）
    tmux select-pane -t "${CLUSTER_ID}:agents.${PANE_BASE}"
    tmux split-window -v
    tmux split-window -v
    tmux select-pane -t "${CLUSTER_ID}:agents.${PANE_BASE}"
    tmux split-window -v

    # 右列を3行に分割（3ペイン）
    local right_start=$((PANE_BASE + 4))
    tmux select-pane -t "${CLUSTER_ID}:agents.${right_start}"
    tmux split-window -v
    tmux split-window -v

    # 環境変数注入: GUP_BRIDGE_MODE 条件追加
    local _bridge_export=""
    if [ "$AGENT_TEAMS_MODE" = true ]; then
        _bridge_export=" && export GUP_BRIDGE_MODE=1"
    fi

    # 各ペインに環境変数を注入
    for i in $(seq 0 $((AGENT_COUNT - 1))); do
        local p=$((PANE_BASE + i))
        local agent_id="${AGENT_IDS[$i]}"
        local agent_name="${AGENT_NAMES[$i]}"
        local agent_role="${AGENT_ROLES[$i]}"
        local agent_color="${AGENT_COLORS[$i]}"

        # tmux変数設定
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @agent_id "$agent_id"
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @agent_name "$agent_name"
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @agent_role "$agent_role"
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @cluster_id "$CLUSTER_ID"
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @current_task ""

        # Agent Teams モード設定（--agent-teams 指定時のみ）
        if [ "$AGENT_TEAMS_MODE" = true ]; then
            tmux set-environment -t "${CLUSTER_ID}:agents.${p}" GUP_BRIDGE_MODE 1
        fi

        # モデル設定（隊長=Opus, 副隊長=Opus, 隊員=Sonnet）
        local model_name="Sonnet"
        if [ "$agent_role" = "captain" ] || [ "$agent_role" = "vice_captain" ]; then
            model_name="Opus"
        fi
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @model_name "$model_name"

        # プロンプト設定と環境変数注入
        local prompt_str=$(generate_prompt "$agent_id" "$agent_color" "$SHELL_SETTING")
        tmux send-keys -t "${CLUSTER_ID}:agents.${p}" \
            "cd \"$(pwd)\" && export CLUSTER_ID='$CLUSTER_ID' && export AGENT_ID='$agent_id' && export AGENT_NAME='$agent_name' && export AGENT_ROLE='$agent_role'${_bridge_export} && export PS1='${prompt_str}' && clear" Enter

        log_info "  └─ [${i}] ${agent_name} (${agent_role}) 配備完了"
    done

    # ペインボーダーにキャラクター名表示
    tmux set-option -t "$CLUSTER_ID" -w pane-border-status top
    tmux set-option -t "$CLUSTER_ID" -w pane-border-format '#{?pane_active,#[reverse],}#[bold]#{@agent_name}#[default] (#{@agent_role}/#{@model_name}) #{@current_task}'

    # Claude Code起動（10秒間隔でstaggered launch）
    if [ "$SETUP_ONLY" = false ]; then
        log_war "${EMOJI} ${LABEL}にClaude Codeを召喚中（10秒間隔）..."

        for i in $(seq 0 $((AGENT_COUNT - 1))); do
            local p=$((PANE_BASE + i))
            local agent_role="${AGENT_ROLES[$i]}"
            local agent_name="${AGENT_NAMES[$i]}"

            # Agent Teams: 隊長はClaude Code起動スキップ
            if [ "$AGENT_TEAMS_MODE" = true ] && [ "$agent_role" = "captain" ]; then
                tmux send-keys -t "${CLUSTER_ID}:agents.${p}" \
                    "echo '🔗 Agent Teams: ${agent_name} はチームメイトとして動作中'" Enter
                log_info "  └─ ${agent_name} はAgent Teamsのチームメイト（Claude Code起動スキップ）"
                continue
            fi

            # モデル決定（隊長・副隊長=Opus, 隊員=Sonnet）
            local model_opt="--model sonnet"
            if [ "$agent_role" = "captain" ] || [ "$agent_role" = "vice_captain" ]; then
                model_opt="--model opus"
            fi

            # Claude Code起動
            tmux send-keys -t "${CLUSTER_ID}:agents.${p}" \
                "claude $model_opt --dangerously-skip-permissions"
            sleep 0.3
            tmux send-keys -t "${CLUSTER_ID}:agents.${p}" Enter

            log_info "  └─ ${agent_name} にClaude Code召喚完了"

            # staggered launch: 最後以外は3秒待機
            if [ $i -lt $((AGENT_COUNT - 1)) ]; then
                sleep 3
            fi
        done
    fi

    log_success "✅ ${LABEL}クラスタ起動完了！"

    # inbox_watcherはwatcher_supervisorが一括管理するためここでは起動しない
    # (STEP 6.6でwatcher_supervisor.shが全エージェントを自動検出・起動)

    echo ""
    echo "  接続方法:"
    echo "    tmux attach-session -t ${CLUSTER_ID}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# 司令部サーバー起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_command_server() {
    local TMUX_SERVER="command"

    log_war "🎖️ 司令部サーバーを起動中..."

    # 既存セッションをクリーンアップ
    tmux kill-session -t command 2>/dev/null || true

    # tmuxサーバー起動（別サーバーとして）
    if ! tmux new-session -d -s command -n "command"; then
        echo "エラー: tmuxセッション 'command' の作成に失敗しました"
        exit 1
    fi

    # pane-base-index を取得
    local PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

    # ペイン1を追加（参謀長用）
    tmux split-window -v -t "command:command"

    # エージェント情報定義（2名: 大隊長 + 参謀長）
    local AGENT_IDS=("anzu" "miho")
    local AGENT_NAMES=("角谷杏" "西住みほ")
    local AGENT_ROLES=("battalion_commander" "chief_of_staff")
    local AGENT_COLORS=("yellow" "magenta")

    # 各ペインに環境変数を注入
    for i in {0..1}; do
        local p=$((PANE_BASE + i))
        local agent_id="${AGENT_IDS[$i]}"
        local agent_name="${AGENT_NAMES[$i]}"
        local agent_role="${AGENT_ROLES[$i]}"
        local agent_color="${AGENT_COLORS[$i]}"

        # tmux変数設定
        tmux set-option -p -t "command:command.${p}" @agent_id "$agent_id"
        tmux set-option -p -t "command:command.${p}" @agent_name "$agent_name"
        tmux set-option -p -t "command:command.${p}" @agent_role "$agent_role"
        tmux set-option -p -t "command:command.${p}" @model_name "Opus"
        tmux set-option -p -t "command:command.${p}" @current_task ""

        # プロンプト設定と環境変数注入
        local prompt_str=$(generate_prompt "$agent_id" "$agent_color" "$SHELL_SETTING")
        tmux send-keys -t "command:command.${p}" \
            "cd \"$(pwd)\" && export AGENT_ID='$agent_id' && export AGENT_NAME='$agent_name' && export AGENT_ROLE='$agent_role' && export PS1='${prompt_str}' && clear" Enter

        log_info "  └─ [${i}] ${agent_name} (${agent_role}) 配備完了"
    done

    # ペインボーダーにキャラクター名表示
    tmux set-option -t command -w pane-border-status top
    tmux set-option -t command -w pane-border-format '#{?pane_active,#[reverse],}#[bold]#{@agent_name}#[default] (#{@agent_role}/#{@model_name}) #{@current_task}'

    # Claude Code起動（3秒間隔でstaggered launch）
    if [ "$SETUP_ONLY" = false ]; then
        log_war "🎖️ 司令部にClaude Codeを召喚中（3秒間隔）..."

        for i in {0..1}; do
            local p=$((PANE_BASE + i))
            local agent_name="${AGENT_NAMES[$i]}"

            # Claude Code起動（司令部は全員Opus）
            tmux send-keys -t "command:command.${p}" \
                "claude --model opus --dangerously-skip-permissions"
            sleep 0.3
            tmux send-keys -t "command:command.${p}" Enter

            log_info "  └─ ${agent_name} にClaude Code召喚完了"

            # staggered launch: 最後以外は3秒待機
            if [ $i -lt 1 ]; then
                sleep 3
            fi
        done
    fi

    log_success "✅ 司令部サーバー起動完了！"
    echo ""
    echo "  接続方法:"
    echo "    tmux attach-session -t command"
    echo ""
}
