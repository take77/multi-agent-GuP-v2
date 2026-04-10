#!/usr/bin/env bash
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
source "$SCRIPT_DIR/lib/launch_common.sh"
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
AGENT_TEAMS_MODE=false
WORKTREE_MODE=false        # --worktree: 各隊のworktreeを自動セットアップ
WORKTREE_CMD_ID=""         # --worktree <cmd_id>: worktreeに紐づけるcmd番号
WEB_MODE=false

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
            echo "  --worktree [cmd_id] 各隊のworktreeを自動セットアップ（scripts/worktree_manager.sh が必要）"
            echo "                      cmd_idを省略した場合はcaptain_queueの最新IDを使用"
            echo "  --command           司令部サーバーのみ起動（大隊長+参謀長の2ペイン）"
            echo "                      デフォルトtmuxサーバーにcommandセッションとして起動"
            echo "  --all-clusters      全クラスタ起動（将来用、現在はスタブ）"
            echo "  --web               Web UI を起動（http://localhost:3000）"
            echo "                      tmuxセッション起動後、cd web && npm run dev をバックグラウンド実行"
            echo "  --agent-teams       Agent Teams モード有効化（Phase 0適用が前提）"
            echo "                      参謀長モニタプロセスを起動し、YAML↔Agent Teams双方向連携を有効化"
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
            echo "  隊長:          Opus"
            echo "  隊員1-6:       Sonnet"
            echo ""
            echo "隊形:"
            echo "  平時の隊（デフォルト）: 隊員1-6=Sonnet"
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
        --worktree)
            WORKTREE_MODE=true
            if [[ -n "$2" && "$2" != -* ]]; then
                WORKTREE_CMD_ID="$2"
                shift 2
            else
                shift
            fi
            ;;
        --web)
            WEB_MODE=true
            shift
            ;;
        --agent-teams)
            echo "⚠️  Agent Teams モードは gup_v2_launch_hybrid.sh を使用してください"
            echo "  ./gup_v2_launch_hybrid.sh $*"
            exit 1
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
# ダージリン隊クラスタ起動関数
# ═══════════════════════════════════════════════════════════════════════════════
launch_darjeeling_cluster() {
    launch_squad_cluster "darjeeling" "🫖" "ダージリン隊" \
        "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
        "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue"
}
setup_darjeeling_cluster() {
    setup_squad_cluster "darjeeling" "🫖" "ダージリン隊" \
        "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
        "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue" "$AGENT_TEAMS_MODE"
}
start_darjeeling_claude() {
    start_squad_claude "darjeeling" "🫖" "ダージリン隊" \
        "darjeeling,pekoe,hana,rosehip,marie,oshida,andou" \
        "ダージリン,オレンジペコ,五十鈴華,ローズヒップ,マリー,押田,安藤" \
        "captain,vice_captain,member,member,member,member,member" \
        "$AGENT_TEAMS_MODE"
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
setup_katyusha_cluster() {
    setup_squad_cluster "katyusha" "🪆" "カチューシャ隊" \
        "katyusha,nonna,klara,mako,erwin,caesar,saori" \
        "カチューシャ,ノンナ,クラーラ,冷泉麻子,エルヴィン,カエサル,武部沙織" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue" "$AGENT_TEAMS_MODE"
}
start_katyusha_claude() {
    start_squad_claude "katyusha" "🪆" "カチューシャ隊" \
        "katyusha,nonna,klara,mako,erwin,caesar,saori" \
        "カチューシャ,ノンナ,クラーラ,冷泉麻子,エルヴィン,カエサル,武部沙織" \
        "captain,vice_captain,member,member,member,member,member" \
        "$AGENT_TEAMS_MODE"
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
setup_kay_cluster() {
    setup_squad_cluster "kay" "🦅" "ケイ隊" \
        "kay,arisa,naomi,anchovy,pepperoni,carpaccio,yukari" \
        "ケイ,アリサ,ナオミ,アンチョビ,ペパロニ,カルパッチョ,秋山優花里" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue" "$AGENT_TEAMS_MODE"
}
start_kay_claude() {
    start_squad_claude "kay" "🦅" "ケイ隊" \
        "kay,arisa,naomi,anchovy,pepperoni,carpaccio,yukari" \
        "ケイ,アリサ,ナオミ,アンチョビ,ペパロニ,カルパッチョ,秋山優花里" \
        "captain,vice_captain,member,member,member,member,member" \
        "$AGENT_TEAMS_MODE"
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
setup_maho_cluster() {
    setup_squad_cluster "maho" "🖤" "西住まほ隊" \
        "maho,erika,mika,aki,mikko,kinuyo,fukuda" \
        "西住まほ,逸見エリカ,ミカ,アキ,ミッコ,西絹代,福田" \
        "captain,vice_captain,member,member,member,member,member" \
        "magenta,red,blue,blue,blue,blue,blue" "$AGENT_TEAMS_MODE"
}
start_maho_claude() {
    start_squad_claude "maho" "🖤" "西住まほ隊" \
        "maho,erika,mika,aki,mikko,kinuyo,fukuda" \
        "西住まほ,逸見エリカ,ミカ,アキ,ミッコ,西絹代,福田" \
        "captain,vice_captain,member,member,member,member,member" \
        "$AGENT_TEAMS_MODE"
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
    cleanup_stale_processes
    launch_command_server
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# クラスタモード分岐（--cluster オプション指定時）
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$CLUSTER_MODE" ]; then
    cleanup_stale_processes
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
            log_info "🌐 クラスタモード: 全クラスタ並列起動"
            check_dependencies
            _par_dir=$(mktemp -d)
            trap "rm -rf '$_par_dir'" EXIT
            launch_darjeeling_cluster > "$_par_dir/darjeeling.log" 2>&1 &
            launch_katyusha_cluster  > "$_par_dir/katyusha.log"  2>&1 &
            launch_kay_cluster       > "$_par_dir/kay.log"       2>&1 &
            launch_maho_cluster      > "$_par_dir/maho.log"      2>&1 &
            wait
            for _cn in darjeeling katyusha kay maho; do
                echo "  ┌── ${_cn} ──"
                cat "$_par_dir/${_cn}.log" | sed 's/^/  │ /'
                echo "  └──"
            done
            rm -rf "$_par_dir"
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
    if [ -f "./queue/captain_queue.yaml" ]; then
        if grep -q "id: cmd_" "./queue/captain_queue.yaml" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    if [ "$NEED_BACKUP" = true ]; then
        mkdir -p "$BACKUP_DIR" || true
        cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
        cp -r "./queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
        cp "./queue/captain_queue.yaml" "$BACKUP_DIR/" 2>/dev/null || true
        log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: キューディレクトリ確保 + リセット（--clean時のみリセット）
# ═══════════════════════════════════════════════════════════════════════════════

# queue ディレクトリが存在しない場合は作成（初回起動時に必要）
[ -d ./queue/reports ] || mkdir -p ./queue/reports
[ -d ./queue/tasks ] || mkdir -p ./queue/tasks

# inbox ディレクトリ処理（OS別）
OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: 通常のディレクトリを使用
    [ -d ./queue/inbox ] || mkdir -p ./queue/inbox
else
    # Linux/WSL2: Linux FSにシンボリックリンク（WSL2の/mnt/c/ではinotifywaitが動かないため）
    INBOX_LINUX_DIR="$HOME/.local/share/multi-agent-captain/inbox"
    if [ ! -L ./queue/inbox ]; then
        mkdir -p "$INBOX_LINUX_DIR"
        [ -d ./queue/inbox ] && cp ./queue/inbox/*.yaml "$INBOX_LINUX_DIR/" 2>/dev/null && rm -rf ./queue/inbox
        ln -sf "$INBOX_LINUX_DIR" ./queue/inbox
        log_info "  └─ inbox → Linux FS ($INBOX_LINUX_DIR) にシンボリックリンク作成"
    fi
fi

# アーカイブディレクトリ確保
mkdir -p queue/inbox/archive

# inbox 既読メッセージアーカイブ（エージェント起動前に実行）
log_info "📦 Archiving read inbox messages..."
if [ -f scripts/inbox_archive.sh ]; then
    bash scripts/inbox_archive.sh
fi

# stale ロックファイル除去（inbox_write.sh の flock 残骸をクリーンアップ）
log_info "🔓 Cleaning stale lock files..."
if [ -f scripts/clean_stale_locks.sh ]; then
    bash scripts/clean_stale_locks.sh
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
# STEP 4.5: Agent Teams 環境チェック（--agent-teams 指定時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$AGENT_TEAMS_MODE" = true ]; then
    log_info "🔍 Agent Teams 環境チェック中..."

    AGENT_TEAMS_READY=true

    # (1) CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 環境変数チェック
    # OS環境変数が未設定の場合、.claude/settings.json から読み取り
    if [ -z "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]; then
        SETTINGS_FILE="$SCRIPT_DIR/.claude/settings.json"
        if [ -f "$SETTINGS_FILE" ]; then
            # jq が使える場合は jq、なければ grep+sed で取得
            if command -v jq >/dev/null 2>&1; then
                AT_ENV=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' "$SETTINGS_FILE" 2>/dev/null)
            else
                AT_ENV=$(grep -o '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)"/\1/')
            fi
            if [ -n "$AT_ENV" ]; then
                export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="$AT_ENV"
                log_success "  ✅ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: .claude/settings.json から取得 ($AT_ENV)"
            else
                log_war "  ⚠️  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 環境変数が未設定"
                AGENT_TEAMS_READY=false
            fi
        else
            log_war "  ⚠️  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 環境変数が未設定（.claude/settings.json も不在）"
            AGENT_TEAMS_READY=false
        fi
    else
        log_success "  ✅ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 環境変数: 設定済み"
    fi

    # (2) Phase 0 適用チェック（scripts/check_inbox_on_stop.sh の存在確認）
    if [ ! -f "$SCRIPT_DIR/scripts/check_inbox_on_stop.sh" ]; then
        log_war "  ⚠️  Phase 0 未適用: scripts/check_inbox_on_stop.sh が見つかりません"
        AGENT_TEAMS_READY=false
    else
        log_success "  ✅ Phase 0 適用済み: scripts/check_inbox_on_stop.sh 確認"
    fi

    # (3) Node.js 存在チェック
    if ! command -v node >/dev/null 2>&1; then
        log_war "  ⚠️  Node.js が見つかりません（参謀長モニタ起動不可）"
        AGENT_TEAMS_READY=false
    else
        NODE_VERSION=$(node --version 2>/dev/null)
        log_success "  ✅ Node.js 確認: $NODE_VERSION"
    fi

    # 全チェック失敗時はフォールバック
    if [ "$AGENT_TEAMS_READY" = false ]; then
        log_war "  ⚠️  Agent Teams 環境チェック失敗 → AGENT_TEAMS_MODE=false にフォールバック"
        AGENT_TEAMS_MODE=false
    else
        log_success "  ✅ Agent Teams 環境チェック完了"
    fi
    echo ""
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

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5.5: Agent Teams 設定追加（--agent-teams 指定時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$AGENT_TEAMS_MODE" = true ]; then
    log_info "🔗 Agent Teams モード設定中..."

    # (1) tmux 環境変数設定
    tmux set-environment -t command GUP_AGENT_TEAMS_ACTIVE 1
    log_success "  ✅ GUP_AGENT_TEAMS_ACTIVE=1 設定完了"

    # (2) 参謀長モニタプロセスをバックグラウンド起動
    # 既存モニタープロセスがあれば停止してから新規起動
    _existing_monitor_pid=$(tmux show-environment -t command GUP_MONITOR_PID 2>/dev/null | sed 's/.*=//')
    if [ -n "$_existing_monitor_pid" ] && kill -0 "$_existing_monitor_pid" 2>/dev/null; then
        kill "$_existing_monitor_pid" 2>/dev/null || true
        wait "$_existing_monitor_pid" 2>/dev/null || true
        log_info "  └─ 既存モニタープロセス(PID: $_existing_monitor_pid)を停止"
    fi
    if [ -d "$SCRIPT_DIR/scripts/monitor" ] && [ -f "$SCRIPT_DIR/scripts/monitor/start.ts" ]; then
        cd "$SCRIPT_DIR/scripts/monitor"
        npx tsx start.ts >> "$SCRIPT_DIR/logs/monitor.log" 2>&1 &
        MONITOR_PID=$!
        cd "$SCRIPT_DIR"

        tmux set-environment -t command GUP_MONITOR_PID "$MONITOR_PID"
        log_success "  ✅ 参謀長モニタプロセス起動完了（PID: $MONITOR_PID）"
    else
        log_war "  ⚠️  scripts/monitor/start.ts が見つかりません（モニタ起動スキップ）"
    fi

    echo ""
fi

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
    # モデル: opus（config/settings.yaml cli.agents.miho.model で設定）
    # 理由: 施策分配判断、worktreeマージ管理、品質ゲート機能に高い推論能力が必要
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
    # NOTE: "bypass permissions" は --dangerously-skip-permissions 使用時に表示されない。
    # Claude Code の入力プロンプト "❯" を検知する方式に変更（全モードで共通）。
    for i in {1..30}; do
        if tmux capture-pane -t "command:main.${PANE_BASE}" -p | grep -qE '❯|bypass permissions'; then
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
    cleanup_stale_processes

    # STEP 6.7 は廃止 — CLAUDE.md Session Start (step 1: tmux agent_id) で各自が自律的に
    # 自分のinstructions/*.mdを読み込む。検証済み (2026-02-08)。
    log_info "📜 指示書読み込みは各エージェントが自律実行（CLAUDE.md Session Start）"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.7.5: 各隊クラスタ起動（フェーズ1: 順次setup → フェーズ2: 並列Claude召喚）
    # ═══════════════════════════════════════════════════════════════════════════
    # フェーズ1: セッション作成・ペイン分割を順次実行（メインプロセスから呼ぶのでtmuxがターミナルサイズを正しく検出）
    log_war "🏗️ 全4隊クラスタを構築中（順次）..."
    setup_darjeeling_cluster
    setup_katyusha_cluster
    setup_kay_cluster
    setup_maho_cluster
    log_success "✅ 全4隊クラスタ構築完了"

    # ═══════════════════════════════════════════════════════════════════════════
    # STEP 6.7.6: Worktree 自動セットアップ（--worktree 指定時のみ）
    # ═══════════════════════════════════════════════════════════════════════════
    if [ "$WORKTREE_MODE" = true ]; then
        if [ -f "$SCRIPT_DIR/scripts/worktree_manager.sh" ]; then
            log_info "🌿 Worktree自動セットアップを実行中..."

            # cmd_id が省略された場合は captain_queue.yaml の最新IDを取得
            _wt_cmd_id="$WORKTREE_CMD_ID"
            if [ -z "$_wt_cmd_id" ]; then
                _wt_cmd_id=$(grep -oE 'id: cmd_[0-9]+' "$SCRIPT_DIR/queue/captain_queue.yaml" 2>/dev/null | tail -1 | awk '{print $2}' || echo "")
            fi

            if [ -z "$_wt_cmd_id" ]; then
                log_war "  ⚠️  cmd_idが不明のためworktreeセットアップをスキップ（--worktree <cmd_id> で指定してください）"
            else
                for _wt_cluster in darjeeling katyusha kay maho; do
                    if bash "$SCRIPT_DIR/scripts/worktree_manager.sh" create "$_wt_cluster" "$_wt_cmd_id"; then
                        log_success "  └─ ${_wt_cluster}: worktree作成完了"
                    else
                        log_war "  └─ ${_wt_cluster}: worktree作成失敗（スキップ）"
                    fi
                done
                log_success "✅ Worktree自動セットアップ完了 (cmd_id: ${_wt_cmd_id})"
            fi
        else
            log_war "  ⚠️  scripts/worktree_manager.sh が見つかりません（worktreeセットアップをスキップ）"
            log_war "  ⚠️  scripts/worktree_manager.sh を作成後に再実行してください"
        fi
    fi

    # フェーズ2: Claude Code召喚を並列実行（セッションは既存のため端末サイズ問題なし）
    log_war "⚡ 全4隊Claude Codeを並列召喚中..."

    # 一時ディレクトリ（ログバッファ用）
    _parallel_log_dir=$(mktemp -d)
    trap "rm -rf '$_parallel_log_dir'" EXIT

    start_darjeeling_claude > "$_parallel_log_dir/darjeeling.log" 2>&1 &
    _pid_darjeeling=$!
    start_katyusha_claude   > "$_parallel_log_dir/katyusha.log"  2>&1 &
    _pid_katyusha=$!
    start_kay_claude        > "$_parallel_log_dir/kay.log"       2>&1 &
    _pid_kay=$!
    start_maho_claude       > "$_parallel_log_dir/maho.log"      2>&1 &
    _pid_maho=$!

    # 全隊のClaude召喚完了を待機
    _parallel_fail=0
    for _pid_label in "darjeeling:$_pid_darjeeling" "katyusha:$_pid_katyusha" "kay:$_pid_kay" "maho:$_pid_maho"; do
        _label="${_pid_label%%:*}"
        _pid="${_pid_label##*:}"
        if ! wait "$_pid"; then
            log_error "  └─ ${_label} Claude召喚失敗"
            _parallel_fail=1
        fi
    done

    # 各隊のログをまとめて表示（混在防止）
    for _cluster_name in darjeeling katyusha kay maho; do
        echo ""
        echo "  ┌── ${_cluster_name} ──"
        sed 's/^/  │ /' "$_parallel_log_dir/${_cluster_name}.log"
        echo "  └──"
    done
    rm -rf "$_parallel_log_dir"

    if [ "$_parallel_fail" -eq 1 ]; then
        log_error "一部クラスタのClaude召喚に失敗しました"
        exit 1
    fi

    log_success "✅ 全4隊Claude Code並列召喚完了"

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
echo "     │ (隊長)   │ (隊員4)  │"
echo "     ├──────────┤──────────┤"
echo "     │  pekoe   │ oshida   │"
echo "     │ (隊員1)  │ (隊員5)  │"
echo "     ├──────────┤──────────┤"
echo "     │  hana    │ andou    │"
echo "     │ (隊員2)  │ (隊員6)  │"
echo "     ├──────────┘          │"
echo "     │ rosehip             │"
echo "     │ (隊員3)             │"
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
# STEP 8: Web UI 起動（--web オプション時のみ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$WEB_MODE" = true ]; then
    log_info "🌐 Web UI を起動中..."
    mkdir -p "$SCRIPT_DIR/logs/structured"
    (cd "$SCRIPT_DIR/web" && npm run dev > "$SCRIPT_DIR/logs/structured/web_dev.log" 2>&1 &)
    log_success "  └─ Web UI 起動完了: http://localhost:3000"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 9: Windows Terminal でタブを開く（-t オプション時のみ）
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
