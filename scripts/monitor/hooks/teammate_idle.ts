import { StateManager } from '../lib/state_manager.js';

export async function teammateIdleHook(input: any): Promise<any> {
  try {
    const { teammate_id } = input;
    const stateManager = new StateManager('queue/hq/session_state.yaml');
    await stateManager.load();

    const pendingTasks = stateManager.getPendingTasksFor(teammate_id);

    if (pendingTasks.length > 0) {
      return {
        decision: "block",
        reason: `未完了タスクがあります: ${pendingTasks.join(', ')}`
      };
    }

    stateManager.incrementIdleCount(teammate_id);
    await stateManager.save();

    return {};
  } catch (error) {
    console.error('TeammateIdle hook error:', error);
    return {};
  }
}
