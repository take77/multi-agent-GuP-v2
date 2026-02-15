import { StateManager } from '../lib/state_manager.js';

/**
 * TaskCompleted Hook Handler
 *
 * タスク完了時に acceptance_criteria を検証し、
 * - 検証不合格 → { decision: "block", reason: "..." } を返す（exit code 2相当）
 * - 検証合格 → タスクを完了マーク → {} を返す
 * - エラー時 → フェイルオープン（完了を許可）→ {} を返す
 */
export async function taskCompletedHook(input: any): Promise<any> {
  try {
    const { task_id, result } = input;

    if (!task_id) {
      console.error('TaskCompleted hook: task_id is missing');
      return {}; // Fail-open
    }

    const stateManager = new StateManager('queue/hq/session_state.yaml');
    await stateManager.load();

    // 受入基準を取得
    const criteria = await stateManager.getAcceptanceCriteria(task_id);

    // 基準が存在しない場合は検証をスキップ（フェイルオープン）
    if (!criteria || criteria.length === 0) {
      console.log(`TaskCompleted hook: No acceptance criteria found for task ${task_id}. Allowing completion.`);
      stateManager.markTaskCompleted(task_id);
      await stateManager.save();
      return {};
    }

    // 各基準を検証（文字列マッチング + 基本的な存在チェック）
    for (const criterion of criteria) {
      // result が undefined/null の場合は不合格
      if (!result) {
        return {
          decision: "block",
          reason: `Criterion not met: "${criterion}". Result is empty or undefined.`
        };
      }

      // result 文字列に criterion が含まれているかチェック
      const resultStr = typeof result === 'string' ? result : JSON.stringify(result);
      if (!resultStr.includes(criterion)) {
        return {
          decision: "block",
          reason: `Criterion not met: "${criterion}". Expected to find this in result, but not found.`
        };
      }
    }

    // 全ての基準を満たした場合、タスクを完了マーク
    stateManager.markTaskCompleted(task_id);
    await stateManager.save();

    console.log(`TaskCompleted hook: All criteria met for task ${task_id}. Task marked as completed.`);
    return {};

  } catch (error) {
    // フェイルオープン: エラー時はタスク完了を許可
    console.error('TaskCompleted hook error:', error);
    return {};
  }
}
