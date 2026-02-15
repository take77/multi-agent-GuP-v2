import { describe, it, before, after } from 'node:test';
import * as assert from 'node:assert';
import * as fs from 'fs/promises';
import * as path from 'path';
import { taskCompletedHook } from './task_completed.js';

/**
 * Unit Test for TaskCompleted Hook
 */

const TEST_STATE_PATH = 'queue/hq/test_session_state.yaml';
const TEST_TASKS_DIR = 'queue/tasks';

describe('taskCompletedHook', () => {
  before(async () => {
    // テスト用のディレクトリとファイルを準備
    await fs.mkdir('queue/hq', { recursive: true });
    await fs.mkdir('queue/tasks', { recursive: true });

    // テスト用の初期状態YAML
    await fs.writeFile(TEST_STATE_PATH, 'teammates: []\n', 'utf8');
  });

  after(async () => {
    // テスト後のクリーンアップ
    try {
      await fs.unlink(TEST_STATE_PATH);
      // タスクYAMLファイルも削除
      const files = await fs.readdir(TEST_TASKS_DIR);
      for (const file of files) {
        if (file.startsWith('test_task_')) {
          await fs.unlink(path.join(TEST_TASKS_DIR, file));
        }
      }
    } catch (error) {
      // クリーンアップエラーは無視
    }
  });

  it('should block when criteria are not met', async () => {
    // タスクYAMLを作成（acceptance_criteria あり）
    const taskYaml = `
task:
  task_id: test_task_001
  description: Test task
  acceptance_criteria:
    - "All tests passed"
    - "Code compiled successfully"
`;
    await fs.writeFile(path.join(TEST_TASKS_DIR, 'test_task_001.yaml'), taskYaml, 'utf8');

    // criteria を満たさない result で呼び出し
    const input = {
      task_id: 'test_task_001',
      result: 'Some incomplete result'
    };

    const response = await taskCompletedHook(input);

    // block が返ることを検証
    assert.strictEqual(response.decision, 'block');
    assert.ok(response.reason);
    assert.ok(response.reason.includes('All tests passed'));
  });

  it('should allow when all criteria are met', async () => {
    // タスクYAMLを作成（acceptance_criteria あり）
    const taskYaml = `
task:
  task_id: test_task_002
  description: Test task
  acceptance_criteria:
    - "Build completed"
    - "Tests passed"
`;
    await fs.writeFile(path.join(TEST_TASKS_DIR, 'test_task_002.yaml'), taskYaml, 'utf8');

    // criteria を全て満たす result で呼び出し
    const input = {
      task_id: 'test_task_002',
      result: 'Build completed successfully. All Tests passed with no errors.'
    };

    const response = await taskCompletedHook(input);

    // allow が返ることを検証（空オブジェクト）
    assert.deepStrictEqual(response, {});
  });

  it('should allow when criteria do not exist (fail-open)', async () => {
    // タスクYAMLを作成（acceptance_criteria なし）
    const taskYaml = `
task:
  task_id: test_task_003
  description: Test task without criteria
`;
    await fs.writeFile(path.join(TEST_TASKS_DIR, 'test_task_003.yaml'), taskYaml, 'utf8');

    // criteria がない場合は allow（フェイルオープン）
    const input = {
      task_id: 'test_task_003',
      result: 'Any result'
    };

    const response = await taskCompletedHook(input);

    // allow が返ることを検証（空オブジェクト）
    assert.deepStrictEqual(response, {});
  });

  it('should block when result is undefined', async () => {
    // タスクYAMLを作成（acceptance_criteria あり）
    const taskYaml = `
task:
  task_id: test_task_004
  description: Test task
  acceptance_criteria:
    - "Some criterion"
`;
    await fs.writeFile(path.join(TEST_TASKS_DIR, 'test_task_004.yaml'), taskYaml, 'utf8');

    // result が undefined の場合
    const input = {
      task_id: 'test_task_004',
      result: undefined
    };

    const response = await taskCompletedHook(input);

    // block が返ることを検証
    assert.strictEqual(response.decision, 'block');
    assert.ok(response.reason);
    assert.ok(response.reason.includes('Result is empty or undefined'));
  });

  it('should allow on error (fail-open)', async () => {
    // 存在しないタスクIDでエラーを発生させる
    const input = {
      task_id: 'non_existent_task',
      result: 'Some result'
    };

    const response = await taskCompletedHook(input);

    // エラー時はフェイルオープンで allow（空オブジェクト）
    assert.deepStrictEqual(response, {});
  });
});
