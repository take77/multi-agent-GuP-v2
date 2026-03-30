import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { taskCompletedHook } from './task_completed.js';

/**
 * Unit Test for TaskCompleted Hook
 *
 * 安全策: process.chdir() で cwd を /tmp 配下の一時ディレクトリに切り替え、
 * hook が参照する相対パス（queue/hq/, queue/tasks/）がプロジェクト本体と干渉しないようにする。
 */

let TEST_BASE_DIR: string;
let ORIGINAL_CWD: string;

describe('taskCompletedHook', () => {
  beforeAll(async () => {
    ORIGINAL_CWD = process.cwd();

    // /tmp 配下に隔離されたテスト用ディレクトリを作成
    TEST_BASE_DIR = await fs.mkdtemp(path.join(os.tmpdir(), 'gup-hook-test-'));

    // hook が参照する相対パス構造を再現
    await fs.mkdir(path.join(TEST_BASE_DIR, 'queue', 'hq'), { recursive: true });
    await fs.mkdir(path.join(TEST_BASE_DIR, 'queue', 'tasks'), { recursive: true });

    // テスト用の初期状態YAML
    await fs.writeFile(
      path.join(TEST_BASE_DIR, 'queue', 'hq', 'session_state.yaml'),
      'teammates: []\n',
      'utf8'
    );

    // cwd を一時ディレクトリに切り替え
    process.chdir(TEST_BASE_DIR);
  });

  afterAll(async () => {
    // cwd を元に戻す
    process.chdir(ORIGINAL_CWD);

    // クリーンアップ
    try {
      if (TEST_BASE_DIR) {
        await fs.rm(TEST_BASE_DIR, { recursive: true, force: true });
      }
    } catch (error) {
      // クリーンアップエラーは無視
    }
  });

  it('should block when criteria are not met', async () => {
    const taskYaml = `
task:
  task_id: test_task_001
  description: Test task
  acceptance_criteria:
    - "All tests passed"
    - "Code compiled successfully"
`;
    await fs.writeFile('queue/tasks/test_task_001.yaml', taskYaml, 'utf8');

    const input = {
      task_id: 'test_task_001',
      result: 'Some incomplete result'
    };

    const response = await taskCompletedHook(input);

    expect(response.decision).toBe('block');
    expect(response.reason).toBeTruthy();
    expect(response.reason).toContain('All tests passed');
  });

  it('should allow when all criteria are met', async () => {
    const taskYaml = `
task:
  task_id: test_task_002
  description: Test task
  acceptance_criteria:
    - "Build completed"
    - "Tests passed"
`;
    await fs.writeFile('queue/tasks/test_task_002.yaml', taskYaml, 'utf8');

    const input = {
      task_id: 'test_task_002',
      result: 'Build completed successfully. All Tests passed with no errors.'
    };

    const response = await taskCompletedHook(input);

    expect(response).toEqual({});
  });

  it('should allow when criteria do not exist (fail-open)', async () => {
    const taskYaml = `
task:
  task_id: test_task_003
  description: Test task without criteria
`;
    await fs.writeFile('queue/tasks/test_task_003.yaml', taskYaml, 'utf8');

    const input = {
      task_id: 'test_task_003',
      result: 'Any result'
    };

    const response = await taskCompletedHook(input);

    expect(response).toEqual({});
  });

  it('should block when result is undefined', async () => {
    const taskYaml = `
task:
  task_id: test_task_004
  description: Test task
  acceptance_criteria:
    - "Some criterion"
`;
    await fs.writeFile('queue/tasks/test_task_004.yaml', taskYaml, 'utf8');

    const input = {
      task_id: 'test_task_004',
      result: undefined
    };

    const response = await taskCompletedHook(input);

    expect(response.decision).toBe('block');
    expect(response.reason).toBeTruthy();
    expect(response.reason).toContain('Result is empty or undefined');
  });

  it('should allow on error (fail-open)', async () => {
    const input = {
      task_id: 'non_existent_task',
      result: 'Some result'
    };

    const response = await taskCompletedHook(input);

    expect(response).toEqual({});
  });
});
