#!/bin/bash
# 🏯 multi-agent-GuP-v2 発進スクリプト（毎日の起動用）
# Daily Deployment Script for Multi-Agent Orchestration System
#
# 使用方法:
#   ./gup_v2_launch.sh           # 全エージェント起動（前回の状態を維持）
#   ./gup_v2_launch.sh -c        # キューをリセットして起動（クリーンスタート）
#   ./gup_v2_launch.sh -s        # セットアップのみ（Claude起動なし）
#   ./gup_v2_launch.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# シェル設定を読み取り（デフォルト: bash）
SHELL_SETTING="bash"
if [ -f "./config/settings.yaml" ]; then
    SHELL_SETTING=$(grep "^shell:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "bash")
fi

# CLI Adapter読み込み（Multi-CLI Support）
if [ -f "$SCRIPT_DIR/lib/cli_adapter.sh" ]; then
    source "$SCRIPT_DIR/lib/cli_adapter.sh"
    CLI_ADAPTER_LOADED=true
else
    CLI_ADAPTER_LOADED=false
fi

# 色付きログ関数（）
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
# 依存ツールチェック関数
# ═══════════════════════════════════════════════════════════════════════════════
check_dependencies() {
    local missing=()
    command -v inotifywait >/dev/null 2>&1 || missing+=("inotifywait (sudo apt install inotify-tools)")
    command -v xxd >/dev/null 2>&1 || missing+=("xxd (sudo apt install xxd)")
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
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
SETUP_ONLY=false
OPEN_TERMINAL=false
CLEAN_MODE=false
KESSEN_MODE=false
CAPTAIN_NO_THINKING=false
SILENT_MODE=false
SHELL_OVERRIDE=""
CLUSTER_MODE=""  # "" = 従来モード, "darjeeling" = ダージリン隊のみ, "all" = 全クラスタ
COMMAND_SERVER_MODE=false  # --command: 司令部サーバーのみ起動

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -k|--kessen)
            KESSEN_MODE=true
            shift
            ;;
        -t|--terminal)
            OPEN_TERMINAL=true
            shift
            ;;
        --captain-no-thinking)
            CAPTAIN_NO_THINKING=true
            shift
            ;;
        -S|--silent)
            SILENT_MODE=true
            shift
            ;;
        -shell|--shell)
            if [[ -n "$2" && "$2" != -* ]]; then
                SHELL_OVERRIDE="$2"
                shift 2
            else
                echo "エラー: -shell オプションには bash または zsh を指定してください"
                exit 1
            fi
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-captain 発進スクリプト"
            echo ""
            echo "使用方法: ./gup_v2_launch.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -c, --clean         キューとダッシュボードをリセットして起動（クリーンスタート）"
            echo "                      未指定時は前回の状態を維持して起動"
            echo "  -k, --kessen        決戦モード（全隊員をOpusで起動）"
            echo "                      未指定時は平時の隊（隊員1-4=Sonnet, 隊員5-8=Opus）"
            echo "  -s, --setup-only    tmuxセッションのセットアップのみ（Claude起動なし）"
            echo "  -t, --terminal      Windows Terminal で新しいタブを開く"
            echo "  -shell, --shell SH  シェルを指定（bash または zsh）"
            echo "                      未指定時は config/settings.yaml の設定を使用"
            echo "  -S, --silent        サイレントモード（隊員のecho表示を無効化・API節約）"
            echo "                      未指定時はshoutモード（タスク完了時にecho表示）"
            echo "  --cluster <name>    指定クラスタのみ起動（例: --cluster darjeeling, --cluster katyusha）"
            echo "                      デフォルトtmuxサーバーに統合されたセッションとして起動"
            echo "  --command           司令部サーバーのみ起動（大隊長+参謀長の2ペイン）"
            echo "                      デフォルトtmuxサーバーにcommandセッションとして起動"
            echo "  --all-clusters      全クラスタ起動（将来用、現在はスタブ）"
            echo "  -h, --help          このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./gup_v2_launch.sh              # 前回の状態を維持して発進"
            echo "  ./gup_v2_launch.sh -c           # クリーンスタート（キューリセット）"
            echo "  ./gup_v2_launch.sh -s           # セットアップのみ（手動でClaude起動）"
            echo "  ./gup_v2_launch.sh -t           # 全エージェント起動 + ターミナルタブ展開"
            echo "  ./gup_v2_launch.sh -shell bash  # bash用プロンプトで起動"
            echo "  ./gup_v2_launch.sh -k           # 決戦モード（全隊員Opus）"
            echo "  ./gup_v2_launch.sh -c -k         # クリーンスタート＋決戦モード"
            echo "  ./gup_v2_launch.sh -shell zsh   # zsh用プロンプトで起動"
            echo "  ./gup_v2_launch.sh --captain-no-thinking  # 大隊長のthinkingを無効化（中継特化）"
            echo "  ./gup_v2_launch.sh -S           # サイレントモード（echo表示なし）"
            echo ""
            echo "モデル構成:"
            echo "  大隊長/参謀長: Opus（--captain-no-thinkingで大隊長のthinking無効化）"
            echo "  隊長/副隊長:   Opus"
            echo "  隊員1-4:   Sonnet"
            echo "  隊員5-8:   Opus"
            echo ""
            echo "隊形:"
            echo "  平時の隊（デフォルト）: 隊員1-4=Sonnet, 隊員5-8=Opus"
            echo "  決戦モード（--kessen）:   全隊員=Opus"
            echo ""
            echo "表示モード:"
            echo "  shout（デフォルト）:  タスク完了時にecho表示"
            echo "  silent（--silent）:   echo表示なし（API節約）"
            echo ""
            echo "エイリアス:"
            echo "  csst  → cd /mnt/c/tools/multi-agent-captain && ./gup_v2_launch.sh"
            echo "  css   → tmux attach-session -t command"
            echo "  csm   → tmux attach -t darjeeling"
            echo ""
            exit 0
            ;;
        --cluster)
            if [[ -n "$2" && "$2" != -* ]]; then
                CLUSTER_MODE="$2"
                shift 2
            else
                echo "エラー: --cluster オプションにはクラスタ名を指定してください（例: --cluster darjeeling）"
                exit 1
            fi
            ;;
        --all-clusters)
            CLUSTER_MODE="all"
            shift
            ;;
        --command)
            COMMAND_SERVER_MODE=true
            shift
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./gup_v2_launch.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# シェル設定のオーバーライド（コマンドラインオプション優先）
if [ -n "$SHELL_OVERRIDE" ]; then
    if [[ "$SHELL_OVERRIDE" == "bash" || "$SHELL_OVERRIDE" == "zsh" ]]; then
        SHELL_SETTING="$SHELL_OVERRIDE"
    else
        echo "エラー: -shell オプションには bash または zsh を指定してください（指定値: $SHELL_OVERRIDE）"
        exit 1
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 依存ツールチェック実行
# ═══════════════════════════════════════════════════════════════════════════════
check_dependencies

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
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m隊長\033[0m: プロジェクト統括    \033[1;31m副隊長\033[0m: タスク管理    \033[1;34m隊員\033[0m: 実働部隊×8      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# 汎用クラスタ起動関数（全隊共通）
# ───────────────────────────────────────────────────────────────────────────────
# 使用法:
#   launch_squad_cluster <cluster_id> <emoji> <label>
#     <agent_ids_csv> <agent_names_csv> <agent_roles_csv> <agent_colors_csv>
#
# 例:
#   launch_squad_cluster "darjeeling" "🫖" "ダージリン隊" \
#     "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
#     "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
#     "captain,vice_captain,member,member,member,member,member" \
#     "magenta,red,blue,blue,blue,blue,blue"
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

    local AGENT_COUNT=${#AGENT_IDS[@]}

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

        # モデル設定（隊長・副隊長=Opus, 隊員=Sonnet）
        local model_name="Sonnet"
        if [ "$agent_role" = "captain" ] || [ "$agent_role" = "vice_captain" ]; then
            model_name="Opus"
        fi
        tmux set-option -p -t "${CLUSTER_ID}:agents.${p}" @model_name "$model_name"

        # プロンプト設定と環境変数注入
        local prompt_str=$(generate_prompt "$agent_id" "$agent_color" "$SHELL_SETTING")
        tmux send-keys -t "${CLUSTER_ID}:agents.${p}" \
            "cd \"$(pwd)\" && export CLUSTER_ID='$CLUSTER_ID' && export AGENT_ID='$agent_id' && export AGENT_NAME='$agent_name' && export AGENT_ROLE='$agent_role' && export PS1='${prompt_str}' && clear" Enter

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

            # モデル決定
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

            # staggered launch: 最後以外は10秒待機
            if [ $i -lt $((AGENT_COUNT - 1)) ]; then
                sleep 10
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

    # Claude Code起動（10秒間隔でstaggered launch）
    if [ "$SETUP_ONLY" = false ]; then
        log_war "🎖️ 司令部にClaude Codeを召喚中（10秒間隔）..."

        for i in {0..1}; do
            local p=$((PANE_BASE + i))
            local agent_name="${AGENT_NAMES[$i]}"

            # Claude Code起動（司令部は全員Opus）
            tmux send-keys -t "command:command.${p}" \
                "claude --model opus --dangerously-skip-permissions"
            sleep 0.3
            tmux send-keys -t "command:command.${p}" Enter

            log_info "  └─ ${agent_name} にClaude Code召喚完了"

            # staggered launch: 最後以外は10秒待機
            if [ $i -lt 1 ]; then
                sleep 10
            fi
        done
    fi

    log_success "✅ 司令部サーバー起動完了！"
    echo ""
    echo "  接続方法:"
    echo "    tmux attach-session -t command"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# ダージリン隊クラスタ起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_darjeeling_cluster() {
    launch_squad_cluster "darjeeling" "🫖" "ダージリン隊" \
        "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
        "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue"
}

# ═══════════════════════════════════════════════════════════════════════════════
# カチューシャ隊クラスタ起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_katyusha_cluster() {
    launch_squad_cluster "katyusha" "🪆" "カチューシャ隊" \
        "katyusha,nonna,klara,mako,erwin,caesar,saori" \
        "カチューシャ,ノンナ,クラーラ,冷泉麻子,エルヴィン,カエサル,武部沙織" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ケイ隊クラスタ起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_kay_cluster() {
    launch_squad_cluster "kay" "🦅" "ケイ隊" \
        "kay,arisa,naomi,anchovy,pepperoni,carpaccio,yukari" \
        "ケイ,アリサ,ナオミ,アンチョビ,ペパロニ,カルパッチョ,秋山優花里" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue"
}

# ═══════════════════════════════════════════════════════════════════════════════
# 西住まほ隊クラスタ起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_maho_cluster() {
    launch_squad_cluster "maho" "🖤" "西住まほ隊" \
        "maho,erika,mika,aki,mikko,kinuyo,fukuda" \
        "西住まほ,逸見エリカ,ミカ,アキ,ミッコ,西絹代,福田" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue"
}

# バナー表示実行
show_battle_cry

echo -e "  \033[1;33mパンツァー・フォー！隊立てを開始します\033[0m (Setting up the battlefield)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 司令部サーバーモード分岐（--command オプション指定時）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$COMMAND_SERVER_MODE" = true ]; then
    log_info "🎖️ 司令部サーバーモード: 大隊長+参謀長のみ起動"
    check_dependencies
    launch_command_server
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# クラスタモード分岐（--cluster オプション指定時）
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$CLUSTER_MODE" ]; then
    case "$CLUSTER_MODE" in
        darjeeling)
            log_info "🫖 クラスタモード: ダージリン隊のみ起動"
            check_dependencies
            launch_darjeeling_cluster
            exit 0
            ;;
        katyusha)
            log_info "🪆 クラスタモード: カチューシャ隊のみ起動"
            check_dependencies
            launch_katyusha_cluster
            exit 0
            ;;
        kay)
            log_info "🦅 クラスタモード: ケイ隊のみ起動"
            check_dependencies
            launch_kay_cluster
            exit 0
            ;;
        maho)
            log_info "🖤 クラスタモード: 西住まほ隊のみ起動"
            check_dependencies
            launch_maho_cluster
            exit 0
            ;;
        all)
            log_info "🌐 クラスタモード: 全クラスタ起動"
            check_dependencies
            launch_darjeeling_cluster
            launch_katyusha_cluster
            launch_kay_cluster
            launch_maho_cluster
            exit 0
            ;;
        *)
            echo "エラー: 未知のクラスタ名 '$CLUSTER_MODE'"
            echo "  利用可能なクラスタ: darjeeling, katyusha, kay, maho"
            exit 1
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: 既存セッションクリーンアップ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🧹 既存の隊を撤収中..."
for _sq in darjeeling katyusha kay maho command; do
    tmux kill-session -t "$_sq" 2>/dev/null && log_info "  └─ ${_sq}、撤収完了" || log_info "  └─ ${_sq}は存在せず"
