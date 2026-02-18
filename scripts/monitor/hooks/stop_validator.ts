import { StateManager } from '../lib/state_manager.js';

let stopHookActive = false;

/**
 * Stop Validator Hook Handler
 *
 * ターン終了時に session_state.yaml を最新状態で保存する。
 * 無限ループ防止のため、stopHookActive フラグを使用。
 */
export async function stopValidatorHook(input: any): Promise<any> {
  if (stopHookActive) {
    return {};
  }

  try {
    stopHookActive = true;
    const stateManager = new StateManager('queue/hq/session_state.yaml');
    await stateManager.load();
    await stateManager.save();
    return {};
  } catch (error) {
    console.error('StopValidator hook error:', error);
    return {};
  } finally {
    stopHookActive = false;
  }
}
