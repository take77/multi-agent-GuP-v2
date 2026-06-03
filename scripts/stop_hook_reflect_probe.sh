#!/usr/bin/env bash
# stop_hook_reflect_probe.sh — Phase 1: runtime probe (observation only)
#
# 目的: Stop 受信の生 stdin JSON を 1 回だけログして実フィールドを現物確定する。
# 重要:
#   - decision を絶対に stdout へ出さない（stdout は常に空）
#   - 常に exit 0 (停止を一切阻害しない = 挙動ゼロ変更)
#   - 完全 fail-open: あらゆる例外でも exit 0 (set -e を使わない)
#   - 1 回ガード: FLAG ファイルが存在すれば即 exit 0 (ログ肥大防止)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || SCRIPT_DIR="$(pwd)"
LOG_DIR="${SCRIPT_DIR}/logs/stophook_probe"
FLAG="/tmp/gup_stophook_probe_done"

# 1 回ガード: flag が存在したら即 exit 0
if [ -f "$FLAG" ]; then
    exit 0
fi

# stdin を読み込む（失敗しても exit 0）
INPUT=$(cat 2>/dev/null) || { exit 0; }

# ログディレクトリ作成（失敗しても exit 0）
mkdir -p "$LOG_DIR" 2>/dev/null || { exit 0; }

# タイムスタンプ付きログファイルへ書き込む
TS=$(date '+%Y%m%d_%H%M%S' 2>/dev/null) || TS="unknown"
LOGFILE="${LOG_DIR}/stop_input_${TS}.json"
printf '%s\n' "$INPUT" > "$LOGFILE" 2>/dev/null || { exit 0; }

# flag をセット（以降の Stop では 1 回ガードで即 exit 0）
touch "$FLAG" 2>/dev/null || true

# stdout は空 — decision を一切返さない
# 常に exit 0（停止を一切阻害しない）
exit 0
