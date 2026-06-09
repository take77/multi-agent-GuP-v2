#!/usr/bin/env bash
# A1 統合スモークゲート Phase2 — Mobile harness (ST-A)
# 契約: docs/plans/a1_smoke_gate_harness_contract.md §2/§3/§4 逐語準拠
# 雛形: scripts/smoke_gate/web_smoke.sh (P1・kay 隊・同一スキーマ/同構造)
# seam: ST-B(aki) = `flutter test integration_test/app_smoke_test.dart -d <device_id>`
#       (calsail-mobile feat/integration-smoke-test・単一テストが boot / login UI / gotrue callback-URL parse /
#        router redirect machinery を exercise)
# 成果物: queue/reports/smoke_gate/mobile_<ts>.yaml + artifacts/
# exit 0=pass / 1=fail / 2=blocked
#
# ★設計メモ — checks=2 本(android_smoke / ios_smoke):
#   seam は OS あたり【単一テストファイル 1 invocation】ゆえ OS ごとに 1 結果。機械可読 id は android_smoke/ios_smoke。
# ★coverage の誠実さ(redo R1/R2):
#   - covered = smoke が【実走(executed)】し exercise した領域のみ。build/install/infra で走る前に死んだら uncovered。
#   - aki Phase3 は getSessionFromUrl を【直呼び】ゆえ item C の OS-delivery 受信層(manifest intent-filter /
#     FlutterFragmentActivity / SDK AppLinks 購読 / _handleDeeplink / _isAuthCallbackDeeplink gate)は
#     【exercise しない】→ SMOKE_NEVER_COVERS で常に uncovered に明記(over-claim 禁止)。

set -uo pipefail

# ────────────────────────────────────────────────────────────
# 設定
# ────────────────────────────────────────────────────────────
HARNESS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_REPO="${TARGET_REPO:-/Users/take77.mac-mini/Developments/calsail/calsail-mobile}"
ARTIFACTS_DIR="${HARNESS_ROOT}/queue/reports/smoke_gate/artifacts"
REPORT_DIR="${HARNESS_ROOT}/queue/reports/smoke_gate"

# seam 契約(固定)
SMOKE_TEST_REL="integration_test/app_smoke_test.dart"
AKI_BRANCH="feat/integration-smoke-test"
ANDROID_AVD="${ANDROID_AVD:-Pixel_8_Pro}"
IOS_DEVICE_NAME="${IOS_DEVICE_NAME:-iPhone 16 Pro}"

# 実走チューニング(値非露出の運用ノブのみ)
FLUTTER_TEST_TIMEOUT="${FLUTTER_TEST_TIMEOUT:-600}"   # flutter test 1 回あたり秒
ANDROID_BOOT_TIMEOUT="${ANDROID_BOOT_TIMEOUT:-240}"   # emulator boot 待ち秒

TS="$(date +%Y%m%dT%H%M%S)"
ANDROID_LOG="${ARTIFACTS_DIR}/mobile_android_${TS}.log"
IOS_LOG="${ARTIFACTS_DIR}/mobile_ios_${TS}.log"
ANDROID_SHOT="${ARTIFACTS_DIR}/mobile_android_${TS}.png"
IOS_SHOT="${ARTIFACTS_DIR}/mobile_ios_${TS}.png"
REPORT_FILE="${REPORT_DIR}/mobile_${TS}.yaml"

mkdir -p "${ARTIFACTS_DIR}"

# 実行時に確定する device 識別子(teardown 対象判定に使用)
ANDROID_SERIAL=""
IOS_UDID=""
BOOTED_ANDROID=0   # この harness が boot した場合のみ 1(=teardown 対象)
BOOTED_IOS=0

# timeout バイナリ解決(macOS 既定は無し → 在れば flutter test を wrap)
TIMEOUT_BIN=""
if command -v timeout &>/dev/null; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_BIN="gtimeout"
fi

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

start_time() { date +%s; }
elapsed() { echo $(( $(date +%s) - $1 )); }

# flutter test 出力から SKIP(>0) を検出(SKIP=FAIL ルール)
# compact reporter の集計行 "+N ~M -K" の ~M を拾う。fallback で "skipped" キーワード。
detect_skip_count() {
  local f="$1" n
  [[ -f "$f" ]] || { echo 0; return; }
  n=$(grep -oE '~[0-9]+' "$f" 2>/dev/null | tail -1 | tr -d '~')
  if [[ -n "${n:-}" && "${n}" -gt 0 ]]; then echo "$n"; return; fi
  if grep -qiE '[1-9][0-9]* skipped' "$f" 2>/dev/null; then
    grep -oiE '[0-9]+ skipped' "$f" | grep -oE '[0-9]+' | head -1
    return
  fi
  echo 0
}

