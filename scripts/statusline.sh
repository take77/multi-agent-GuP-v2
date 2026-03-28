#!/usr/bin/env bash
# Claude Code Status Line Script (Linux version)
# Reads JSON from stdin, outputs 3-line status with ANSI colors
#
# Linux対応変更点 (vs macOS版):
#   - date -j -f → date -d (ISO8601パース)
#   - date -r $unix_ts → date -d @$unix_ts (unixtime→日時)
#   - stat -f "%m" → stat -c "%Y" (ファイル更新時刻)
#   - security find-generic-password → 環境変数対応

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Parse fields from stdin
# Actual JSON structure from Claude Code:
#   model.display_name, context_window.used_percentage,
#   cost.total_lines_added, cost.total_lines_removed, cwd
MODEL_DISPLAY=$(echo "$INPUT" | jq -r '.model.display_name // .model // "Sonnet 4.6"' 2>/dev/null || echo "Sonnet 4.6")
CONTEXT_PCT=$(echo "$INPUT" | jq -r '(.context_window.used_percentage // .context_window_usage_percentage // 0) | floor' 2>/dev/null || echo "0")
LINES_ADDED=$(echo "$INPUT" | jq -r '.cost.total_lines_added // .lines_added // 0' 2>/dev/null || echo "0")
LINES_REMOVED=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // .lines_removed // 0' 2>/dev/null || echo "0")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

# Sanitize numeric values
CONTEXT_PCT=$(echo "$CONTEXT_PCT" | grep -E '^[0-9]+$' || echo "0")
LINES_ADDED=$(echo "$LINES_ADDED" | grep -E '^[0-9]+$' || echo "0")
LINES_REMOVED=$(echo "$LINES_REMOVED" | grep -E '^[0-9]+$' || echo "0")

# Get git branch
if [ -n "$CWD" ]; then
  GIT_BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
else
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi

# ANSI color codes (RGB)
GREEN=$'\033[38;2;151;201;195m'
YELLOW=$'\033[38;2;229;192;123m'
RED=$'\033[38;2;224;108;117m'
GRAY=$'\033[38;2;74;88;92m'
RESET=$'\033[0m'

# Return ANSI color string based on percentage
color_for_pct() {
  local pct=${1:-0}
  if [ "$pct" -lt 50 ]; then
    printf '%s' "$GREEN"
  elif [ "$pct" -lt 80 ]; then
    printf '%s' "$YELLOW"
  else
    printf '%s' "$RED"
  fi
}

# Build progress bar (10 segments: ▰ filled, ▱ empty)
progress_bar() {
  local pct=${1:-0}
  local filled=$(( pct / 10 ))
  local bar=""
  local i=1
  while [ $i -le 10 ]; do
    if [ $i -le $filled ]; then
      bar="${bar}▰"
    else
      bar="${bar}▱"
    fi
    i=$(( i + 1 ))
  done
  printf '%s' "$bar"
}

# Format ISO8601 timestamp as unix epoch
# Input: ISO8601 string e.g. "2026-03-06T05:00:00.717869+00:00"
# Linux: uses date -d instead of date -j -f
_iso_to_unix() {
  local ts=$1
  # Strip fractional seconds for date -d compatibility
  local bare="${ts%%.*}"   # remove .XXXXXX+00:00
  bare="${bare%+*}"        # remove +HH:MM if no fractional part
  bare="${bare%Z}"         # remove trailing Z
  # Parse as UTC using Linux date -d
  TZ=UTC date -d "${bare}Z" "+%s" 2>/dev/null || echo ""
}

format_time_short() {
  local ts=$1
  if [ -z "$ts" ] || [ "$ts" = "null" ] || [ "$ts" = "0" ]; then echo "N/A"; return; fi
  local unix_ts
  unix_ts=$(_iso_to_unix "$ts")
  if [ -z "$unix_ts" ]; then echo "N/A"; return; fi
  # %I = 12-hour, %p = AM/PM; strip leading zero, lowercase
  # Linux: date -d @unix_ts instead of date -r unix_ts
  TZ="Asia/Tokyo" LANG=C date -d "@${unix_ts}" "+%I%p" 2>/dev/null \
    | sed 's/^0//' | tr '[:upper:]' '[:lower:]' || echo "N/A"
}

