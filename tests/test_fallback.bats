#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  cd "$PROJECT_ROOT"
}

@test "fallback_to_tmux.sh が存在する" {
  [ -f scripts/fallback_to_tmux.sh ]
  [ -x scripts/fallback_to_tmux.sh ]
}

@test "tmux セッションなしでもエラーにならない" {
  # tmux セッション未存在環境でも exit 0 で終了することを確認
  run bash scripts/fallback_to_tmux.sh
  [ "$status" -eq 0 ]
}