# flutter test 非ゼロ終了ログを分類し CLS_STATUS / CLS_DETAIL / CLS_EXECUTED を設定する。
# ★下流文言(「Unable to start the app」は build/install 両方で出る)で判定せず、
#   【specific な上流原因】で精密に切る(feedback_map_error_string_to_branch・redo R3/R4 で精度強化)。
# ★CLS_EXECUTED: smoke が実際に【走ったか】(=1) / build/install/infra で走る前に死んだか(=0)。
#   covered/uncovered の真の判定軸(redo R2: build-fail を covered に化けさせない)。
#  分岐(precedence 順):
#   1) genuinely-INFRA(storage 満杯/no space/device offline/adb daemon 不通)
#      → blocked / executed=0。判定不能=要 device 復旧(契約 §3)。★INSTALL_FAILED 全般は infra にしない(R3)。
#   2) 既知・変更非関連の standing toolchain debt(iOS MLImage arm64 iOS-sim link)= 狭 signature
#      → blocked(known debt)/ executed=0。恒常 red の cry-wolf を回避(R4)。UNKNOWN build 失敗は下の fail へ。
#   3) UNKNOWN build/link/install-code 失敗(Could not build/Linker/Gradle task failed/xcodebuild error/
#      INSTALL_FAILED_*・MANIFEST・NO_MATCHING_ABIS・PARSE_FAILED 等の code/packaging 由来)
#      → fail / executed=0。app 起動せず=新規回帰候補として赤で晒す(R3: code 回帰を infra に握り潰さない)。
#   4) それ以外(app は起動・assertion 赤 / timeout)→ fail / executed=1。
classify_outcome() {
  local f="$1" os="$2"
  # 1) genuinely-infra のみ(install_failed 全般を含めない)
  if grep -qiE 'INSUFFICIENT_STORAGE|No space left|device .*offline|error: device .*not found|cannot connect to daemon|daemon (not running|still not running)' "$f" 2>/dev/null; then
    CLS_STATUS="blocked"; CLS_EXECUTED=0
    CLS_DETAIL="${os} smoke could not execute: host/device INFRA failure (emulator storage full / device offline / adb daemon) — free space or re-provision device & retry. NOT a code regression. see log artifact"
    return
  fi
  # 2) 既知 standing toolchain debt = 狭 signature(MLImage arm64 iOS-sim link)。過剰一致禁止。
  if grep -qiE "MLImage(\.framework)?\[arm64\]|MLImage.* built for 'iOS'|MLImage.*iOS-simulator" "$f" 2>/dev/null; then
    CLS_STATUS="blocked"; CLS_EXECUTED=0
    CLS_DETAIL="${os} smoke could not execute: KNOWN standing toolchain debt (MLImage arm64 iOS-simulator link block — pre-existing & change-unrelated; backlog=docs/spike iOS-sim native). NOT a new regression. see log artifact"
    return
  fi
  # 3) UNKNOWN build/link/install-code 失敗(app 起動せず・新規回帰候補)→ fail
  if grep -qiE 'Could not build the application|Failed to build|Linker command failed|xcodebuild.*[Ee]rror|Gradle task .* failed|INSTALL_FAILED|INSTALL_PARSE_FAILED|NO_MATCHING_ABIS|MANIFEST|DUPLICATE_PERMISSION|adb: failed to install|Unable to start the app' "$f" 2>/dev/null; then
    CLS_STATUS="fail"; CLS_EXECUTED=0
    CLS_DETAIL="${os} app BUILD/INSTALL failed (app did not run — build/packaging/manifest/ABI). Investigate as code/config regression unless a known toolchain debt. see log artifact"
    return
  fi
  # 4) app は起動・assertion 赤 / timeout
  CLS_STATUS="fail"; CLS_EXECUTED=1
  CLS_DETAIL="${os} flutter test ran but did not pass (assertion failure or timeout; app launched). see log artifact"
}

