#!/usr/bin/env bats
# test_dashboard_viewer_e2e.bats — dashboard-viewer.py e2e テスト
#
# テスト構成:
#   E2E-DV-001: dashboard.md 不在 → exit 1 + エラーメッセージ
#   E2E-DV-002: 不正ポート指定 → exit 1
#   E2E-DV-003: 起動 + HTTP レスポンス確認 → 200 OK, HTML 含む
#   E2E-DV-004: ポート使用中 → exit 1 + エラーメッセージ

# テスト用ポート (デフォルト 8787 を避ける)
TEST_PORT=19787

setup_file() {
    export PROJECT_ROOT
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export VIEWER_SCRIPT="$PROJECT_ROOT/scripts/dashboard-viewer.py"

    [ -f "$VIEWER_SCRIPT" ] || {
        echo "ERROR: dashboard-viewer.py not found at $VIEWER_SCRIPT" >&2
        return 1
    }
    command -v python3 >/dev/null 2>&1 || {
        echo "ERROR: python3 is required" >&2
        return 1
    }
    command -v curl >/dev/null 2>&1 || {
        echo "ERROR: curl is required" >&2
        return 1
    }
}

setup() {
    # テスト用 tmpdir (dashboard.md 配置用)
    TEST_DIR="$(mktemp -d "$BATS_TMPDIR/dashboard_viewer_e2e.XXXXXX")"
    export TEST_DIR
    SERVER_PID=""
    export SERVER_PID
}

teardown() {
    # サーバープロセスのクリーンアップ
    if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    [ -n "${TEST_DIR:-}" ] && [ -d "${TEST_DIR:-}" ] && rm -rf "$TEST_DIR"
}

# サーバーが起動するまで待機 (最大 5 秒)
wait_for_server() {
    local port="$1"
    local count=0
    while [ "$count" -lt 50 ]; do
        if curl -sf "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        count=$((count + 1))
    done
    return 1
}

# =============================================================================
# E2E-DV-001: dashboard.md 不在 → exit 1 + エラーメッセージ
# =============================================================================

@test "E2E-DV-001: missing dashboard.md → exit 1 with error message" {
    # git 管理外の空ディレクトリからスクリプトを実行
    # (git rev-parse に失敗 → script のディレクトリ起点になるが dashboard なし)
    run bash -c "cd '$TEST_DIR' && BROWSER=/dev/null python3 '$VIEWER_SCRIPT' --port $((TEST_PORT + 1)) 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" || "$output" =~ "Error" ]]
}

# =============================================================================
# E2E-DV-002: 不正ポート指定 → exit 1
# =============================================================================

@test "E2E-DV-002: invalid port argument → exit 1" {
    run bash -c "BROWSER=/dev/null python3 '$VIEWER_SCRIPT' --port not_a_number 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "invalid" || "$output" =~ "Error" ]]
}

# =============================================================================
# E2E-DV-003: 起動 + HTTP GET → 200 OK, HTML レスポンス確認
# =============================================================================

@test "E2E-DV-003: server starts and responds with HTML" {
    # GuP-v2 プロジェクトルートには dashboard.md が存在する (project root fallback)
    BROWSER=/dev/null python3 "$VIEWER_SCRIPT" --port "$TEST_PORT" &
    SERVER_PID=$!

    # サーバー起動を待機
    wait_for_server "$TEST_PORT" || {
        kill "$SERVER_PID" 2>/dev/null || true
        false  # タイムアウト → テスト失敗
    }

    # HTTP GET で 200 OK を確認
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${TEST_PORT}/")
    [ "$http_code" -eq 200 ]

    # レスポンスボディに HTML が含まれること
    local body
    body=$(curl -s "http://127.0.0.1:${TEST_PORT}/")
    [[ "$body" =~ "<html" || "$body" =~ "<!DOCTYPE" ]]

    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
}

# =============================================================================
# E2E-DV-004: ポート使用中 → exit 1 + エラーメッセージ
# =============================================================================

@test "E2E-DV-004: port already in use → exit 1 with error message" {
    local busy_port=$((TEST_PORT + 10))

    # ポートを先に占有
    python3 -c "
import socket, time, threading

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $busy_port))
s.listen(1)
time.sleep(3)
s.close()
" &
    local HOLDER_PID=$!

    # ポートが使われるまで少し待つ
    sleep 0.3

    run bash -c "BROWSER=/dev/null python3 '$VIEWER_SCRIPT' --port $busy_port 2>&1"
    kill "$HOLDER_PID" 2>/dev/null || true
    wait "$HOLDER_PID" 2>/dev/null || true

    [ "$status" -eq 1 ]
    [[ "$output" =~ "already in use" || "$output" =~ "Error" ]]
}
