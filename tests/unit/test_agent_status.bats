#!/usr/bin/env bats
# test_agent_status.bats — lib/agent_status.sh ユニットテスト
#
# テスト構成:
#   T-AS-001: get_squad_member_ids — maho squad のメンバーを正しく返す
#   T-AS-002: get_squad_member_ids — フィルタなしで全 squad のメンバーを返す
#   T-AS-003: get_captain_for_agent — fukuda の隊長は maho を返す
#   T-AS-004: get_captain_for_agent — maho（隊長本人）は空文字を返す
#   T-AS-005: detect_agent_state — 存在しないエージェントは not_found を返す
#   T-AS-006: get_pane_metadata — 空引数は空文字を返す

setup() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export LIB="$PROJECT_ROOT/lib/agent_status.sh"
}

# =============================================================================
# get_squad_member_ids
# =============================================================================

@test "T-AS-001: get_squad_member_ids maho returns maho squad members" {
    run bash -c "source '$LIB' && get_squad_member_ids maho"
    [ "$status" -eq 0 ]
    [[ "$output" == *"maho"* ]]
    [[ "$output" == *"erika"* ]]
    [[ "$output" == *"fukuda"* ]]
}

@test "T-AS-002: get_squad_member_ids no-arg returns members from all squads" {
    run bash -c "source '$LIB' && get_squad_member_ids"
    [ "$status" -eq 0 ]
    [[ "$output" == *"maho"* ]]
    [[ "$output" == *"katyusha"* ]]
    [[ "$output" == *"darjeeling"* ]]
    [[ "$output" == *"kay"* ]]
}

# =============================================================================
# get_captain_for_agent
# =============================================================================

@test "T-AS-003: get_captain_for_agent fukuda returns maho" {
    run bash -c "source '$LIB' && get_captain_for_agent fukuda"
    [ "$status" -eq 0 ]
    [ "$output" = "maho" ]
}

@test "T-AS-004: get_captain_for_agent maho (captain itself) returns empty" {
    run bash -c "source '$LIB' && get_captain_for_agent maho"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# =============================================================================
# detect_agent_state
# =============================================================================

@test "T-AS-005: detect_agent_state with nonexistent agent returns not_found" {
    run bash -c "source '$LIB' && detect_agent_state __nonexistent_agent_zzz__"
    [ "$status" -eq 0 ]
    [ "$output" = "not_found" ]
}

# =============================================================================
# get_pane_metadata
# =============================================================================

@test "T-AS-006: get_pane_metadata with empty pane_target returns empty string" {
    run bash -c "source '$LIB' && get_pane_metadata '' 'agent_id'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