# flutter test 駆動(timeout 在れば wrap)。戻り値 = flutter の exit code。
run_device_smoke() {
  local dev="$1" log="$2"
  if [[ -n "$TIMEOUT_BIN" ]]; then
    ( cd "${TARGET_REPO}" && "$TIMEOUT_BIN" "$FLUTTER_TEST_TIMEOUT" \
        flutter test "${SMOKE_TEST_REL}" -d "$dev" > "$log" 2>&1 )
  else
    ( cd "${TARGET_REPO}" && \
        flutter test "${SMOKE_TEST_REL}" -d "$dev" > "$log" 2>&1 )
  fi
}

# ────────────────────────────────────────────────────────────
# teardown(trap): 【自分が boot した device のみ】安全停止
#   iOS  = xcrun simctl shutdown  (kill 系でない・明確に安全)
#   Android = adb -s <serial> emu kill (emulator console コマンド = device-scoped。
#             shell の kill/killall/pkill = D006 とは別物・他 process/agent に波及不可)
#   MOBILE_SMOKE_NO_TEARDOWN を set すると後始末を skip(device を残したい運用向け)。
# ────────────────────────────────────────────────────────────
teardown() {
  if [[ -n "${MOBILE_SMOKE_NO_TEARDOWN:-}" ]]; then
    echo "[smoke] teardown skipped (MOBILE_SMOKE_NO_TEARDOWN set)"
    return
  fi
  if [[ "${BOOTED_IOS}" == "1" && -n "${IOS_UDID}" ]]; then
    echo "[smoke] teardown: shutdown iOS simulator"
    xcrun simctl shutdown "${IOS_UDID}" >/dev/null 2>&1 || true
  fi
  if [[ "${BOOTED_ANDROID}" == "1" && -n "${ANDROID_SERIAL}" ]]; then
    echo "[smoke] teardown: stop Android emulator (${ANDROID_SERIAL})"
    adb -s "${ANDROID_SERIAL}" emu kill >/dev/null 2>&1 || true
  fi
}
trap teardown EXIT

# ────────────────────────────────────────────────────────────
# §4 Preflight — hard 前提(欠如 = 全 check blocked + exit 2)
# ────────────────────────────────────────────────────────────
preflight_fail=0

for cmd in flutter git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[preflight] MISSING tool: $cmd" >&2
    preflight_fail=1
  fi
done

if [[ ! -d "${TARGET_REPO}" ]]; then
  echo "[preflight] MISSING target repo: ${TARGET_REPO}" >&2
  preflight_fail=1
fi

if [[ "$preflight_fail" -ne 0 ]]; then
  cat > "${REPORT_FILE}" <<YAML
schema_version: 1
gate: mobile
status: blocked
generated_at: "$(date +%Y-%m-%dT%H:%M:%S)"
target:
  repo: calsail-mobile
  path: ${TARGET_REPO}
  branch: unknown
  ref: unknown
checks:
  - id: android_smoke
    name: "Android smoke (flutter test integration_test/app_smoke_test.dart -d Pixel_8_Pro)"
    status: blocked
    duration_s: 0
    detail: "preflight failed: required tool/repo missing (flutter/git/target repo)"
    artifact: ""
  - id: ios_smoke
    name: "iOS smoke (flutter test integration_test/app_smoke_test.dart -d iPhone 16 Pro)"
    status: blocked
    duration_s: 0
    detail: "preflight failed: required tool/repo missing (flutter/git/target repo)"
    artifact: ""
covered: []
uncovered:
  - "Android smoke NOT executed (blocked): preflight failed — required tool/repo missing"
  - "iOS smoke NOT executed (blocked): preflight failed — required tool/repo missing"
  - "item C OS-delivery RECEIVE layer (manifest / FlutterFragmentActivity / AppLinks / _handleDeeplink): NOT exercised"
  - "production deep-link error path / flash / PKCE success token-exchange: NOT exercised"
blocked:
  - check_id: android_smoke
    reason: "required tool/repo missing (flutter/git/${TARGET_REPO}) — install flutter+git and ensure calsail-mobile checked out, then retry"
  - check_id: ios_smoke
    reason: "required tool/repo missing (flutter/git/${TARGET_REPO}) — install flutter+git and ensure calsail-mobile checked out, then retry"
summary: "preflight failed: required tool/repo missing"
YAML
  echo "[smoke] report: ${REPORT_FILE}"
  exit 2
fi

