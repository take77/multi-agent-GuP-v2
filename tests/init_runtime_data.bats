#!/usr/bin/env bats
# init_runtime_data.bats — init_runtime_data.sh のテスト

# --- セットアップ ---

setup_file() {
  export PROJECT_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export INIT_SCRIPT="$PROJECT_ROOT_REAL/scripts/init_runtime_data.sh"

  [ -f "$INIT_SCRIPT" ] || {
    echo "ERROR: $INIT_SCRIPT が見つかりません" >&2
    return 1
  }
}

setup() {
  # テスト毎に独立した一時ディレクトリを作成し、本番環境を汚さない
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d "${BATS_TMPDIR}/init_runtime_data_test.XXXXXX")"

  # テスト用ミニプロジェクト構造を構築
  mkdir -p "$TEST_TMPDIR/config"
  mkdir -p "$TEST_TMPDIR/queue/inbox"
  mkdir -p "$TEST_TMPDIR/scripts"
  mkdir -p "$TEST_TMPDIR/saytask"
  mkdir -p "$TEST_TMPDIR/coordination"

  # 本番の config/squads.yaml をコピー
  cp "$PROJECT_ROOT_REAL/config/squads.yaml" "$TEST_TMPDIR/config/squads.yaml"

  # saytask/streaks.yaml.sample をコピー（存在する場合）
  if [ -f "$PROJECT_ROOT_REAL/saytask/streaks.yaml.sample" ]; then
    cp "$PROJECT_ROOT_REAL/saytask/streaks.yaml.sample" "$TEST_TMPDIR/saytask/streaks.yaml.sample"
  fi
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# PROJECT_ROOT を TEST_TMPDIR に向けてスクリプトを実行するヘルパー
run_init() {
  PROJECT_ROOT="$TEST_TMPDIR" bash "$INIT_SCRIPT"
}

# ----------------------------------------------------------------
# テストケース 1: ファイルが無い状態で実行 → 全ファイル生成される
# ----------------------------------------------------------------
@test "TC1: ファイルが無い状態で実行すると全ファイルが生成される" {
  run run_init
  [ "$status" -eq 0 ]

  # queue/ntfy_inbox.yaml
  [ -f "$TEST_TMPDIR/queue/ntfy_inbox.yaml" ]

  # saytask ファイル
  [ -f "$TEST_TMPDIR/saytask/tasks.yaml" ]
  [ -f "$TEST_TMPDIR/saytask/counter.yaml" ]
  [ -f "$TEST_TMPDIR/saytask/streaks.yaml" ]

  # coordination ファイル
  [ -f "$TEST_TMPDIR/coordination/heartbeat_darjeeling.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/heartbeat_katyusha.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/heartbeat_kay.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/heartbeat_maho.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/session_state.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/commander_to_staff.yaml" ]
  [ -f "$TEST_TMPDIR/coordination/master_dashboard.md" ]
}

# ----------------------------------------------------------------
# テストケース 2: ファイルが既存の状態で実行 → 上書きされない
# ----------------------------------------------------------------
@test "TC2: 既存ファイルは上書きされない" {
  # 事前にファイルを作成してカスタム内容を書き込む
  echo "custom_content: keep_me" > "$TEST_TMPDIR/queue/ntfy_inbox.yaml"
  echo "custom_tasks: do_not_overwrite" > "$TEST_TMPDIR/saytask/tasks.yaml"
  echo "custom_counter: 99" > "$TEST_TMPDIR/saytask/counter.yaml"
  echo "custom_streaks: preserve" > "$TEST_TMPDIR/saytask/streaks.yaml"
  echo "custom_state: running" > "$TEST_TMPDIR/coordination/session_state.yaml"

  run run_init
  [ "$status" -eq 0 ]

  # 内容が変わっていないことを確認
  grep -q "custom_content: keep_me" "$TEST_TMPDIR/queue/ntfy_inbox.yaml"
  grep -q "custom_tasks: do_not_overwrite" "$TEST_TMPDIR/saytask/tasks.yaml"
  grep -q "custom_counter: 99" "$TEST_TMPDIR/saytask/counter.yaml"
  grep -q "custom_streaks: preserve" "$TEST_TMPDIR/saytask/streaks.yaml"
  grep -q "custom_state: running" "$TEST_TMPDIR/coordination/session_state.yaml"

  # 出力に [skip] が含まれていることを確認
  [[ "$output" == *"[skip]"* ]]
}

# ----------------------------------------------------------------
# テストケース 3: 生成されたYAMLが正常にパースできる
# ----------------------------------------------------------------
@test "TC3: 生成されたYAMLが正常に読み取れる（構文チェック）" {
  run run_init
  [ "$status" -eq 0 ]

  # python3 + yaml があれば厳密にパース、なければ grep で簡易チェック
  if python3 -c "import yaml" 2>/dev/null; then
    for yaml_file in \
      "$TEST_TMPDIR/queue/ntfy_inbox.yaml" \
      "$TEST_TMPDIR/saytask/tasks.yaml" \
      "$TEST_TMPDIR/saytask/counter.yaml" \
      "$TEST_TMPDIR/saytask/streaks.yaml" \
      "$TEST_TMPDIR/coordination/heartbeat_darjeeling.yaml" \
      "$TEST_TMPDIR/coordination/session_state.yaml" \
      "$TEST_TMPDIR/coordination/commander_to_staff.yaml"; do
      python3 -c "import yaml, sys; yaml.safe_load(open('${yaml_file}'))" \
        || { echo "YAML parse failed: ${yaml_file}" >&2; return 1; }
    done
  else
    # 簡易チェック
    grep -q "messages" "$TEST_TMPDIR/queue/ntfy_inbox.yaml"
    grep -q "tasks" "$TEST_TMPDIR/saytask/tasks.yaml"
    grep -q "next_id" "$TEST_TMPDIR/saytask/counter.yaml"
    grep -q "streak" "$TEST_TMPDIR/saytask/streaks.yaml"
  fi
}

# ----------------------------------------------------------------
# テストケース 4: 必要な全ファイルが揃っていることの確認
# ----------------------------------------------------------------
@test "TC4: squads.yaml の全エージェント分の inbox ファイルが生成される" {
  run run_init
  [ "$status" -eq 0 ]

  # squads.yaml から期待するエージェントを抽出（CRLF 対応）
  expected_agents=()
  while IFS= read -r agent; do
    [ -n "$agent" ] && expected_agents+=("$agent")
  done < <(
    grep -E '^    (captain|vice_captain): ' "$TEST_TMPDIR/config/squads.yaml" \
      | awk '{print $2}' | tr -d '\r'
    grep -E '^      - [a-zA-Z_]' "$TEST_TMPDIR/config/squads.yaml" \
      | awk '{print $2}' | tr -d '\r'
  )

  # 各エージェントの inbox ファイルが生成されているか確認
  for agent in "${expected_agents[@]}"; do
    [ -f "$TEST_TMPDIR/queue/inbox/${agent}.yaml" ] \
      || { echo "Missing inbox: ${agent}" >&2; return 1; }
  done

  # 合計28エージェント分（4隊 × 7名: captain + vice_captain + 5 members）
  [ "${#expected_agents[@]}" -ge 28 ]
}
