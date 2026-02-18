#!/usr/bin/env bash
# fallback_to_tmux.sh — Agent Teams → tmux フォールバック処理
#
# Agent Teams モードから現行の tmux 直接通信モードへフォールバックする。
# セッション未存在でもエラーにならないよう || true を付加。

# 1. 各セッションの GUP_BRIDGE_MODE を 0 に設定
tmux setenv -t darjeeling GUP_BRIDGE_MODE 0 || true
tmux setenv -t katyusha GUP_BRIDGE_MODE 0 || true
tmux setenv -t kay GUP_BRIDGE_MODE 0 || true
tmux setenv -t maho GUP_BRIDGE_MODE 0 || true

# 2. command セッションの Agent Teams 関連設定を無効化
tmux setenv -t command GUP_AGENT_TEAMS_ACTIVE 0 || true
tmux setenv -t command -u CLAUDE_CODE_TASK_LIST_ID || true

# 3. queue/hq/session_state.yaml の agent_teams_active を false に更新
if [ -f queue/hq/session_state.yaml ]; then
  if command -v yq &> /dev/null; then
    yq eval '.agent_teams_active = false' -i queue/hq/session_state.yaml
  else
    sed -i 's/agent_teams_active: true/agent_teams_active: false/' queue/hq/session_state.yaml
  fi
fi

# 4. 各隊長に inbox_write.sh で通知
bash scripts/inbox_write.sh darjeeling "Agent Teams フォールバック実行。tmux 直接通信モードに切替" system system || true
bash scripts/inbox_write.sh katyusha "Agent Teams フォールバック実行。tmux 直接通信モードに切替" system system || true
bash scripts/inbox_write.sh kay "Agent Teams フォールバック実行。tmux 直接通信モードに切替" system system || true
bash scripts/inbox_write.sh maho "Agent Teams フォールバック実行。tmux 直接通信モードに切替" system system || true

# 5. 完了メッセージ
echo "✅ Agent Teams → tmux フォールバック完了"
