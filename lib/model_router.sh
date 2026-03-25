#!/usr/bin/env bash
# ============================================================
# model_router.sh — Bloom Model Routing for GuP-v2
# ============================================================
# タスクの bloom_level (L1-L6) に基づいて推奨モデルを返す。
# config/settings.yaml の bloom_routing セクションと連動。
#
# Usage:
#   source lib/model_router.sh
#   model=$(get_recommended_model "L4")   # → "opus"
#   display=$(get_model_display_name "opus")  # → "Opus"
#
# Standalone test:
#   bash lib/model_router.sh --test
# ============================================================

set -euo pipefail

# プロジェクトルート（このスクリプトの親の親）
MODEL_ROUTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_ROUTER_PROJECT_ROOT="$(cd "${MODEL_ROUTER_DIR}/.." && pwd)"
MODEL_ROUTER_SETTINGS="${MODEL_ROUTER_PROJECT_ROOT}/config/settings.yaml"

# ------------------------------------------------------------
# validate_bloom_level — L1-L6 の妥当性チェック
# ------------------------------------------------------------
# Returns: 0 = valid, 1 = invalid
# Usage: validate_bloom_level "L4" && echo "valid"
validate_bloom_level() {
  local level="${1:-}"
  case "$level" in
    L1|L2|L3|L4|L5|L6) return 0 ;;
    *) return 1 ;;
  esac
}

# ------------------------------------------------------------
# get_recommended_model — bloom_level → model_id
# ------------------------------------------------------------
# Input:  bloom_level (L1-L6)
# Output: model_id (haiku|sonnet|opus) to stdout
# Exit:   0 = success, 1 = invalid level, 2 = settings not found
get_recommended_model() {
  local level="${1:-}"

  # バリデーション
  if ! validate_bloom_level "$level"; then
    echo "ERROR: Invalid bloom_level: '${level}'. Must be L1-L6." >&2
    return 1
  fi

  # settings.yaml からモデルを取得
  if [[ -f "$MODEL_ROUTER_SETTINGS" ]]; then
    local model
    model=$(grep -A1 "^    ${level}:" "$MODEL_ROUTER_SETTINGS" | grep "model:" | awk '{print $2}' | head -1)
    if [[ -n "$model" ]]; then
      echo "$model"
      return 0
    fi
  fi

  # settings.yaml がない or パース失敗時のフォールバック
  case "$level" in
    L1)       echo "haiku" ;;
    L2|L3)    echo "sonnet" ;;
    L4|L5|L6) echo "opus" ;;
  esac
  return 0
}

# ------------------------------------------------------------
# get_model_display_name — model_id → 表示名
# ------------------------------------------------------------
# Input:  model_id (haiku|sonnet|opus)
# Output: Display name to stdout
get_model_display_name() {
  local model_id="${1:-}"
  case "$model_id" in
    haiku)  echo "Haiku" ;;
    sonnet) echo "Sonnet" ;;
    opus)   echo "Opus" ;;
    *)      echo "$model_id" ;;
  esac
}

# ------------------------------------------------------------
# get_model_switch_command — bloom_level → inbox_write コマンド生成
# ------------------------------------------------------------
# 隊長がモデル切替に使うコマンドを生成する補助関数
# Input:  member_name, bloom_level, captain_name
# Output: inbox_write コマンド文字列 to stdout
get_model_switch_command() {
  local member="${1:-}"
  local level="${2:-}"
  local captain="${3:-}"

  if ! validate_bloom_level "$level"; then
    echo "ERROR: Invalid bloom_level: '${level}'" >&2
    return 1
  fi

  local model
  model=$(get_recommended_model "$level")
  echo "bash scripts/inbox_write.sh ${member} \"/model ${model}\" model_switch ${captain}"
}

# ============================================================
# --test: 単体テスト
# ============================================================
if [[ "${1:-}" == "--test" ]]; then
  set +e  # テスト中はエラーで終了しない
  PASS=0
  FAIL=0
  TOTAL=0

  _assert() {
    local test_name="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
      PASS=$((PASS + 1))
      echo "  PASS: ${test_name}"
    else
      FAIL=$((FAIL + 1))
      echo "  FAIL: ${test_name} (expected='${expected}', actual='${actual}')"
    fi
  }

  echo "=== model_router.sh unit tests ==="
  echo ""

  # --- validate_bloom_level ---
  echo "[validate_bloom_level]"
  for lvl in L1 L2 L3 L4 L5 L6; do
    validate_bloom_level "$lvl"
    _assert "validate_bloom_level ${lvl}" "0" "$?"
  done
  validate_bloom_level "L0" 2>/dev/null
  _assert "validate_bloom_level L0 (invalid)" "1" "$?"
  validate_bloom_level "" 2>/dev/null
  _assert "validate_bloom_level '' (empty)" "1" "$?"
  validate_bloom_level "X" 2>/dev/null
  _assert "validate_bloom_level X (invalid)" "1" "$?"

  echo ""

  # --- get_recommended_model ---
  echo "[get_recommended_model]"
  _assert "L1 → haiku"  "haiku"  "$(get_recommended_model L1)"
  _assert "L2 → sonnet" "sonnet" "$(get_recommended_model L2)"
  _assert "L3 → sonnet" "sonnet" "$(get_recommended_model L3)"
  _assert "L4 → opus"   "opus"   "$(get_recommended_model L4)"
  _assert "L5 → opus"   "opus"   "$(get_recommended_model L5)"
  _assert "L6 → opus"   "opus"   "$(get_recommended_model L6)"

  # エラーケース
  result=$(get_recommended_model "INVALID" 2>/dev/null) || true
  _assert "INVALID → error (empty)" "" "$result"

  echo ""

  # --- get_model_display_name ---
  echo "[get_model_display_name]"
  _assert "haiku → Haiku"   "Haiku"  "$(get_model_display_name haiku)"
  _assert "sonnet → Sonnet" "Sonnet" "$(get_model_display_name sonnet)"
  _assert "opus → Opus"     "Opus"   "$(get_model_display_name opus)"
  _assert "unknown → unknown" "unknown" "$(get_model_display_name unknown)"

  echo ""

  # --- get_model_switch_command ---
  echo "[get_model_switch_command]"
  cmd=$(get_model_switch_command "hana" "L4" "darjeeling")
  _assert "L4 switch cmd" 'bash scripts/inbox_write.sh hana "/model opus" model_switch darjeeling' "$cmd"
  cmd=$(get_model_switch_command "hana" "L2" "darjeeling")
  _assert "L2 switch cmd" 'bash scripts/inbox_write.sh hana "/model sonnet" model_switch darjeeling' "$cmd"

  echo ""
  echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
  [[ $FAIL -eq 0 ]] && exit 0 || exit 1
fi