format_date_long() {
  local ts=$1
  if [ -z "$ts" ] || [ "$ts" = "null" ] || [ "$ts" = "0" ]; then echo "N/A"; return; fi
  local unix_ts
  unix_ts=$(_iso_to_unix "$ts")
  if [ -z "$unix_ts" ]; then echo "N/A"; return; fi
  local time_part
  time_part=$(TZ="Asia/Tokyo" LANG=C date -d "@${unix_ts}" "+%I%p" 2>/dev/null \
    | sed 's/^0//' | tr '[:upper:]' '[:lower:]')
  # %b = abbreviated month (LANG=C ensures English), %e = space-padded day
  local date_part
  date_part=$(TZ="Asia/Tokyo" LANG=C date -d "@${unix_ts}" "+%b %e" 2>/dev/null \
    | sed 's/  / /')
  echo "${date_part} at ${time_part}"
}

# Fetch rate limit data (with caching)
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=300
NOW=$(date +%s)
USE_CACHE=false

if [ -f "$CACHE_FILE" ]; then
  CACHE_TIME=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  CACHE_TIME=$(echo "$CACHE_TIME" | grep -E '^[0-9]+$' || echo "0")
  if [ $(( NOW - CACHE_TIME )) -lt $CACHE_MAX_AGE ]; then
    USE_CACHE=true
  fi
fi

FIVE_HOUR_PCT=0
SEVEN_DAY_PCT=0
FIVE_HOUR_RESET="N/A"
SEVEN_DAY_RESET="N/A"

if [ "$USE_CACHE" = true ]; then
  FIVE_HOUR_PCT=$(jq -r '.five_hour_pct // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  SEVEN_DAY_PCT=$(jq -r '.seven_day_pct // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  FIVE_HOUR_RESET=$(jq -r '.five_hour_reset // "N/A"' "$CACHE_FILE" 2>/dev/null || echo "N/A")
  SEVEN_DAY_RESET=$(jq -r '.seven_day_reset // "N/A"' "$CACHE_FILE" 2>/dev/null || echo "N/A")
else
  # Lockfile: prevent concurrent API calls from multiple script instances
  LOCK_FILE="/tmp/claude-usage.lock"
  # Auto-remove stale lockfile (older than 60 seconds) to recover from crashes
  # Linux: stat -c "%Y" instead of stat -f "%m"
  if [ -d "$LOCK_FILE" ]; then
    LOCK_TIME=$(stat -c "%Y" "$LOCK_FILE" 2>/dev/null || echo "0")
    if [ $(( NOW - LOCK_TIME )) -gt 60 ]; then
      rmdir "$LOCK_FILE" 2>/dev/null || true
    fi
  fi
  if mkdir "$LOCK_FILE" 2>/dev/null; then
    trap 'rmdir "$LOCK_FILE" 2>/dev/null || true' EXIT

    # Get OAuth token from environment variables (Linux: no Keychain)
    # Try multiple env var names for flexibility
    ACCESS_TOKEN="${ANTHROPIC_ACCESS_TOKEN:-${CLAUDE_ACCESS_TOKEN:-}}"

    # Fallback: read from Claude Code credentials file if env var not set
    if [ -z "$ACCESS_TOKEN" ]; then
      # Check multiple known paths
      CREDENTIALS_FILE=""
      for _cand in "${HOME}/.claude/.credentials.json" "${HOME}/.config/claude/credentials.json"; do
        if [ -f "$_cand" ]; then
          CREDENTIALS_FILE="$_cand"
          break
        fi
      done
      if [ -n "$CREDENTIALS_FILE" ] && [ -f "$CREDENTIALS_FILE" ]; then
        CREDENTIALS=$(cat "$CREDENTIALS_FILE" 2>/dev/null || echo "")
        if [ -n "$CREDENTIALS" ]; then
          if echo "$CREDENTIALS" | grep -q '^{'; then
            ACCESS_TOKEN=$(echo "$CREDENTIALS" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || echo "")
          else
            DECODED=$(echo "$CREDENTIALS" | xxd -r -p 2>/dev/null || echo "")
            ACCESS_TOKEN=$(echo "$DECODED" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || echo "")
          fi
        fi
      fi
    fi

    if [ -n "$ACCESS_TOKEN" ]; then
      RESPONSE=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || echo "")

      # Parse only if response contains valid usage data (not an error)
      IS_ERROR=$(echo "$RESPONSE" | jq -r 'if .error then "true" else "false" end' 2>/dev/null || echo "true")

      if [ -n "$RESPONSE" ] && [ "$IS_ERROR" = "false" ]; then
        FH_UTIL=$(echo "$RESPONSE" | jq -r '.five_hour.utilization // 0' 2>/dev/null || echo "0")
        SD_UTIL=$(echo "$RESPONSE" | jq -r '.seven_day.utilization // 0' 2>/dev/null || echo "0")
        FH_RESET_TS=$(echo "$RESPONSE" | jq -r '.five_hour.resets_at // 0' 2>/dev/null || echo "0")
        SD_RESET_TS=$(echo "$RESPONSE" | jq -r '.seven_day.resets_at // 0' 2>/dev/null || echo "0")

        # utilization is already a percentage (0–100)
        FIVE_HOUR_PCT=$(awk "BEGIN {printf \"%d\", $FH_UTIL}")
        SEVEN_DAY_PCT=$(awk "BEGIN {printf \"%d\", $SD_UTIL}")

        # Format reset times
        FIVE_HOUR_RESET=$(format_time_short "$FH_RESET_TS")
        SEVEN_DAY_RESET=$(format_date_long "$SD_RESET_TS")
      fi

      # On success: write new values. On error: preserve old values but update
      # timestamp to prevent hammering the API while rate-limited.
      if [ -n "$RESPONSE" ] && [ "$IS_ERROR" = "false" ]; then
        jq -n \
          --argjson ts "$NOW" \
          --argjson fhp "$FIVE_HOUR_PCT" \
          --argjson sdp "$SEVEN_DAY_PCT" \
          --arg fhr "$FIVE_HOUR_RESET" \
          --arg sdr "$SEVEN_DAY_RESET" \
          '{timestamp: $ts, five_hour_pct: $fhp, seven_day_pct: $sdp, five_hour_reset: $fhr, seven_day_reset: $sdr}' \
          > "$CACHE_FILE" 2>/dev/null || true
      elif [ -f "$CACHE_FILE" ]; then
        # Keep existing values, just bump timestamp to suppress retries
        jq --argjson ts "$NOW" '.timestamp = $ts' "$CACHE_FILE" > "${CACHE_FILE}.tmp" \
          && mv "${CACHE_FILE}.tmp" "$CACHE_FILE" 2>/dev/null || true
      else
        # No cache at all, write zeros so we at least have a file
        jq -n \
          --argjson ts "$NOW" \
          '{timestamp: $ts, five_hour_pct: 0, seven_day_pct: 0, five_hour_reset: "N/A", seven_day_reset: "N/A"}' \
          > "$CACHE_FILE" 2>/dev/null || true
      fi
    fi
  fi
