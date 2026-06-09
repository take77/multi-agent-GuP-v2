#!/usr/bin/env bash
# A1 統合スモークゲート Phase1 — Web harness
# 契約: docs/plans/a1_smoke_gate_harness_contract.md §2/§3/§4 逐語準拠
# 成果物: queue/reports/smoke_gate/web_<ts>.yaml + artifacts/
# exit 0=pass / 1=fail / 2=blocked

set -uo pipefail

# ────────────────────────────────────────────────────────────
# 設定
# ────────────────────────────────────────────────────────────
HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_REPO="${TARGET_REPO:-/Users/take77.mac-mini/Developments/calsail/calsail-web}"
ARTIFACTS_DIR="${HARNESS_ROOT}/queue/reports/smoke_gate/artifacts"
REPORT_DIR="${HARNESS_ROOT}/queue/reports/smoke_gate"

TS="$(date +%Y%m%dT%H%M%S)"
BUILD_LOG="${ARTIFACTS_DIR}/web_build_${TS}.log"
PW_PUBLIC_DIR="${ARTIFACTS_DIR}/pw_public_${TS}"
PW_AUTHED_DIR="${ARTIFACTS_DIR}/pw_authed_${TS}"
REPORT_FILE="${REPORT_DIR}/web_${TS}.yaml"

mkdir -p "${ARTIFACTS_DIR}"

# ────────────────────────────────────────────────────────────
# ヘルパ
# ────────────────────────────────────────────────────────────
overall_status="pass"  # worst-of: fail > blocked > pass

set_status() {
  local s="$1"
  case "$s" in
    fail)    overall_status="fail" ;;
    blocked) [[ "$overall_status" != "fail" ]] && overall_status="blocked" ;;
  esac
}

# duration 計測用
start_time() { date +%s; }
elapsed() { echo $(( $(date +%s) - $1 )); }

# ────────────────────────────────────────────────────────────
# §4 Preflight
# ────────────────────────────────────────────────────────────
preflight_fail=0

# ツール確認
for cmd in node npm git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[preflight] MISSING tool: $cmd" >&2
    preflight_fail=1
  fi
done

# target repo 確認
if [[ ! -d "${TARGET_REPO}" ]]; then
  echo "[preflight] MISSING target repo: ${TARGET_REPO}" >&2
  preflight_fail=1
fi

if [[ "$preflight_fail" -ne 0 ]]; then
  # ツール欠如は全 check blocked
  cat > "${REPORT_FILE}" <<YAML
schema_version: 1
gate: web
status: blocked
generated_at: "$(date -u +%Y-%m-%dT%H:%M:%S)"
target:
  repo: calsail-web
  path: ${TARGET_REPO}
  branch: unknown
  ref: unknown
checks:
  - id: web_build
    name: "npm run build (tsc 型チェック)"
    status: blocked
    duration_s: 0
    detail: "preflight failed: required tool missing (node/npm/git)"
    artifact: ""
  - id: playwright_public
    name: "Playwright public-flow smoke"
    status: blocked
    duration_s: 0
    detail: "preflight failed: required tool missing"
    artifact: ""
  - id: playwright_authed
    name: "Playwright authed-flow smoke"
    status: blocked
    duration_s: 0
    detail: "preflight failed: required tool missing"
    artifact: ""
covered: []
uncovered:
  - "tsc 型チェック (npm run build)"
  - "public e2e flows"
  - "authed e2e flows"
blocked:
  - check_id: web_build
    reason: "required tool missing (node/npm/git) — install and retry"
  - check_id: playwright_public
    reason: "required tool missing"
  - check_id: playwright_authed
    reason: "required tool missing"
summary: "preflight failed: required tool missing"
YAML
  echo "[smoke] report: ${REPORT_FILE}"
  exit 2
fi

# target repo の branch/ref 取得
TARGET_BRANCH="$(git -C "${TARGET_REPO}" branch --show-current 2>/dev/null || echo unknown)"
TARGET_REF="$(git -C "${TARGET_REPO}" rev-parse HEAD 2>/dev/null || echo unknown)"

