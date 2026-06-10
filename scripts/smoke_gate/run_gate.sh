#!/usr/bin/env bash
# A1 統合スモークゲート Phase3 — Orchestrator (run_gate.sh)
# 契約: docs/plans/a1_smoke_gate_harness_contract.md §1/§2/§3 逐語準拠
# 役割: web_smoke.sh + mobile_smoke.sh をワンコマンドで一括起動 → 子レポートを
#       pyyaml で堅牢パース → worst-of(fail>blocked>pass) に集約 → gate_<ts>.yaml emit。
# 成果物: queue/reports/smoke_gate/gate_<ts>.yaml + artifacts/gate_<gate>_<ts>.log
# exit 0=pass / 1=fail / 2=blocked （子ゲートの worst-of）
#
# 使い方:
#   run_gate.sh                  # web + mobile を実走 → 集約
#   run_gate.sh web              # web のみ実走 → 集約
#   run_gate.sh mobile           # mobile のみ実走 → 集約
#   run_gate.sh --aggregate-only # 実走せず、既存の最新 web_*/mobile_*.yaml を集約（集約器の単体検証用）
#   TARGET_WEB / TARGET_MOBILE で対象 repo を上書き可（各サブハーネスへ TARGET_REPO として渡す）

set -uo pipefail

# ────────────────────────────────────────────────────────────
# 設定
# ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_DIR="${HARNESS_ROOT}/queue/reports/smoke_gate"
ARTIFACTS_DIR="${REPORT_DIR}/artifacts"
mkdir -p "${ARTIFACTS_DIR}"

# 契約 §2: filename <ts> と generated_at は同一ローカル TZ
TS="$(date +%Y%m%dT%H%M%S)"
GEN_AT="$(date +%Y-%m-%dT%H:%M:%S)"
GATE_REPORT="${REPORT_DIR}/gate_${TS}.yaml"

WEB_SCRIPT="${SCRIPT_DIR}/web_smoke.sh"
MOBILE_SCRIPT="${SCRIPT_DIR}/mobile_smoke.sh"

# ────────────────────────────────────────────────────────────
# 引数
# ────────────────────────────────────────────────────────────
GATES=()
AGGREGATE_ONLY=0
for a in "$@"; do
  case "$a" in
    web)             GATES+=("web") ;;
    mobile)          GATES+=("mobile") ;;
    full)            GATES+=("web" "mobile") ;;
    --aggregate-only) AGGREGATE_ONLY=1 ;;
    -h|--help)
      grep -E '^#( |$)' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//'
      exit 0 ;;
    *)
      echo "[gate] unknown arg: $a (使い方は -h)" >&2
      exit 64 ;;
  esac
