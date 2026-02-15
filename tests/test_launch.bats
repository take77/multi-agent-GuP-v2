#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  cd "$PROJECT_ROOT"
}

@test "ヘルプに --agent-teams が表示される" {
  ./gup_v2_launch.sh -h | grep -q "\-\-agent-teams"
}