# ────────────────────────────────────────────────────────────
# §4 env preflight（.env.staging に名前ベースで確認・値非露出）
# ────────────────────────────────────────────────────────────
ENV_FILE="${TARGET_REPO}/.env.staging"
REQUIRED_ENVS=(
  "E2E_USER_EMAIL"
  "NEXT_PUBLIC_SUPABASE_URL"
  "SUPABASE_SERVICE_ROLE_KEY"
  "NEXT_PUBLIC_SUPABASE_ANON_KEY"
)
env_absent=()

if [[ -f "${ENV_FILE}" ]]; then
  for key in "${REQUIRED_ENVS[@]}"; do
    if ! grep -q "^${key}=" "${ENV_FILE}"; then
      env_absent+=("$key")
    fi
  done
else
  env_absent=("${REQUIRED_ENVS[@]}")
fi

# ────────────────────────────────────────────────────────────
# check A: web_build
# ────────────────────────────────────────────────────────────
build_status="pass"
build_detail=""
t0=$(start_time)

echo "[smoke] check A: npm run build ..."
if ! (cd "${TARGET_REPO}" && npm run build > "${BUILD_LOG}" 2>&1); then
  build_status="fail"
  build_detail="next build failed — see ${BUILD_LOG}"
  set_status "fail"
else
  build_detail="next build success"
fi
build_dur=$(elapsed $t0)

echo "[smoke] check A done: ${build_status} (${build_dur}s)"

# ────────────────────────────────────────────────────────────
# check B: playwright_public
# ────────────────────────────────────────────────────────────
public_status="pass"
public_detail=""
t0=$(start_time)

echo "[smoke] check B: playwright --project=public ..."
mkdir -p "${PW_PUBLIC_DIR}"

if ! (cd "${TARGET_REPO}" && \
      PLAYWRIGHT_HTML_REPORT="${PW_PUBLIC_DIR}/html" \
      npm run test:e2e -- --project=public --reporter=html,line \
      > "${PW_PUBLIC_DIR}/stdout.log" 2>&1); then
  public_status="fail"
  public_detail="playwright public failed or tests skipped — see ${PW_PUBLIC_DIR}/stdout.log"
  set_status "fail"
else
  # SKIP=fail チェック
  if grep -q "skipped" "${PW_PUBLIC_DIR}/stdout.log" 2>/dev/null; then
    skipped_count=$(grep -oE "[0-9]+ skipped" "${PW_PUBLIC_DIR}/stdout.log" | grep -oE "[0-9]+" | head -1 || echo 0)
    if [[ "${skipped_count:-0}" -gt 0 ]]; then
      public_status="fail"
      public_detail="playwright public: ${skipped_count} test(s) skipped (SKIP=FAIL rule)"
      set_status "fail"
    else
      public_detail="playwright public passed"
    fi
  else
    public_detail="playwright public passed"
  fi
fi
public_dur=$(elapsed $t0)

echo "[smoke] check B done: ${public_status} (${public_dur}s)"

# ────────────────────────────────────────────────────────────
# check C: playwright_authed
# ────────────────────────────────────────────────────────────
authed_status="pass"
authed_detail=""
authed_blocked_reason=""
t0=$(start_time)