done
[[ ${#GATES[@]} -eq 0 ]] && GATES=("web" "mobile")

# 重複排除（順序保持: "web full" 等で web が二重化しないように）
dedup=()
for g in "${GATES[@]}"; do
  seen=0
  for d in "${dedup[@]+"${dedup[@]}"}"; do [[ "$d" == "$g" ]] && seen=1 && break; done
  [[ "$seen" -eq 0 ]] && dedup+=("$g")
done
GATES=("${dedup[@]}")

# ────────────────────────────────────────────────────────────
# §4 Preflight — 集約に python3+yaml が必須（無ければ判定不能=blocked）
# ────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null || ! python3 -c 'import yaml' &>/dev/null; then
  cat > "${GATE_REPORT}" <<YAML
schema_version: 1
gate: full
status: blocked
generated_at: "${GEN_AT}"
gates: []
covered: []
uncovered:
  - "orchestrator preflight failed: python3 + pyyaml unavailable — 集約器が動かないため判定不能"
blocked:
  - gate: orchestrator
    reason: "python3/pyyaml absent — install python3 and pyyaml (pip install pyyaml) then retry"
summary: "orchestrator preflight failed: python3/pyyaml unavailable"
YAML
  echo "[gate] report: ${GATE_REPORT}"
  exit 2
fi

# ────────────────────────────────────────────────────────────
# ヘルパ
# ────────────────────────────────────────────────────────────
# 指定 gate の既存レポートのうち最新（mtime 降順）を返す
latest_report() {
  ls -t "${REPORT_DIR}/${1}_"*.yaml 2>/dev/null | head -1
}

# サブハーネス stdout ログから "[smoke] report ...: <path>" を抽出（最後の1件）
extract_report_path() {
  local log="$1"
  [[ -f "$log" ]] || return 0
  grep -E '\[smoke\] report' "$log" 2>/dev/null | tail -1 | sed -E 's/.*: //'
}

# サブハーネスを1本実走し、manifest 行 "gate|exit|reportpath" を stdout に返す
run_one() {
  local gate="$1" script="$2" target_env="$3" target_val="$4"
  local olog="${ARTIFACTS_DIR}/gate_${gate}_${TS}.log"
  echo "[gate] === ${gate} smoke 実走 ===" >&2
  if [[ -n "$target_val" ]]; then
    env "${target_env}=${target_val}" bash "$script" >"$olog" 2>&1
  else
    bash "$script" >"$olog" 2>&1
  fi
  local ec=$?
  local rpath
  rpath="$(extract_report_path "$olog")"
  if [[ -z "$rpath" || ! -f "$rpath" ]]; then
    rpath="$(latest_report "$gate")"   # fallback: 最新レポート
  fi
  echo "[gate] ${gate} done: exit=${ec} report=${rpath:-<none>}" >&2
  echo "${gate}|${ec}|${rpath}"
}

# ────────────────────────────────────────────────────────────
# 各 gate を実走（または既存集約）→ manifest 構築
# ────────────────────────────────────────────────────────────
manifest=()
for g in "${GATES[@]}"; do
  case "$g" in
    web)    script="$WEB_SCRIPT";    tenv="TARGET_REPO"; tval="${TARGET_WEB:-}" ;;
    mobile) script="$MOBILE_SCRIPT"; tenv="TARGET_REPO"; tval="${TARGET_MOBILE:-}" ;;
  esac

  if [[ "$AGGREGATE_ONLY" -eq 1 ]]; then
    rpath="$(latest_report "$g")"
    if [[ -z "$rpath" ]]; then
      echo "[gate] aggregate-only: no existing report for ${g}" >&2
      manifest+=("${g}|2|")   # レポート不在 → blocked 相当（python で status 合成）
    else
      manifest+=("${g}|0|${rpath}")   # python は report 内 status を優先採用
    fi
  else
    if [[ ! -f "$script" ]]; then
      echo "[gate] MISSING harness script: ${script}" >&2
      manifest+=("${g}|1|")   # ハーネス欠如 → fail
    else
      manifest+=("$(run_one "$g" "$script" "$tenv" "$tval")")
    fi
  fi
done

# ────────────────────────────────────────────────────────────
# §2/§3 集約 — pyyaml で子レポートを読み、worst-of で gate report を emit
#   manifest 各行: "gate|exit|reportpath"（path は当プロジェクト管理下=空白なし）
# ────────────────────────────────────────────────────────────
python3 - "${GATE_REPORT}" "${GEN_AT}" "${HARNESS_ROOT}" "${manifest[@]}" <<'PY'
import sys, os, yaml

out_path  = sys.argv[1]
gen_at    = sys.argv[2]
root      = sys.argv[3]
manifest  = sys.argv[4:]

# worst-of ランク: fail > blocked > pass（契約 §3）
RANK = {"pass": 1, "blocked": 2, "fail": 3}
def from_exit(c):
    return {0: "pass", 1: "fail", 2: "blocked"}.get(c, "fail")
def relpath(p):
    if not p:
        return None
    try:
        return os.path.relpath(p, root)
    except ValueError:
        return p

gates = []
overall = "pass"
all_covered, all_uncovered, all_blocked = [], [], []

for tok in manifest:
    gate, exitc, rpath = (tok.split("|", 2) + ["", "", ""])[:3]
    try:
        exitc = int(exitc)
    except ValueError:
        exitc = 1

    data = None
    if rpath and os.path.exists(rpath):
        try:
            with open(rpath) as f:
                data = yaml.safe_load(f)
        except Exception as e:
            data = None

    if isinstance(data, dict):
        status  = data.get("status") or from_exit(exitc)
        summary = data.get("summary", "")
        tgt     = data.get("target", {}) or {}
        cov     = data.get("covered") or []
        unc     = data.get("uncovered") or []
        blk     = data.get("blocked") or []
        note    = None
    else:
        status  = from_exit(exitc)
        summary = "(no parseable report emitted)"
        tgt     = {}
        cov, unc, blk = [], [], []
        note    = "child harness emitted no parseable report; status derived from exit code"

    for c in cov:
        all_covered.append(f"[{gate}] {c}")
    for u in unc:
        all_uncovered.append(f"[{gate}] {u}")
    for b in blk:
        if isinstance(b, dict):
            all_blocked.append({"gate": gate,
                                "check_id": b.get("check_id"),
                                "reason": b.get("reason")})
        else:
            all_blocked.append({"gate": gate, "reason": str(b)})

    entry = {
        "gate": gate,
        "status": status,
        "exit_code": exitc,
        "report": relpath(rpath) if rpath else None,
        "target_repo": tgt.get("repo"),
        "target_branch": tgt.get("branch"),
        "target_ref": tgt.get("ref"),
        "summary": summary,
    }
    if note:
        entry["note"] = note
    gates.append(entry)

    if RANK.get(status, 3) > RANK[overall]:
        overall = status

n_pass    = sum(1 for g in gates if g["status"] == "pass")
n_total   = len(gates)
parts     = "; ".join(f"{g['gate']}:{g['status']}" for g in gates)
summary   = (f"full gate: {parts} → overall={overall} "
             f"({n_pass}/{n_total} gates green)")

doc = {
    "schema_version": 1,
    "gate": "full",
    "status": overall,
    "generated_at": gen_at,
    "gates": gates,
    "covered": all_covered,
    "uncovered": all_uncovered,
    "blocked": all_blocked,
    "summary": summary,
}

with open(out_path, "w") as f:
    yaml.safe_dump(doc, f, sort_keys=False, allow_unicode=True, default_flow_style=False)

# §3 exit code = worst-of
sys.exit({"pass": 0, "fail": 1, "blocked": 2}.get(overall, 1))
PY
agg_ec=$?

echo "[gate] gate report emitted: ${GATE_REPORT}"
echo "[gate] overall exit: ${agg_ec}"
exit "${agg_ec}"