done

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1.5: 前回記録のバックアップ（--clean時のみ、内容がある場合）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$CLEAN_MODE" = true ]; then
    BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    if [ -f "./dashboard.md" ]; then
        if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    # 既存の dashboard.md 判定の後に追加
    if [ -f "./queue/captain_to_vice_captain.yaml" ]; then
        if grep -q "id: cmd_" "./queue/captain_to_vice_captain.yaml" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    if [ "$NEED_BACKUP" = true ]; then
        mkdir -p "$BACKUP_DIR" || true
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
        cp "./queue/captain_to_vice_captain.yaml" "$BACKUP_DIR/" 2>/dev/null || true
        log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: キューディレクトリ確保 + リセット（--clean時のみリセット）
# ═══════════════════════════════════════════════════════════════════════════════

# queue ディレクトリが存在しない場合は作成（初回起動時に必要）
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks ] || mkdir -p ./queue/tasks
# inbox はLinux FSにシンボリックリンク（WSL2の/mnt/c/ではinotifywaitが動かないため）
INBOX_LINUX_DIR="$HOME/.local/share/multi-agent-captain/inbox"
if [ ! -L ./queue/inbox ]; then
    mkdir -p "$INBOX_LINUX_DIR"
    [ -d ./queue/inbox ] && cp ./queue/inbox/*.yaml "$INBOX_LINUX_DIR/" 2>/dev/null && rm -rf ./queue/inbox
    ln -sf "$INBOX_LINUX_DIR" ./queue/inbox
    log_info "  └─ inbox → Linux FS ($INBOX_LINUX_DIR) にシンボリックリンク作成"
fi

if [ "$CLEAN_MODE" = true ]; then
    log_info "📜 前回の作戦記録を破棄中..."

    # 全隊のエージェントIDリスト
    ALL_SQUAD_AGENTS=(
        darjeeling pekoe hana rosehip marie oshida andou
        katyusha nonna klara mako erwin caesar saori
        kay arisa naomi anchovy pepperoni carpaccio yukari
        maho erika mika aki mikko kinuyo fukuda
    )

    # タスクファイルリセット（キャラクター名ベース）
    for agent in "${ALL_SQUAD_AGENTS[@]}"; do
        cat > "./queue/tasks/${agent}.yaml" << EOF
# ${agent}専用タスクファイル
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
    done

    # レポートファイルリセット（キャラクター名ベース）
    for agent in "${ALL_SQUAD_AGENTS[@]}"; do
        cat > "./queue/reports/${agent}_report.yaml" << EOF
worker_id: ${agent}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    done

    # ntfy inbox リセット
    echo "inbox:" > ./queue/ntfy_inbox.yaml

    # agent inbox リセット（司令部 + 全隊）
    for agent in anzu miho "${ALL_SQUAD_AGENTS[@]}"; do
        echo "messages:" > "./queue/inbox/${agent}.yaml"
    done

    log_success "✅ 撤収完了"
else
    log_info "📜 前回の隊容を維持して発進..."
    log_success "✅ キュー・報告ファイルはそのまま継続"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: ダッシュボード初期化（--clean時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$CLEAN_MODE" = true ]; then
    log_info "📊 戦況報告板を初期化中..."
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

    if [ "$LANG_SETTING" = "ja" ]; then
        # 日本語のみ
        cat > ./dashboard.md << EOF
# 📊 戦況報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 司令官のご判断をお待ちしております
なし

## 🔄 進行中 - 只今、作業中
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 確認事項
なし
EOF
    else
        # 日本語 + 翻訳併記
        cat > ./dashboard.md << EOF
# 📊 戦況報告 (Battle Status Report)
最終更新 (Last Updated): ${TIMESTAMP}

## 🚨 要対応 - 司令官のご判断をお待ちしております (Action Required - Awaiting Lord's Decision)
なし (None)

## 🔄 進行中 - 只今、作業中 (In Progress - Currently in Battle)
なし (None)

## ✅ 本日の戦果 (Today's Achievements)
| 時刻 (Time) | 戦場 (Battlefield) | 任務 (Mission) | 結果 (Result) |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち (Skill Candidates - Pending Approval)
なし (None)

## 🛠️ 生成されたスキル (Generated Skills)
なし (None)

## ⏸️ 待機中 (On Standby)
なし (None)

## ❓ 確認事項 (Questions for Lord)
なし (None)
EOF
    fi

    log_success "  └─ ダッシュボード初期化完了 (言語: $LANG_SETTING, シェル: $SHELL_SETTING)"
else
    log_info "📊 前回のダッシュボードを維持"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: tmux の存在確認
# ═══════════════════════════════════════════════════════════════════════════════
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  tmux が見つかりません                                 ║"
    echo "  ╠════════════════════════════════════════════════════════╣"
    echo "  ║  Run first_setup.sh first:                            ║"
    echo "  ║  まず first_setup.sh を実行してください:               ║"
    echo "  ║     ./first_setup.sh                                  ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: 司令部（command）セッション作成（大隊長 + 参謀長の2ペイン）
# ═══════════════════════════════════════════════════════════════════════════════
log_war "👑 司令部を構築中..."

# command セッションがなければ作る（-s 時もここで必ず command が存在するようにする）
# window 0 のみ作成し -n main で名前付け（第二 window にするとアタッチ時に空ペインが開くため 1 window に限定）
if ! tmux has-session -t command 2>/dev/null; then
    tmux new-session -d -s command -n main
fi

# 大隊長ペインはウィンドウ名 "main" で指定（base-index 1 環境でも動く）
ANZU_PROMPT=$(generate_prompt "大隊長" "magenta" "$SHELL_SETTING")
tmux send-keys -t command:main "cd \"$(pwd)\" && export PS1='${ANZU_PROMPT}' && clear" Enter
tmux select-pane -t command:main -P 'bg=#002b36'  # 大隊長の Solarized Dark
tmux set-option -p -t command:main @agent_id "anzu"
tmux set-option -p -t command:main @agent_role "battalion_commander"

log_success "  └─ 大隊長の本隊、構築完了"

# 参謀長（miho）ペイン作成
tmux split-window -h -t command:main
tmux set-option -p -t command:main.1 @agent_id miho
tmux set-option -p -t command:main.1 @agent_role chief_of_staff
tmux select-pane -t command:main.1 -P 'bg=#1a1a2e'
MIHO_PROMPT=$(generate_prompt "参謀長" "cyan" "$SHELL_SETTING")
tmux send-keys -t command:main.1 "cd \"$(pwd)\" && export PS1='${MIHO_PROMPT}' && clear" Enter

echo ""

# pane-base-index を取得（1 の環境ではペインは 1,2,... になる）
PANE_BASE=$(tmux show-options -gv pane-base-index 2>/dev/null || echo 0)

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Claude Code 起動（-s / --setup-only のときはスキップ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = false ]; then
    # CLI の存在チェック（Multi-CLI対応）
    if [ "$CLI_ADAPTER_LOADED" = true ]; then
        _default_cli=$(get_cli_type "")
        if ! validate_cli_availability "$_default_cli"; then
            exit 1
        fi
    else
        if ! command -v claude &> /dev/null; then
            log_info "⚠️  claude コマンドが見つかりません"
            echo "  first_setup.sh を再実行してください:"
            echo "    ./first_setup.sh"
            exit 1
        fi
    fi

    log_war "👑 全軍に Claude Code を召喚中..."

    # 大隊長（anzu）: CLI Adapter経由でコマンド構築
    _anzu_cli_type="claude"
    _anzu_cmd="claude --model opus --dangerously-skip-permissions"
    if [ "$CLI_ADAPTER_LOADED" = true ]; then
        _anzu_cli_type=$(get_cli_type "anzu")
        _anzu_cmd=$(build_cli_command "anzu")
    fi
    # 大隊長（anzu）ペインに明示的に送信（.${PANE_BASE}でpane-base-index対応）
    tmux set-option -p -t "command:main.${PANE_BASE}" @agent_cli "$_anzu_cli_type"
    if [ "$CAPTAIN_NO_THINKING" = true ] && [ "$_anzu_cli_type" = "claude" ]; then
        tmux send-keys -t "command:main.${PANE_BASE}" "MAX_THINKING_TOKENS=0 $_anzu_cmd"
        sleep 0.3
        tmux send-keys -t "command:main.${PANE_BASE}" Enter
        log_info "  └─ 大隊長（${_anzu_cli_type} / thinking無効）、召喚完了"
    else
        tmux send-keys -t "command:main.${PANE_BASE}" "$_anzu_cmd"
        sleep 0.3
        tmux send-keys -t "command:main.${PANE_BASE}" Enter
        log_info "  └─ 大隊長（${_anzu_cli_type}）、召喚完了"
    fi

    # 参謀長（miho）: CLI Adapter経由でコマンド構築
    _miho_cli_type="claude"
    _miho_cmd="claude --model opus --dangerously-skip-permissions"
    if [ "$CLI_ADAPTER_LOADED" = true ]; then
        _miho_cli_type=$(get_cli_type "miho")
        _miho_cmd=$(build_cli_command "miho")
    fi
    # 参謀長ペインに明示的に送信（PANE_BASE+1でpane-base-index対応）
    _miho_pane=$((PANE_BASE + 1))
    tmux set-option -p -t "command:main.${_miho_pane}" @agent_cli "$_miho_cli_type"
    tmux send-keys -t "command:main.${_miho_pane}" "$_miho_cmd"
    sleep 0.3
    tmux send-keys -t "command:main.${_miho_pane}" Enter
    log_info "  └─ 参謀長（${_miho_cli_type}）、召喚完了"

    # 少し待機（安定のため）
    sleep 1

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.5: 各エージェントに指示書を読み込ませる
    # ═══════════════════════════════════════════════════════════════════════════
    log_war "📜 各エージェントに指示書を読み込ませ中..."
    echo ""

    echo ""
    echo -e "                                    \033[1;35m「 パンツァー・フォー！ 」\033[0m"
    echo ""
    echo -e "                               \033[0;36m[ASCII Art: syntax-samurai/ryu - CC0 1.0 Public Domain]\033[0m"
    echo ""

    echo "  Claude Code の起動を待機中（最大30秒）..."

    # 大隊長の起動を確認（最大30秒待機）
    for i in {1..30}; do
        if tmux capture-pane -t "command:main.${PANE_BASE}" -p | grep -q "bypass permissions"; then
            echo "  └─ 大隊長の Claude Code 起動確認完了（${i}秒）"
            break
        fi
        sleep 1
    done

    # ═══════════════════════════════════════════════════════════════════
    # STEP 6.6: watcher_supervisor起動（全エージェント自動検出・管理）
    # ═══════════════════════════════════════════════════════════════════
    log_info "📬 メールボックス監視を起動中..."

    # inbox ディレクトリ初期化（シンボリックリンク先のLinux FSに作成）
    mkdir -p "$SCRIPT_DIR/logs"
    for agent in anzu miho \
        darjeeling pekoe hana rosehip marie oshida andou \
        katyusha nonna klara mako erwin caesar saori \
        kay arisa naomi anchovy pepperoni carpaccio yukari \
        maho erika mika aki mikko kinuyo fukuda; do
        [ -f "$SCRIPT_DIR/queue/inbox/${agent}.yaml" ] || echo "messages:" > "$SCRIPT_DIR/queue/inbox/${agent}.yaml"
    done

    # 既存のwatcherと孤児inotifywaitをkill（クラスタ起動前にクリーンアップ）
    pkill -f "inbox_watcher.sh" 2>/dev/null || true
    pkill -f "watcher_supervisor.sh" 2>/dev/null || true
    pkill -f "inotifywait.*queue/inbox" 2>/dev/null || true
    sleep 1

    # STEP 6.7 は廃止 — CLAUDE.md Session Start (step 1: tmux agent_id) で各自が自律的に
    # 自分のinstructions/*.mdを読み込む。検証済み (2026-02-08)。
    log_info "📜 指示書読み込みは各エージェントが自律実行（CLAUDE.md Session Start）"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.7.5: 各隊クラスタ起動（デフォルト起動時）
    # ═══════════════════════════════════════════════════════════════════════════
    log_war "🫖 ダージリン隊クラスタも起動中..."
    launch_darjeeling_cluster
    log_war "🪆 カチューシャ隊クラスタも起動中..."
    launch_katyusha_cluster
    log_war "🦅 ケイ隊クラスタも起動中..."
    launch_kay_cluster
    log_war "🖤 西住まほ隊クラスタも起動中..."
    launch_maho_cluster

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.6: watcher_supervisor起動（全隊のClaude Code起動完了後）
    # ═══════════════════════════════════════════════════════════════════════════
    # NOTE: 以前はクラスタ起動前にwatcher_supervisorを起動していたが、
    # inbox_watcherがClaude Code起動前にペインにアクセスし、競合が発生していた。
    # 全クラスタのClaude Code起動完了後にwatcher_supervisorを起動することで解決。
    log_info "📬 メールボックス監視を起動中..."
    echo "[STEP 6.6] Starting watcher_supervisor (after all clusters ready)..."
    nohup bash "$SCRIPT_DIR/scripts/watcher_supervisor.sh" \
        >> "$SCRIPT_DIR/logs/watcher_supervisor.log" 2>&1 &
    disown
    log_success "  └─ watcher_supervisor起動完了（全エージェント自動管理）"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6.8: ntfy入力リスナー起動
# ═══════════════════════════════════════════════════════════════════════════════
NTFY_TOPIC=$(grep 'ntfy_topic:' ./config/settings.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')
if [ -n "$NTFY_TOPIC" ]; then
    pkill -f "ntfy_listener.sh" 2>/dev/null || true
    [ ! -f ./queue/ntfy_inbox.yaml ] && echo "inbox:" > ./queue/ntfy_inbox.yaml
    nohup bash "$SCRIPT_DIR/scripts/ntfy_listener.sh" &>/dev/null &
    disown
    log_info "📱 ntfy入力リスナー起動 (topic: $NTFY_TOPIC)"
else
    log_info "📱 ntfy未設定のためリスナーはスキップ"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: 環境確認・完了メッセージ
# ═══════════════════════════════════════════════════════════════════════════════
log_info "🔍 隊容を確認中..."
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📺 Tmux隊容 (Sessions)                                  │"
echo "  └──────────────────────────────────────────────────────────┘"
tmux list-sessions | sed 's/^/     /'
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  📋 布隊図 (Formation)                                   │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "     【commandセッション】司令部（2ペイン）"
echo "     ┌──────────────────┬──────────────────┐"
echo "     │ anzu (大隊長)    │ miho (参謀長)    │"
echo "     └──────────────────┴──────────────────┘"
echo ""
echo "     【darjeelingセッション】ダージリン隊（7ペイン）"
echo "     ┌──────────┬──────────┐"
echo "     │darjeeling│  marie   │"
echo "     │ (隊長)   │ (隊員3)  │"
echo "     ├──────────┤──────────┤"
echo "     │  pekoe   │ oshida   │"
echo "     │(副隊長)  │ (隊員4)  │"
echo "     ├──────────┤──────────┤"
echo "     │  hana    │ andou    │"
echo "     │ (隊員1)  │ (隊員5)  │"
echo "     ├──────────┘          │"
echo "     │ rosehip             │"
echo "     │ (隊員2)             │"
echo "     └─────────────────────┘"
echo ""
echo "     ※ katyusha / kay / maho 隊も同一レイアウト（7ペイン×4隊）"
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 発進準備完了！パンツァー・フォー！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

if [ "$SETUP_ONLY" = true ]; then
    echo "  ⚠️  セットアップのみモード: Claude Codeは未起動です"
    echo ""
    echo "  手動でClaude Codeを起動するには:"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  # 隊長を召喚                                            │"
    echo "  │  tmux send-keys -t command:main \\                         │"
    echo "  │    'claude --dangerously-skip-permissions' Enter         │"
    echo "  │                                                          │"
    echo "  │  # 副隊長・隊員を一斉召喚                                  │"
    echo "  │  for p in \$(seq $PANE_BASE $((PANE_BASE+8))); do                                 │"
    echo "  │      tmux send-keys -t darjeeling:agents.\$p \\            │"
    echo "  │      'claude --dangerously-skip-permissions' Enter       │"
    echo "  │  done                                                    │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
fi

echo "  次のステップ:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  司令部にアタッチして命令を開始:                          │"
echo "  │     tmux attach-session -t command   (または: css)        │"
echo "  │                                                          │"
echo "  │  ダージリン隊を確認する:                                  │"
echo "  │     tmux attach -t darjeeling (または: csm)               │"
echo "  │  カチューシャ隊を確認する:                               │"
echo "  │     tmux attach -t katyusha                              │"
echo "  │  ケイ隊を確認する:                                       │"
echo "  │     tmux attach -t kay                                   │"
echo "  │  西住まほ隊を確認する:                                   │"
echo "  │     tmux attach -t maho                                  │"
echo "  │                                                          │"
echo "  │  ※ 各エージェントは指示書を読み込み済み。                 │"
echo "  │    すぐに命令を開始できます。                             │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   パンツァー・フォー！勝利を掴め！"
echo "  ════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Windows Terminal でタブを開く（-t オプション時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$OPEN_TERMINAL" = true ]; then
    log_info "📺 Windows Terminal でタブを展開中..."

    # Windows Terminal が利用可能か確認
    if command -v wt.exe &> /dev/null; then
        wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t command" \; new-tab wsl.exe -e bash -c "tmux attach-session -t darjeeling"
        log_success "  └─ ターミナルタブ展開完了"
    else
        log_info "  └─ wt.exe が見つかりません。手動でアタッチしてください。"
    fi
    echo ""
fi