# target repo の branch/ref 取得
TARGET_BRANCH="$(git -C "${TARGET_REPO}" branch --show-current 2>/dev/null || echo unknown)"
TARGET_REF="$(git -C "${TARGET_REPO}" rev-parse HEAD 2>/dev/null || echo unknown)"

# ────────────────────────────────────────────────────────────
# §4 Preflight — per-check soft 前提(不成立 = 該当 check blocked・silent skip 禁止)
#   ★名前ベース確認のみ(値・UDID を露出しない)
# ────────────────────────────────────────────────────────────

# seam: aki のテストファイルが working-tree に在るか(= aki branch checkout 済)
seam_ready=0
if [[ -f "${TARGET_REPO}/${SMOKE_TEST_REL}" ]]; then
  seam_ready=1
fi

# Android AVD(Pixel_8_Pro)が available か + adb/emulator 在
android_ready=0
android_block_reason=""
if ! command -v adb &>/dev/null || ! command -v emulator &>/dev/null; then
  android_block_reason="adb/emulator not on PATH — install Android SDK platform-tools+emulator and retry"
elif ! emulator -list-avds 2>/dev/null | grep -qx "${ANDROID_AVD}"; then
  android_block_reason="AVD '${ANDROID_AVD}' not found — create it via avdmanager (name-based check) and retry"
else
  android_ready=1
fi

# iOS simulator(iPhone 16 Pro)が available か + xcrun 在
ios_ready=0
ios_block_reason=""
if ! command -v xcrun &>/dev/null; then
  ios_block_reason="xcrun not on PATH — install Xcode command line tools and retry"
elif ! xcrun simctl list devices available 2>/dev/null | grep -qE "${IOS_DEVICE_NAME} \("; then
  ios_block_reason="simulator '${IOS_DEVICE_NAME}' not available — create it in Xcode (name-based check) and retry"
else
  ios_ready=1
fi

# seam 未 ready は両 OS check を blocked(device は boot しない)
if [[ "$seam_ready" -ne 0 ]]; then
  echo "[smoke] seam ready: ${SMOKE_TEST_REL} present"
else
  echo "[smoke] seam NOT ready: ${SMOKE_TEST_REL} absent (aki ST-B / ${AKI_BRANCH} 未 checkout)"
fi

# ────────────────────────────────────────────────────────────
# boot ヘルパ
# ────────────────────────────────────────────────────────────

# 起動中 emulator から ANDROID_AVD に一致する serial を返す(無ければ空・非ゼロ)
# ★複数 emulator 同時起動時に「最初の emulator-」でなく【AVD 名一致】で正しい台を選ぶ。
find_android_serial_by_avd() {
  local s name
  for s in $(adb devices 2>/dev/null | awk '/^emulator-/{print $1}'); do
    name="$(adb -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    if [[ "$name" == "${ANDROID_AVD}" ]]; then echo "$s"; return 0; fi
  done
  return 1
}

# Android emulator(Pixel_8_Pro)を起動 → boot_completed 待ち → serial 解決
# ★ownership-safe(redo R5): teardown するのは【この harness が自分で launch した serial】だけ。
#   - 既に該当 AVD が起動済(他 agent の台かもしれない)なら reuse し、BOOTED_ANDROID は立てない(=teardown 対象外)。
#   - launch する場合は、launch 前の emulator serial を snapshot し、launch 後に【新規出現した serial】のみを
#     所有とみなして ANDROID_SERIAL/BOOTED_ANDROID を確定する(serial 解決前に BOOTED を立てない)。
#   ＝D006 の精神(他 process/agent へ波及不可)を device lifecycle にも適用。他者の同名 AVD を絶対 kill しない。
boot_android() {
  adb start-server >/dev/null 2>&1 || true
  local existing bc
  existing="$(find_android_serial_by_avd)"
  if [[ -n "$existing" ]]; then
    bc="$(adb -s "$existing" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$bc" == "1" ]]; then
      ANDROID_SERIAL="$existing"
      echo "[smoke] android: reuse already-running ${ANDROID_AVD} (${ANDROID_SERIAL}) — NOT owned (teardown 対象外)"
      return 0
    fi
  fi
  # launch 前の emulator serial を snapshot(これらは「自分の台ではない」=teardown 対象外)
  local before_serials
  before_serials=" $(adb devices 2>/dev/null | awk '/^emulator-/{print $1}' | sort | tr '\n' ' ') "
  echo "[smoke] android: launch ${ANDROID_AVD} (pre-existing serials snapshotted for ownership)"
  flutter emulators --launch "${ANDROID_AVD}" >/dev/null 2>&1 || \
    ( emulator -avd "${ANDROID_AVD}" -no-snapshot -no-boot-anim >/dev/null 2>&1 & )
  local waited=0 s name
  while [[ $waited -lt $ANDROID_BOOT_TIMEOUT ]]; do
    for s in $(adb devices 2>/dev/null | awk '/^emulator-/{print $1}'); do
      # snapshot に在った serial(=他者/既存の台)は所有しない
      case "$before_serials" in *" $s "*) continue ;; esac
      name="$(adb -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
      [[ "$name" == "${ANDROID_AVD}" ]] || continue
      bc="$(adb -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
      if [[ "$bc" == "1" ]]; then
        ANDROID_SERIAL="$s"
        BOOTED_ANDROID=1   # ★所有確定後にのみ立てる(=この serial だけ teardown 対象)
        echo "[smoke] android: launched & owned new serial ${ANDROID_SERIAL} (teardown 対象)"
        return 0
      fi
    done
    sleep 3
    waited=$((waited + 3))
  done
  return 1
}

