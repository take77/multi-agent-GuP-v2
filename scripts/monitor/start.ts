#!/usr/bin/env node
import * as fs from 'fs/promises';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { StateManager } from './lib/state_manager.js';
import { CostTracker } from './lib/cost_tracker.js';
import { taskCompletedHook } from './hooks/task_completed.js';
import { teammateIdleHook } from './hooks/teammate_idle.js';
import { stopValidatorHook } from './hooks/stop_validator.js';
import { auditLoggerHook } from './hooks/audit_logger.js';

interface AgentTeamsConfig {
  enabled: boolean;
  lead: {
    agent_id: string;
    model: string;
    effort: string;
    delegate_mode: boolean;
  };
  monitor: {
    state_file: string;
  };
  teammates: Array<{
    agent_id: string;
    model: string;
  }>;
}

interface SettingsYaml {
  agent_teams: AgentTeamsConfig;
}

async function main() {
  const isDryRun = process.argv.includes('--dry-run');

  try {
    console.log('🚀 multi-agent-GuP-v2 Monitor starting...');

    // 1. config/settings.yaml 読み込み
    const configPath = path.resolve('../../config/settings.yaml');
    const configContent = await fs.readFile(configPath, 'utf8');
    const settings = yaml.load(configContent) as SettingsYaml;

    if (!settings.agent_teams) {
      throw new Error('agent_teams configuration not found in settings.yaml');
    }

    console.log(`📋 Lead agent: ${settings.agent_teams.lead.agent_id} (${settings.agent_teams.lead.model})`);
    console.log(`👥 Teammates: ${settings.agent_teams.teammates.map(t => t.agent_id).join(', ')}`);

    // 2. StateManager 初期化 + session_state.yaml 読み込み（復帰モード対応）
    const stateManager = new StateManager(settings.agent_teams.monitor.state_file);
    await stateManager.load();
    console.log('✅ State loaded from', settings.agent_teams.monitor.state_file);

    // 3. instructions/battalion_commander.md 読み込み
    const instructionsPath = path.resolve('../../instructions/battalion_commander.md');
    const instructions = await fs.readFile(instructionsPath, 'utf8');
    console.log(`📖 Instructions loaded (${instructions.length} bytes)`);

    // 4. hooks 準備
    const hooks = {
      TaskCompleted: taskCompletedHook,
      TeammateIdle: teammateIdleHook,
      Stop: stopValidatorHook,
      PostToolUse: auditLoggerHook,
    };
    console.log('🪝 Hooks registered:', Object.keys(hooks).join(', '));

    if (isDryRun) {
      console.log('✅ Dry-run mode: Configuration loaded successfully. Exiting without starting agent.');
      process.exit(0);
    }

    // 5. CostTracker 初期化
    const costTracker = new CostTracker();

    // 6. Agent SDK 動的インポート（インストール確認）
    let query: any;
    try {
      const sdk = await import('@anthropic-ai/claude-agent-sdk');
      query = sdk.query;
    } catch (error: any) {
      console.error('❌ @anthropic-ai/claude-agent-sdk not installed.');
      console.error('   Run: npm install @anthropic-ai/claude-agent-sdk');
      process.exit(1);
    }

    // 7. Agent SDK query() 起動
    console.log('🤖 Starting Agent SDK query with lead agent...');

    const result = await query({
      model: settings.agent_teams.lead.model as any,
      effort: settings.agent_teams.lead.effort as any,
      delegateMode: settings.agent_teams.lead.delegate_mode,
      systemPrompt: instructions,
      prompt: 'Start monitoring. Check coordination/master_dashboard.md for current status.',
      hooks: {
        TaskCompleted: async (input: any) => await hooks.TaskCompleted(input),
        TeammateIdle: async (input: any) => await hooks.TeammateIdle(input),
        Stop: async (input: any) => await hooks.Stop(input),
        PostToolUse: {
          async: true,
          handler: async (input: any) => await hooks.PostToolUse(input),
        },
      },
      onMessage: (msg: any) => {
        // CostTracker にコスト情報を渡す
        costTracker.track(msg);

        // StateManager に状態を通知
        stateManager.updateFromMessage(msg);

        console.log(`💬 Message from ${msg.from || 'agent'}: ${msg.type || 'unknown type'}`);
      },
    });

    console.log('✅ Agent session completed.');
    console.log('📊 Cost summary:', costTracker.getSummary());

    // session_state.yaml に最終状態を保存
    await stateManager.save();
    console.log('💾 Final state saved to', settings.agent_teams.monitor.state_file);

    // コスト情報をログ出力
    const costLogPath = 'logs/monitor/cost_summary.json';
    await costTracker.writeTo(costLogPath);
    console.log('💰 Cost log saved to', costLogPath);

  } catch (error: any) {
    console.error('❌ Monitor startup failed:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