if [[ ${#env_absent[@]} -gt 0 ]]; then
  authed_status="blocked"
  authed_blocked_reason="absent env in .env.staging: ${env_absent[*]} — provision these keys in .env.staging (values not exposed) and retry"
  authed_detail="env preflight failed: ${env_absent[*]} absent"
  set_status "blocked"
  echo "[smoke] check C: blocked (env absent: ${env_absent[*]})"
else
  echo "[smoke] check C: playwright --project=chromium ..."
  mkdir -p "${PW_AUTHED_DIR}"

  if ! (cd "${TARGET_REPO}" && \
        PLAYWRIGHT_HTML_REPORT="${PW_AUTHED_DIR}/html" \
        npm run test:e2e -- --project=chromium --reporter=html,line \
        > "${PW_AUTHED_DIR}/stdout.log" 2>&1); then
    authed_status="fail"
    authed_detail="playwright authed failed or tests skipped — see ${PW_AUTHED_DIR}/stdout.log"
    set_status "fail"
  else
    if grep -q "skipped" "${PW_AUTHED_DIR}/stdout.log" 2>/dev/null; then
      skipped_count=$(grep -oE "[0-9]+ skipped" "${PW_AUTHED_DIR}/stdout.log" | grep -oE "[0-9]+" | head -1 || echo 0)
      if [[ "${skipped_count:-0}" -gt 0 ]]; then
        authed_status="fail"
        authed_detail="playwright authed: ${skipped_count} test(s) skipped (SKIP=FAIL rule)"
        set_status "fail"
      else
        authed_detail="playwright authed passed (setup + chromium specs)"
      fi
    else
      authed_detail="playwright authed passed (setup + chromium specs)"
    fi
  fi
fi
authed_dur=$(elapsed $t0)

echo "[smoke] check C done: ${authed_status} (${authed_dur}s)"

# ────────────────────────────────────────────────────────────
# covered / uncovered 集計
# ────────────────────────────────────────────────────────────
covered=()
uncovered=()
blocked_entries=""

[[ "$build_status" == "pass" ]]   && covered+=("tsc 型チェック (npm run build)")   || uncovered+=("tsc 型チェック (npm run build): ${build_status}")
[[ "$public_status" == "pass" ]]  && covered+=("public e2e flows (contact-form + happy-path)") || uncovered+=("public e2e flows: ${public_status}")

if [[ "$authed_status" == "pass" ]]; then
  covered+=("authed e2e flows (csv-button / login / mobile-menu / receipts / yearly-filter)")
elif [[ "$authed_status" == "blocked" ]]; then
  uncovered+=("authed e2e flows: blocked (env absent)")
  blocked_entries="  - check_id: playwright_authed
    reason: \"${authed_blocked_reason}\""
else
  uncovered+=("authed e2e flows: ${authed_status}")
fi

# YAML リスト生成
yaml_list() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
  else
    local out=""
    for item in "${arr[@]}"; do
      out+="  - \"${item}\"\n"
    done
    printf "%b" "$out"
  fi
}

covered_yaml="$(yaml_list "${covered[@]+"${covered[@]}"}")"
uncovered_yaml="$(yaml_list "${uncovered[@]+"${uncovered[@]}"}")"

# blocked セクション
if [[ -z "$blocked_entries" ]]; then
  blocked_yaml="[]"
else
  blocked_yaml=$'\n'"${blocked_entries}"
fi

# summary
summary="build:${build_status}; public:${public_status}; authed:${authed_status}"

# ────────────────────────────────────────────────────────────
# §2 report emit
# ────────────────────────────────────────────────────────────
cat > "${REPORT_FILE}" <<YAML
schema_version: 1
gate: web
status: ${overall_status}
generated_at: "$(date -u +%Y-%m-%dT%H:%M:%S)"
target:
  repo: calsail-web
  path: ${TARGET_REPO}
  branch: ${TARGET_BRANCH}
  ref: "${TARGET_REF}"
checks:
  - id: web_build
    name: "npm run build (tsc 型チェック)"
    status: ${build_status}
    duration_s: ${build_dur}
    detail: "${build_detail}"
    artifact: "${BUILD_LOG}"
  - id: playwright_public
    name: "Playwright public-flow smoke (contact-form + happy-path)"
    status: ${public_status}
    duration_s: ${public_dur}
    detail: "${public_detail}"
    artifact: "${PW_PUBLIC_DIR}/"
  - id: playwright_authed
    name: "Playwright authed-flow smoke (setup + chromium)"
    status: ${authed_status}
    duration_s: ${authed_dur}
    detail: "${authed_detail}"
    artifact: "${PW_AUTHED_DIR}/"
covered:
${covered_yaml}
uncovered:
${uncovered_yaml}
blocked: ${blocked_yaml}
summary: "${summary}"
YAML

echo "[smoke] report emitted: ${REPORT_FILE}"
echo "[smoke] overall: ${overall_status}"

# ────────────────────────────────────────────────────────────
# §3 exit code
# ────────────────────────────────────────────────────────────
case "$overall_status" in
  pass)    exit 0 ;;
  fail)    exit 1 ;;
  blocked) exit 2 ;;
  *)       exit 1 ;;
esac