# iOS simulator(iPhone 16 Pro)の UDID を name から解決 → boot → bootstatus 待ち
# ★既に Booted な該当 sim を優先 reuse(BOOTED_IOS は立てない=teardown 対象外。二重 boot/他者の台 shutdown を避ける)。
UDID_RE='[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}'
boot_ios() {
  local line booted_line state
  booted_line="$(xcrun simctl list devices 2>/dev/null | grep -E "${IOS_DEVICE_NAME} \(" | grep '(Booted)' | head -1)"
  if [[ -n "$booted_line" ]]; then
    IOS_UDID="$(echo "$booted_line" | grep -oE "$UDID_RE" | head -1)"
    if [[ -n "$IOS_UDID" ]]; then
      echo "[smoke] ios: reuse already-booted ${IOS_DEVICE_NAME} — teardown 対象外"
      return 0
    fi
  fi
  line="$(xcrun simctl list devices available 2>/dev/null | grep -E "${IOS_DEVICE_NAME} \(" | head -1)"
  IOS_UDID="$(echo "$line" | grep -oE "$UDID_RE" | head -1)"
  [[ -z "$IOS_UDID" ]] && return 1
  state="$(xcrun simctl list devices 2>/dev/null | grep "$IOS_UDID" | grep -oE '\((Booted|Shutdown|Booting)\)' | tr -d '()' | head -1)"
  if [[ "$state" != "Booted" ]]; then
    xcrun simctl boot "$IOS_UDID" >/dev/null 2>&1 && BOOTED_IOS=1
  fi
  # boot 完了まで待機(自己バウンド)
  xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null 2>&1 || true
  return 0
}

# ────────────────────────────────────────────────────────────
# ★smoke が【実際に exercise する】領域(honest・redo R1 で item C 受信層の over-claim を是正)。
#   aki ST-B(app_smoke_test.dart)の genuinely-covered と揃える。受信層/flash/PKCE は SMOKE_NEVER_COVERS で uncovered。
# ────────────────────────────────────────────────────────────
SMOKE_COVERS_DESC="boot crash-free→/login; login UI render (Google/Apple); gotrue callback-URL parse (error-fragment, crash-free surface, /login retained); router redirect machinery (session→/, signOut→/login)"

# ────────────────────────────────────────────────────────────
# check A: android_smoke
#   android_executed: smoke が実走したか(=1 covered 軸 / =0 build/install/infra で走る前に死亡=uncovered・R2)
# ────────────────────────────────────────────────────────────
android_status="pass"
android_detail=""
android_executed=0
t0=$(start_time)

if [[ "$seam_ready" -eq 0 ]]; then
  android_status="blocked"; android_executed=0
  android_detail="seam not ready: ${SMOKE_TEST_REL} absent (aki ${AKI_BRANCH} 未 checkout)"
  set_status "blocked"
  echo "[smoke] check A android_smoke: blocked (seam absent)"
elif [[ "$android_ready" -eq 0 ]]; then
  android_status="blocked"; android_executed=0
  android_detail="preflight blocked: ${android_block_reason}"
  set_status "blocked"
  echo "[smoke] check A android_smoke: blocked (${android_block_reason})"
else
  echo "[smoke] check A android_smoke: boot ${ANDROID_AVD} ..."
  if ! boot_android; then
    android_status="blocked"; android_executed=0
    android_detail="Android emulator '${ANDROID_AVD}' did not reach boot_completed within ${ANDROID_BOOT_TIMEOUT}s (host/device infra)"
    set_status "blocked"
    echo "[smoke] check A android_smoke: blocked (boot timeout)"
  else
    echo "[smoke] check A android_smoke: flutter test on ${ANDROID_SERIAL} ..."
    if ! run_device_smoke "${ANDROID_SERIAL}" "${ANDROID_LOG}"; then
      classify_outcome "${ANDROID_LOG}" Android
      android_status="$CLS_STATUS"
      android_detail="$CLS_DETAIL"
      android_executed="$CLS_EXECUTED"
      set_status "$android_status"
    else
      skip_n="$(detect_skip_count "${ANDROID_LOG}")"
      if [[ "${skip_n:-0}" -gt 0 ]]; then
        android_status="fail"; android_executed=1
        android_detail="Android smoke EXECUTED but ${skip_n} test(s) skipped (SKIP=FAIL rule)"
        set_status "fail"
      else
        android_status="pass"; android_executed=1
        android_detail="Android smoke EXECUTED & passed: ${SMOKE_COVERS_DESC}"
      fi
    fi
    # スクショ(best-effort・失敗しても check を落とさない)
    adb -s "${ANDROID_SERIAL}" exec-out screencap -p > "${ANDROID_SHOT}" 2>/dev/null || \
      echo "[smoke] android screenshot skipped (best-effort)"
  fi
fi
android_dur=$(elapsed "$t0")
echo "[smoke] check A done: ${android_status} executed=${android_executed} (${android_dur}s)"

# ────────────────────────────────────────────────────────────
# check B: ios_smoke
# ────────────────────────────────────────────────────────────
ios_status="pass"
ios_detail=""
ios_executed=0
t0=$(start_time)

if [[ "$seam_ready" -eq 0 ]]; then
  ios_status="blocked"; ios_executed=0
  ios_detail="seam not ready: ${SMOKE_TEST_REL} absent (aki ${AKI_BRANCH} 未 checkout)"
  set_status "blocked"
  echo "[smoke] check B ios_smoke: blocked (seam absent)"
elif [[ "$ios_ready" -eq 0 ]]; then
  ios_status="blocked"; ios_executed=0
  ios_detail="preflight blocked: ${ios_block_reason}"
  set_status "blocked"
  echo "[smoke] check B ios_smoke: blocked (${ios_block_reason})"
else
  echo "[smoke] check B ios_smoke: boot ${IOS_DEVICE_NAME} ..."
  if ! boot_ios; then
    ios_status="blocked"; ios_executed=0
    ios_detail="iOS simulator '${IOS_DEVICE_NAME}' could not be resolved/booted (host/device infra)"
    set_status "blocked"
    echo "[smoke] check B ios_smoke: blocked (boot failed)"
  else
    echo "[smoke] check B ios_smoke: flutter test on iOS simulator ..."
    if ! run_device_smoke "${IOS_UDID}" "${IOS_LOG}"; then
      classify_outcome "${IOS_LOG}" iOS
      ios_status="$CLS_STATUS"
      ios_detail="$CLS_DETAIL"
      ios_executed="$CLS_EXECUTED"
      set_status "$ios_status"
    else
      skip_n="$(detect_skip_count "${IOS_LOG}")"
      if [[ "${skip_n:-0}" -gt 0 ]]; then
        ios_status="fail"; ios_executed=1
        ios_detail="iOS smoke EXECUTED but ${skip_n} test(s) skipped (SKIP=FAIL rule)"
        set_status "fail"
      else
        ios_status="pass"; ios_executed=1
        ios_detail="iOS smoke EXECUTED & passed: ${SMOKE_COVERS_DESC}"
      fi
    fi
    # スクショ(best-effort)
    xcrun simctl io "${IOS_UDID}" screenshot "${IOS_SHOT}" >/dev/null 2>&1 || \
      echo "[smoke] ios screenshot skipped (best-effort)"
  fi
fi
ios_dur=$(elapsed "$t0")
echo "[smoke] check B done: ${ios_status} executed=${ios_executed} (${ios_dur}s)"

# ────────────────────────────────────────────────────────────
# covered / uncovered 集計（redo R2: 真の軸は executed = smoke が実走したか）
#   - executed=1（pass / assertion-fail）→ covered（実際に exercise した）
#   - executed=0（build/install/infra/known-debt で走る前に死亡）→ uncovered（理由付・covered に化けさせない）
#   - status==blocked（infra / known toolchain debt）→ blocked[] にも理由を記載
# ★契約§2「executed-but-failed=covered」の "executed" を厳密化（build 前に死んだら未 executed）。
# ────────────────────────────────────────────────────────────
covered=()
uncovered=()
blocked_entries=""

# Android
if [[ "$android_executed" == "1" ]]; then
  covered+=("Android smoke EXECUTED (${android_status}): ${SMOKE_COVERS_DESC}")
else
  uncovered+=("Android smoke NOT executed (${android_status}): ${android_detail}")
fi
if [[ "$android_status" == "blocked" ]]; then
  blocked_entries+="  - check_id: android_smoke
    reason: \"${android_detail}\"
"
fi

# iOS
if [[ "$ios_executed" == "1" ]]; then
  covered+=("iOS smoke EXECUTED (${ios_status}): ${SMOKE_COVERS_DESC}")
else
  uncovered+=("iOS smoke NOT executed (${ios_status}): ${ios_detail}")
fi
if [[ "$ios_status" == "blocked" ]]; then
  blocked_entries+="  - check_id: ios_smoke
    reason: \"${ios_detail}\"
"
fi

# ★smoke が【本質的に exercise しない】領域（実走の成否に依らず常に uncovered・redo R1 honesty）。
#   auth Wave が現に住んでいた item C 受信層を「covered」と読ませない。aki ST-B header の uncovered と揃える。
uncovered+=("item C OS-delivery RECEIVE layer (manifest intent-filter / FlutterFragmentActivity / SDK AppLinks subscription / _handleDeeplink / _isAuthCallbackDeeplink gate): Phase3 が getSessionFromUrl を直呼びゆえ受信経路は NOT exercised")
uncovered+=("production deep-link error path (_handleDeeplink→notifyException stream-error・raw throw でない): NOT exercised")
uncovered+=("flash (削除後 settings 一瞬露出 UX): NOT exercised")
uncovered+=("PKCE success token-exchange: NOT exercised")

# YAML フィールド生成(key 込み): 空 = 「key: []」(同一行・valid flow seq) / 非空 = block list。
# ★empty を別行 "[]" にすると "key:\n[]" となり YAML パース不能(P3 run_gate が機械可読に読めない)ため key を同梱する。
yaml_field() {
  local key="$1"; shift
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    printf '%s: []' "$key"
  else
    printf '%s:' "$key"
    local item
    for item in "${arr[@]}"; do
      printf '\n  - "%s"' "$item"
    done
  fi
}

covered_field="$(yaml_field covered "${covered[@]+"${covered[@]}"}")"
uncovered_field="$(yaml_field uncovered "${uncovered[@]+"${uncovered[@]}"}")"

if [[ -z "$blocked_entries" ]]; then
  blocked_yaml="[]"
else
  # 末尾改行を保持しつつ heredoc 内へ
  blocked_yaml=$'\n'"${blocked_entries%$'\n'}"
fi

summary="android:${android_status}; ios:${ios_status}"

# ────────────────────────────────────────────────────────────
# §2 report emit
# ────────────────────────────────────────────────────────────
cat > "${REPORT_FILE}" <<YAML
schema_version: 1
gate: mobile
status: ${overall_status}
generated_at: "$(date +%Y-%m-%dT%H:%M:%S)"
target:
  repo: calsail-mobile
  path: ${TARGET_REPO}
  branch: ${TARGET_BRANCH}
  ref: "${TARGET_REF}"
checks:
  - id: android_smoke
    name: "Android smoke (flutter test ${SMOKE_TEST_REL} -d ${ANDROID_AVD})"
    status: ${android_status}
    duration_s: ${android_dur}
    detail: "${android_detail}"
    artifact: "${ANDROID_LOG}"
  - id: ios_smoke
    name: "iOS smoke (flutter test ${SMOKE_TEST_REL} -d ${IOS_DEVICE_NAME})"
    status: ${ios_status}
    duration_s: ${ios_dur}
    detail: "${ios_detail}"
    artifact: "${IOS_LOG}"
${covered_field}
${uncovered_field}
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
