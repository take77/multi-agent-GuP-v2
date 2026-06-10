#!/usr/bin/env bash
# scripts/ratelimit_check.sh — CLI Rate Limit Monitor (GuP-v2)
# CLI種別ごとに重複排除し、共有クォータの消費状況を統合表示する。
#
# 対応データソース:
#   1. Claude OAuth Usage API: ~/.claude/.credentials.json → api.anthropic.com/api/oauth/usage
#   2. Claude stats-cache:     ~/.claude/stats-cache.json
#   3. Codex /status pane capture + ~/.codex/log/codex-tui.log (token_limit_reached)
#
# GuP-v2 固有:
#   - 28 エージェント対応（4隊 × (captain + vice_captain + 5 members) + 司令部 2名）
#   - CLUSTER_ID 環境変数によるマルチクラスタ pane 解決
#   - macOS (darwin) 専用。Linux フォールバックなし
#   - tmux pane が存在するエージェントのみ表示（不在はスキップ）
#
# Usage:
#   bash scripts/ratelimit_check.sh              # 日本語出力
#   bash scripts/ratelimit_check.sh --lang en    # English output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Defaults ───
LANG_MODE="ja"

# ─── Parse args ───
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)  LANG_MODE="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: ratelimit_check.sh [--lang en|ja]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ─── Load shared libraries ───
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/agent_status.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/cli_adapter.sh"

# python3 は system にあるものを使う（.venv は GuP-v2 標準ではない）
PYTHON="${PYTHON:-python3}"

# ─── Constants ───
CLAUDE_STATS="$HOME/.claude/stats-cache.json"
CLAUDE_CREDS="$HOME/.claude/.credentials.json"
CODEX_LOG="$HOME/.codex/log/codex-tui.log"
TODAY=$(date +%Y-%m-%d)

# Warning thresholds
CODEX_CONTEXT_WARN=20
CODEX_CONTEXT_CRIT=10
CODEX_LIMIT_HITS_WARN=3

# ─── Agent list (dynamic from config/squads.yaml + agents.yaml) ───
# HQ: anzu (battalion_commander) + miho (chief_of_staff)
# 4 squads: captain + vice_captain + 5 members each
ALL_AGENTS=("anzu" "miho")
_squad_ids_str=$(get_squad_member_ids 2>/dev/null || echo "")
if [[ -n "$_squad_ids_str" ]]; then
    for _aid in $_squad_ids_str; do
        ALL_AGENTS+=("$_aid")
    done
else
    # Fallback (squads.yaml read failure): 28 agents hardcoded
    ALL_AGENTS+=(
        darjeeling pekoe hana rosehip marie andou oshida
        katyusha nonna klara mako erwin caesar saori
        kay arisa naomi yukari anchovy carpaccio pepperoni
        maho erika mika aki mikko kinuyo fukuda
    )
fi

# ═══════════════════════════════════════════════════════
# Phase 1: Scan all tmux panes for metadata
# ═══════════════════════════════════════════════════════
declare -A AGENT_CLI AGENT_MODEL AGENT_PANE

for agent in "${ALL_AGENTS[@]}"; do
    # _find_pane_for_agent は CLUSTER_ID プレフィックスを考慮する
    pane_target=$(_find_pane_for_agent "$agent" 2>/dev/null || echo "")

    # pane が存在しないエージェントは AGENT_PANE 未設定のまま（後段でスキップ）
    if [[ -z "$pane_target" ]]; then
        continue
    fi

    # Read pane metadata (fallback to cli_adapter)
    cli=$(get_pane_metadata "$pane_target" "agent_cli" 2>/dev/null || echo "")
    if [[ -z "$cli" ]]; then
        cli=$(get_cli_type "$agent" 2>/dev/null || echo "?")
    fi

    model=$(get_pane_metadata "$pane_target" "model_name" 2>/dev/null || echo "")
    if [[ -z "$model" ]]; then
        model=$(get_agent_model "$agent" 2>/dev/null || echo "?")
    fi
    # Shorten long model names for display (e.g., "claude-sonnet-4-6" → "sonnet")
    # Also strip ANSI escape leftovers / literal "[1m]" artifacts that may leak from upstream config.
    model=$(printf '%s' "$model" | sed -E 's/\x1b?\[[0-9;]*[mK]\]?//g; s/[Cc]laude-?//g; s/-20[0-9]{6}//g; s/-[0-9]+-[0-9]+$//; s/^-//')

    AGENT_CLI["$agent"]="$cli"
    AGENT_MODEL["$agent"]="$model"
    AGENT_PANE["$agent"]="$pane_target"
