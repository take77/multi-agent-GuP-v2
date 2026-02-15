#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  cd "$PROJECT_ROOT"
}

@test "config/settings.yaml に agent_teams セクションが存在すること" {
  run grep "^agent_teams:" config/settings.yaml
  [ "$status" -eq 0 ]
}

@test "config/settings.yaml の既存設定（language等）が変更されていないこと" {
  run grep "^language:" config/settings.yaml
  [ "$status" -eq 0 ]
  run grep "^shell:" config/settings.yaml
  [ "$status" -eq 0 ]
}

@test "queue/hq/session_state.yaml が存在し valid な YAML であること" {
  [ -f queue/hq/session_state.yaml ]
  run python3 -c "import yaml; yaml.safe_load(open('queue/hq/session_state.yaml'))"
  [ "$status" -eq 0 ]
}

@test "scripts/monitor/package.json が存在し valid な JSON であること" {
  [ -f scripts/monitor/package.json ]
  run jq . scripts/monitor/package.json
  [ "$status" -eq 0 ]
}

@test "instructions/agent_teams/ ディレクトリが存在すること" {
  [ -d instructions/agent_teams ]
}

@test "logs/bridge/.gitkeep が存在すること" {
  [ -f logs/bridge/.gitkeep ]
}

@test "logs/monitor/.gitkeep が存在すること" {
  [ -f logs/monitor/.gitkeep ]
}