fi

# Sanitize percentages
FIVE_HOUR_PCT=$(echo "$FIVE_HOUR_PCT" | grep -E '^[0-9]+$' || echo "0")
SEVEN_DAY_PCT=$(echo "$SEVEN_DAY_PCT" | grep -E '^[0-9]+$' || echo "0")

# ── Line 1: model │ context% │ +lines/-lines │ branch ──────────────────────
CTX_COLOR=$(color_for_pct "$CONTEXT_PCT")
printf "${GRAY}🤖 ${RESET}${MODEL_DISPLAY}${GRAY} │ ${CTX_COLOR}📊 ${CONTEXT_PCT}%%${RESET}${GRAY} │ ${GREEN}✏️  +${LINES_ADDED}/-${LINES_REMOVED}${RESET}${GRAY} │ ${RESET}🔀 ${GIT_BRANCH}${RESET}\n"

# ── Line 2: 5-hour rate limit ──────────────────────────────────────────────
FH_COLOR=$(color_for_pct "$FIVE_HOUR_PCT")
FH_BAR=$(progress_bar "$FIVE_HOUR_PCT")
printf "${FH_COLOR}⏱ 5h  ${FH_BAR}  ${FIVE_HOUR_PCT}%%  Resets ${FIVE_HOUR_RESET} (Asia/Tokyo)${RESET}\n"

# ── Line 3: 7-day rate limit ───────────────────────────────────────────────
SD_COLOR=$(color_for_pct "$SEVEN_DAY_PCT")
SD_BAR=$(progress_bar "$SEVEN_DAY_PCT")
printf "${SD_COLOR}📅 7d  ${SD_BAR}  ${SEVEN_DAY_PCT}%%  Resets ${SEVEN_DAY_RESET} (Asia/Tokyo)${RESET}\n"
