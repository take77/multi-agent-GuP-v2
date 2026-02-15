#!/usr/bin/env bats

@test "ヘルプに --agent-teams が表示される" {
  cd ~/Developments/Tools/multi-agent-GuP-v2/
  ./gup_v2_launch.sh -h | grep -q "\-\-agent-teams"
}
