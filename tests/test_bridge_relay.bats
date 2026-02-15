#!/usr/bin/env bats

setup() {
  cd ~/Developments/Tools/multi-agent-GuP-v2/
}

@test "bridge_relay.sh が存在する" {
  [ -f scripts/bridge_relay.sh ]
  [ -x scripts/bridge_relay.sh ]
}

@test "下り変換で cmd_id が返る" {
  # bridge_relay.sh down を実行し、cmd_id が返ることを確認
  result=$(bash scripts/bridge_relay.sh down test_captain test_cluster "テストメッセージ" "test-proj" "high" "テスト受入基準")
  # cmd_xxx 形式の文字列が返ることを確認
  [[ "$result" =~ ^cmd_[0-9]+$ ]]
}

@test "source: agent_teams が付与される" {
  # YAML生成を確認
  bash scripts/bridge_relay.sh down test_captain test_cluster "テスト" "test-proj" "medium" "基準" > /dev/null
  # queue/captain_to_vice_captain.yaml に source: agent_teams が含まれることを確認
  grep -q "source: agent_teams" queue/captain_to_vice_captain.yaml
}