done

# ═══════════════════════════════════════════════════════
# Phase 2: Group agents by CLI type (only panes that exist)
# ═══════════════════════════════════════════════════════
declare -a CLAUDE_AGENTS=() CODEX_AGENTS=() OTHER_AGENTS=()

for agent in "${ALL_AGENTS[@]}"; do
    # Skip agents without a tmux pane
    [[ -z "${AGENT_PANE[$agent]:-}" ]] && continue
    case "${AGENT_CLI[$agent]:-}" in
        claude) CLAUDE_AGENTS+=("$agent") ;;
        codex)  CODEX_AGENTS+=("$agent") ;;
        *)      OTHER_AGENTS+=("$agent") ;;
    esac
done

# ─── tmux pane capture helpers ───

capture_tmux_pane_zoomed() {
    local pane="$1"
    local start="${2:--80}"
    local restore_zoom=false
    local was_zoomed="0"
    local out=""

    was_zoomed=$(timeout 2 tmux display-message -t "$pane" -p '#{window_zoomed_flag}' 2>/dev/null || echo "0")
    if [[ "$was_zoomed" != "1" ]]; then
        tmux resize-pane -t "$pane" -Z 2>/dev/null || true
        restore_zoom=true
        sleep 0.2
    fi

    out=$(tmux capture-pane -t "$pane" -p -J -S "$start" 2>/dev/null || echo "")

    if $restore_zoom; then
        tmux resize-pane -t "$pane" -Z 2>/dev/null || true
    fi

    printf '%s' "$out"
}

capture_codex_status_snapshot() {
    local pane="$1"
    local restore_zoom=false
    local was_zoomed="0"
    local out=""

    was_zoomed=$(timeout 2 tmux display-message -t "$pane" -p '#{window_zoomed_flag}' 2>/dev/null || echo "0")
    if [[ "$was_zoomed" != "1" ]]; then
        tmux resize-pane -t "$pane" -Z 2>/dev/null || true
        restore_zoom=true
        sleep 0.2
    fi

    tmux send-keys -t "$pane" '/status' 2>/dev/null || true
    sleep 0.3
    tmux send-keys -t "$pane" Enter 2>/dev/null || true
    sleep 2

    out=$(tmux capture-pane -t "$pane" -p -J -S -80 2>/dev/null || echo "")

    if $restore_zoom; then
        tmux resize-pane -t "$pane" -Z 2>/dev/null || true
    fi

    printf '%s' "$out"
}

extract_latest_codex_status_block() {
    awk '
        />_ OpenAI Codex/ {
            capture = 1
            block = ""
        }
        capture {
            block = block $0 ORS
        }
        capture && /^╰/ {
            last = block
            capture = 0
        }
        END {
            printf "%s", last
        }
    ' <<< "$1"
}

extract_codex_context_left() {
    awk '
        /context left/ && match($0, /([0-9]+)%/, m) {
            context = m[1]
        }
        /Context window:/ && match($0, /([0-9]+)% left/, m) {
            fallback = m[1]
        }
        /[0-9]+% left/ && /·/ && match($0, /([0-9]+)% left/, m) {
            context = m[1]
        }
        END {
            if (context != "") {
                print context
            } else if (fallback != "") {
                print fallback
            }
        }
    ' <<< "$1"
}

normalize_reset_value() {
    local reset_value="${1:-}"

    if [[ -n "${reset_value//[[:space:]]/}" ]]; then
        printf '%s' "$reset_value"
    else
        printf 'unknown'
    fi
}

# ═══════════════════════════════════════════════════════
# Phase 3: Collect data per CLI group
# ═══════════════════════════════════════════════════════

# --- 3a: Claude OAuth usage API + stats-cache ---
CLAUDE_5H_UTIL=""
CLAUDE_5H_RESET=""
CLAUDE_7D_UTIL=""
CLAUDE_7D_RESET=""
CLAUDE_7D_SONNET_UTIL=""
CLAUDE_7D_OPUS_UTIL=""
CLAUDE_EXTRA_ENABLED="false"
CLAUDE_STATUS="OK"

# OAuth usage API (primary source — real subscription rate limits)
# 注: ~/.claude/.credentials.json の OAuth トークンは読み取りのみ。値はログ出力しない
if [[ ${#CLAUDE_AGENTS[@]} -gt 0 ]] && [[ -f "$CLAUDE_CREDS" ]] && command -v "$PYTHON" &>/dev/null; then
    oauth_data=$("$PYTHON" -c "
import json, subprocess, sys

try:
    with open('${CLAUDE_CREDS}') as f:
        creds = json.load(f)
    token = creds.get('claudeAiOauth', {}).get('accessToken', '')
    if not token:
        sys.exit(1)

    result = subprocess.run([
        'curl', '-s', '-m', '10',
        '-H', f'Authorization: Bearer {token}',
        '-H', 'Accept: application/json',
        '-H', 'anthropic-beta: oauth-2025-04-20',
        'https://api.anthropic.com/api/oauth/usage'
    ], capture_output=True, text=True)

    data = json.loads(result.stdout)

    fh = data.get('five_hour') or {}
    sd = data.get('seven_day') or {}
    ss = data.get('seven_day_sonnet') or {}
    so = data.get('seven_day_opus') or {}
    ex = data.get('extra_usage') or {}

    print(f'5H_UTIL={fh.get(\"utilization\", \"?\")}')
    print(f'5H_RESET={fh.get(\"resets_at\", \"?\")[:16]}')
    print(f'7D_UTIL={sd.get(\"utilization\", \"?\")}')
    print(f'7D_RESET={sd.get(\"resets_at\", \"?\")[:10]}')
    print(f'7D_SONNET={ss.get(\"utilization\", \"-\")}')
    print(f'7D_OPUS={so.get(\"utilization\", \"-\")}')
    print(f'EXTRA={ex.get(\"is_enabled\", False)}')
except Exception:
    sys.exit(1)
" 2>/dev/null) || oauth_data=""

    if [[ -n "$oauth_data" ]]; then
        CLAUDE_5H_UTIL=$(echo "$oauth_data" | grep '^5H_UTIL=' | cut -d= -f2)
        CLAUDE_5H_RESET=$(echo "$oauth_data" | grep '^5H_RESET=' | cut -d= -f2)
        CLAUDE_7D_UTIL=$(echo "$oauth_data" | grep '^7D_UTIL=' | cut -d= -f2)
        CLAUDE_7D_RESET=$(echo "$oauth_data" | grep '^7D_RESET=' | cut -d= -f2)
        CLAUDE_7D_SONNET_UTIL=$(echo "$oauth_data" | grep '^7D_SONNET=' | cut -d= -f2)
        CLAUDE_7D_OPUS_UTIL=$(echo "$oauth_data" | grep '^7D_OPUS=' | cut -d= -f2)
        CLAUDE_EXTRA_ENABLED=$(echo "$oauth_data" | grep '^EXTRA=' | cut -d= -f2)
    fi
fi

# Stats-cache (secondary source — token counts)
CLAUDE_TODAY_TOTAL=0
CLAUDE_TODAY_DETAIL=""
CLAUDE_DATA_DATE=""
CLAUDE_SESSIONS=""
CLAUDE_MESSAGES=""

if [[ ${#CLAUDE_AGENTS[@]} -gt 0 ]] && [[ -f "$CLAUDE_STATS" ]] && command -v "$PYTHON" &>/dev/null; then
    claude_data=$("$PYTHON" -c "
import json, sys
try:
    with open('${CLAUDE_STATS}') as f:
        data = json.load(f)
    today = '${TODAY}'
    all_token_entries = data.get('dailyModelTokens', [])
    target_tokens = {}
    target_date = today
    for entry in all_token_entries:
        if entry.get('date') == today:
            target_tokens = entry.get('tokensByModel', {})
            target_date = today
            break
    else:
        if all_token_entries:
            latest = all_token_entries[-1]
            target_tokens = latest.get('tokensByModel', {})
            target_date = latest.get('date', today)
    total_today = sum(target_tokens.values())
    short = {}
    for k, v in target_tokens.items():
        name = k.replace('claude-', '')
        for prefix in ('opus-4-8', 'opus-4-7', 'opus-4-6', 'sonnet-4-6', 'sonnet-4-5', 'haiku-4-5'):
            if name.startswith(prefix):
                name = prefix.split('-')[0]
                break
        short[name] = short.get(name, 0) + v
    all_activity = data.get('dailyActivity', [])
    target_activity = {}
    for entry in all_activity:
        if entry.get('date') == today:
            target_activity = entry
            break
    else:
        if all_activity:
            target_activity = all_activity[-1]
    sessions = target_activity.get('sessionCount', '?')
    messages = target_activity.get('messageCount', '?')
    print(f'TOTAL={total_today}')
    print(f'DATE={target_date}')
    for k, v in short.items():
        print(f'MODEL_{k}={v}')
    print(f'SESSIONS={sessions}')
    print(f'MESSAGES={messages}')
except Exception:
    sys.exit(1)
" 2>/dev/null) || claude_data=""

    if [[ -n "$claude_data" ]]; then
        CLAUDE_TODAY_TOTAL=$(echo "$claude_data" | grep '^TOTAL=' | cut -d= -f2)
        CLAUDE_DATA_DATE=$(echo "$claude_data" | grep '^DATE=' | cut -d= -f2)
        CLAUDE_SESSIONS=$(echo "$claude_data" | grep '^SESSIONS=' | cut -d= -f2)
        CLAUDE_MESSAGES=$(echo "$claude_data" | grep '^MESSAGES=' | cut -d= -f2)

        # Build model detail string
        CLAUDE_TODAY_DETAIL=""
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            model_name=$(echo "$line" | sed 's/^MODEL_//' | cut -d= -f1)
            model_val=$(echo "$line" | cut -d= -f2)
            if [[ -n "$CLAUDE_TODAY_DETAIL" ]]; then
                CLAUDE_TODAY_DETAIL="${CLAUDE_TODAY_DETAIL} | ${model_name}: $(printf "%'d" "$model_val" 2>/dev/null || echo "$model_val")"
            else
                CLAUDE_TODAY_DETAIL="${model_name}: $(printf "%'d" "$model_val" 2>/dev/null || echo "$model_val")"
            fi
        done < <(echo "$claude_data" | grep '^MODEL_')
    fi
fi

# --- 3b: Codex /status from pane (zoom temporarily to avoid narrow tiled-pane truncation) ---
declare -A CODEX_CONTEXT
CODEX_WARNINGS=""
CODEX_STATUS="OK"

# Shared quota (same ChatGPT account — capture from first idle agent with /status)
CODEX_ACCT_5H_LEFT=""
CODEX_ACCT_5H_RESET=""
CODEX_ACCT_7D_LEFT=""
CODEX_ACCT_7D_RESET=""
CODEX_MODEL_5H_LEFT=""
CODEX_MODEL_5H_RESET=""
CODEX_MODEL_7D_LEFT=""
CODEX_MODEL_7D_RESET=""
CODEX_MODEL_LABEL=""

if [[ ${#CODEX_AGENTS[@]} -gt 0 ]]; then
    _rl_quota_done=false

    for agent in "${CODEX_AGENTS[@]}"; do
        pane="${AGENT_PANE[$agent]}"
        _pane_snapshot=$(capture_tmux_pane_zoomed "$pane" -80)

        # Context: use a zoomed capture so the Codex prompt or recent /status block survives narrow panes.
        ctx=$(extract_codex_context_left "$_pane_snapshot" || true)
        [[ -z "$ctx" ]] && ctx="?"
        CODEX_CONTEXT["$agent"]="$ctx"

        # Quota: capture the latest /status block from a zoomed pane so narrow tiled panes do not
        # truncate "% left" and reset timestamps.
        if ! $_rl_quota_done; then
            _status_out="$_pane_snapshot"
            _status_block=$(extract_latest_codex_status_block "$_status_out")

            if [[ ! "$_status_block" =~ [0-9]+%[[:space:]]left ]]; then
                _status_out=$(capture_codex_status_snapshot "$pane")
                _status_block=$(extract_latest_codex_status_block "$_status_out")
            fi

            if [[ -n "$_status_block" ]]; then
                # Extract all "5h limit:" and "Weekly limit:" lines from the newest /status block only.
                # First occurrence = account-level, second = model-level.
                _5h_lines=$(printf '%s\n' "$_status_block" | grep '5h limit:' || true)
                _wk_lines=$(printf '%s\n' "$_status_block" | grep 'Weekly limit:' || true)

                # Account 5h (first line)
                _line=$(printf '%s\n' "$_5h_lines" | head -1 || true)
                if [[ -n "$_line" ]]; then
                    CODEX_ACCT_5H_LEFT=$(printf '%s\n' "$_line" | grep -oE '[0-9]+% left' | head -1 | grep -oE '[0-9]+' || true)
                    CODEX_ACCT_5H_RESET=$(printf '%s\n' "$_line" | sed -n 's/.*(resets \([^)]*\)).*/\1/p' | head -1)
                fi

                # Account Weekly (first line)
                _line=$(printf '%s\n' "$_wk_lines" | head -1 || true)
                if [[ -n "$_line" ]]; then
                    CODEX_ACCT_7D_LEFT=$(printf '%s\n' "$_line" | grep -oE '[0-9]+% left' | head -1 | grep -oE '[0-9]+' || true)
                    CODEX_ACCT_7D_RESET=$(printf '%s\n' "$_line" | sed -n 's/.*(resets \([^)]*\)).*/\1/p' | head -1)
                fi

                # Model label (e.g., "GPT-5.4-Codex")
                CODEX_MODEL_LABEL=$(printf '%s\n' "$_status_block" | grep -oE 'GPT-[^:]+ limit:' | head -1 | sed 's/ limit:$//' || true)

                # Model 5h (second line)
                _line=$(printf '%s\n' "$_5h_lines" | sed -n '2p' || true)
                if [[ -n "$_line" ]]; then
                    CODEX_MODEL_5H_LEFT=$(printf '%s\n' "$_line" | grep -oE '[0-9]+% left' | head -1 | grep -oE '[0-9]+' || true)
                    CODEX_MODEL_5H_RESET=$(printf '%s\n' "$_line" | sed -n 's/.*(resets \([^)]*\)).*/\1/p' | head -1)
                fi

                # Model Weekly (second line)
                _line=$(printf '%s\n' "$_wk_lines" | sed -n '2p' || true)
                if [[ -n "$_line" ]]; then
                    CODEX_MODEL_7D_LEFT=$(printf '%s\n' "$_line" | grep -oE '[0-9]+% left' | head -1 | grep -oE '[0-9]+' || true)
                    CODEX_MODEL_7D_RESET=$(printf '%s\n' "$_line" | sed -n 's/.*(resets \([^)]*\)).*/\1/p' | head -1)
                fi
            fi

            # Mark done if we got at least account 5h
            [[ -n "$CODEX_ACCT_5H_LEFT" ]] && _rl_quota_done=true
        fi

        # Check context thresholds
        if [[ "$ctx" != "?" ]]; then
            if [[ "$ctx" -lt "$CODEX_CONTEXT_CRIT" ]]; then
                CODEX_WARNINGS="${CODEX_WARNINGS} ${agent}(${ctx}%)!!"
                CODEX_STATUS="CRITICAL"
            elif [[ "$ctx" -lt "$CODEX_CONTEXT_WARN" ]]; then
                CODEX_WARNINGS="${CODEX_WARNINGS} ${agent}(${ctx}%)!"
                if [[ "$CODEX_STATUS" != "CRITICAL" ]]; then
                    CODEX_STATUS="WARNING"
                fi
            fi
        fi
    done
fi

# --- 3c: Codex log — token_limit_reached in last hour ---
CODEX_LIMIT_HITS=0
if [[ ${#CODEX_AGENTS[@]} -gt 0 ]] && [[ -f "$CODEX_LOG" ]]; then
    current_hour=$(date -u +%Y-%m-%dT%H)
    CODEX_LIMIT_HITS=$(tail -5000 "$CODEX_LOG" 2>/dev/null \
        | grep "token_limit_reached=true" \
        | grep -c "$current_hour" || true)
    CODEX_LIMIT_HITS="${CODEX_LIMIT_HITS:-0}"
    # Sanitize: strip whitespace, ensure integer
    CODEX_LIMIT_HITS=$(echo "$CODEX_LIMIT_HITS" | tr -d '[:space:]')
    [[ "$CODEX_LIMIT_HITS" =~ ^[0-9]+$ ]] || CODEX_LIMIT_HITS=0

    if [[ "$CODEX_LIMIT_HITS" -ge "$CODEX_LIMIT_HITS_WARN" ]]; then
        if [[ "$CODEX_STATUS" == "OK" ]]; then
            CODEX_STATUS="WARNING"
        fi
        CODEX_WARNINGS="${CODEX_WARNINGS} limit_hits=${CODEX_LIMIT_HITS}/h"
    fi
fi

# ═══════════════════════════════════════════════════════
# Phase 4: Display
# ═══════════════════════════════════════════════════════

printf "\n"
if [[ "$LANG_MODE" == "en" ]]; then
    printf "══ Rate Limit Status (%s) ══\n" "$TODAY"
else
    printf "══ レートリミット状況 (%s) ══\n" "$TODAY"
fi

# Summary: total agents detected
_total_agents=$(( ${#CLAUDE_AGENTS[@]} + ${#CODEX_AGENTS[@]} + ${#OTHER_AGENTS[@]} ))
if [[ "$LANG_MODE" == "en" ]]; then
    printf "  Detected agents: %d (claude=%d, codex=%d, other=%d)\n" \
        "$_total_agents" "${#CLAUDE_AGENTS[@]}" "${#CODEX_AGENTS[@]}" "${#OTHER_AGENTS[@]}"
else
    printf "  検出エージェント: %d (claude=%d, codex=%d, その他=%d)\n" \
        "$_total_agents" "${#CLAUDE_AGENTS[@]}" "${#CODEX_AGENTS[@]}" "${#OTHER_AGENTS[@]}"
fi

if [[ "$_total_agents" -eq 0 ]]; then
    if [[ "$LANG_MODE" == "en" ]]; then
        printf "\n  No agent tmux panes found. Launch the squad first.\n\n"
    else
        printf "\n  tmux pane 上にエージェントが検出されません。先にクラスタを起動してください。\n\n"
    fi
    exit 0
fi

# --- Claude group ---
if [[ ${#CLAUDE_AGENTS[@]} -gt 0 ]]; then
    printf "\n── Claude Max ────────────────────────\n"

    # Agent list with models
    agent_list=""
    for agent in "${CLAUDE_AGENTS[@]}"; do
        model="${AGENT_MODEL[$agent]}"
        if [[ -n "$agent_list" ]]; then
            agent_list="${agent_list}, ${agent}(${model})"
        else
            agent_list="${agent}(${model})"
        fi
    done
    printf "  Agents: %s\n" "$agent_list"

    # OAuth rate limits (primary display)
    if [[ -n "$CLAUDE_5H_UTIL" && "$CLAUDE_5H_UTIL" != "?" ]]; then
        printf "  ── Quota ──\n"
        # 5-hour window
        fh_int=${CLAUDE_5H_UTIL%.*}
        if [[ "$fh_int" =~ ^[0-9]+$ ]] && [[ "$fh_int" -ge 80 ]]; then
            printf "  5h window:  %s%% used [WARN] (resets %s)\n" "$CLAUDE_5H_UTIL" "$CLAUDE_5H_RESET"
            CLAUDE_STATUS="WARNING (5h: ${CLAUDE_5H_UTIL}%)"
        else
            printf "  5h window:  %s%% used  (resets %s)\n" "$CLAUDE_5H_UTIL" "$CLAUDE_5H_RESET"
        fi
        # 7-day window
        sd_int=${CLAUDE_7D_UTIL%.*}
        if [[ "$sd_int" =~ ^[0-9]+$ ]] && [[ "$sd_int" -ge 80 ]]; then
            printf "  7d window:  %s%% used [WARN] (resets %s)\n" "$CLAUDE_7D_UTIL" "$CLAUDE_7D_RESET"
            CLAUDE_STATUS="WARNING (7d: ${CLAUDE_7D_UTIL}%)"
        else
            printf "  7d window:  %s%% used  (resets %s)\n" "$CLAUDE_7D_UTIL" "$CLAUDE_7D_RESET"
        fi
        # Per-model breakdown
        if [[ "$CLAUDE_7D_SONNET_UTIL" != "-" && -n "$CLAUDE_7D_SONNET_UTIL" ]]; then
            printf "    sonnet 7d: %s%%\n" "$CLAUDE_7D_SONNET_UTIL"
        fi
        if [[ "$CLAUDE_7D_OPUS_UTIL" != "-" && -n "$CLAUDE_7D_OPUS_UTIL" ]]; then
            printf "    opus 7d:   %s%%\n" "$CLAUDE_7D_OPUS_UTIL"
        fi
        # Extra usage
        if [[ "$CLAUDE_EXTRA_ENABLED" == "True" ]]; then
            printf "  Extra usage: ENABLED\n"
        fi
    else
        printf "  Quota: N/A (OAuth API unreachable or credentials missing)\n"
    fi

    # Token stats from stats-cache (secondary)
    if [[ "$CLAUDE_TODAY_TOTAL" =~ ^[0-9]+$ ]] && [[ "$CLAUDE_TODAY_TOTAL" -gt 0 ]]; then
        printf "  ── Tokens ──\n"
        if [[ "${CLAUDE_DATA_DATE:-$TODAY}" != "$TODAY" ]]; then
            printf "  Latest (%s): %'d tokens\n" "$CLAUDE_DATA_DATE" "$CLAUDE_TODAY_TOTAL"
        else
            printf "  Today: %'d tokens\n" "$CLAUDE_TODAY_TOTAL"
        fi
        if [[ -n "$CLAUDE_TODAY_DETAIL" ]]; then
            printf "    %s\n" "$CLAUDE_TODAY_DETAIL"
        fi
        printf "  Sessions: %s | Messages: %s\n" "$CLAUDE_SESSIONS" "$CLAUDE_MESSAGES"
    fi

    printf "  Status: %s\n" "$CLAUDE_STATUS"
fi

# --- Codex group ---
if [[ ${#CODEX_AGENTS[@]} -gt 0 ]]; then
    printf "\n── ChatGPT (Codex) ───────────────────\n"

    # Shared model (from first codex agent)
    codex_model="${AGENT_MODEL[${CODEX_AGENTS[0]}]:-?}"
    # Build agent list (max 60 chars then ellipsis)
    _agent_csv=$(IFS=,; echo "${CODEX_AGENTS[*]}")
    if [[ "${#_agent_csv}" -gt 60 ]]; then
        _agent_csv="${_agent_csv:0:57}..."
    fi
    printf "  Agents (%d): %s\n" "${#CODEX_AGENTS[@]}" "$_agent_csv"
    printf "  Default model: %s\n" "$codex_model"

    # Context display
    if [[ "$LANG_MODE" == "en" ]]; then
        printf "  Context left:\n    "
    else
        printf "  コンテキスト残量:\n    "
    fi

    count=0
    for agent in "${CODEX_AGENTS[@]}"; do
        ctx="${CODEX_CONTEXT[$agent]}"
        # Add warning markers
        marker=""
        if [[ "$ctx" != "?" ]]; then
            if [[ "$ctx" -lt "$CODEX_CONTEXT_CRIT" ]]; then
                marker="!!"
            elif [[ "$ctx" -lt "$CODEX_CONTEXT_WARN" ]]; then
                marker="!"
            fi
        fi
        printf "%s:%s%%%s  " "$agent" "$ctx" "$marker"
        count=$((count + 1))
        if [[ $((count % 4)) -eq 0 ]] && [[ $count -lt ${#CODEX_AGENTS[@]} ]]; then
            printf "\n    "
        fi
    done
    printf "\n"

    # Quota display from /status
    printf "  Quota\n"
    if [[ -n "$CODEX_ACCT_5H_LEFT" ]]; then
        printf "  5h limit: %s%% left (resets %s)\n" "$CODEX_ACCT_5H_LEFT" "$(normalize_reset_value "$CODEX_ACCT_5H_RESET")"
    else
        printf "  5h limit: N/A\n"
    fi
    if [[ -n "$CODEX_ACCT_7D_LEFT" ]]; then
        printf "  Weekly limit: %s%% left (resets %s)\n" "$CODEX_ACCT_7D_LEFT" "$(normalize_reset_value "$CODEX_ACCT_7D_RESET")"
    else
        printf "  Weekly limit: N/A\n"
    fi
    # Model-level quota
    if [[ -n "$CODEX_MODEL_5H_LEFT" ]]; then
        printf "  %s:\n" "${CODEX_MODEL_LABEL:-Model}"
        printf "    5h limit: %s%% left (resets %s)\n" "$CODEX_MODEL_5H_LEFT" "$(normalize_reset_value "$CODEX_MODEL_5H_RESET")"
        if [[ -n "$CODEX_MODEL_7D_LEFT" ]]; then
            printf "    Weekly limit: %s%% left (resets %s)\n" "$CODEX_MODEL_7D_LEFT" "$(normalize_reset_value "$CODEX_MODEL_7D_RESET")"
        fi
    fi

    printf "  Limit hits (1h): %d\n" "$CODEX_LIMIT_HITS"

    if [[ "$CODEX_STATUS" != "OK" ]]; then
        printf "  Status: %s (%s)\n" "$CODEX_STATUS" "${CODEX_WARNINGS# }"
    else
        printf "  Status: OK\n"
    fi
fi

# --- Other CLIs ---
if [[ ${#OTHER_AGENTS[@]} -gt 0 ]]; then
    printf "\n── Other CLI ─────────────────────────\n"
    for agent in "${OTHER_AGENTS[@]}"; do
        cli="${AGENT_CLI[$agent]:-?}"
        model="${AGENT_MODEL[$agent]:-?}"
        printf "  %s: %s (%s) — no rate limit data\n" "$agent" "$cli" "$model"
    done
fi

printf "\n"
