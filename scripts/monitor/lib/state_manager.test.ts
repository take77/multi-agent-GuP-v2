import { describe, it, expect, beforeEach, afterAll, beforeAll } from 'vitest';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import { StateManager } from './state_manager.js';

/**
 * Unit Test for StateManager
 *
 * 安全策: process.chdir() で cwd を /tmp 配下の一時ディレクトリに切り替え、
 * プロジェクト本体のファイルと干渉しないようにする。
 */

let TEST_BASE_DIR: string;
let ORIGINAL_CWD: string;
let testStatePath: string;
let testTasksDir: string;

describe('StateManager', () => {
  beforeAll(async () => {
    ORIGINAL_CWD = process.cwd();

    // /tmp 配下に隔離されたテスト用ディレクトリを作成
    TEST_BASE_DIR = await fs.mkdtemp(path.join(os.tmpdir(), 'gup-state-test-'));

    process.chdir(TEST_BASE_DIR);
  });

  beforeEach(async () => {
    // 各テスト前にクリーンな状態にする
    testStatePath = path.join(TEST_BASE_DIR, 'test_session_state.yaml');
    testTasksDir = path.join(TEST_BASE_DIR, 'test_tasks');

    try { await fs.unlink(testStatePath); } catch { /* ignore */ }
    try { await fs.rm(testTasksDir, { recursive: true, force: true }); } catch { /* ignore */ }
  });

  afterAll(async () => {
    process.chdir(ORIGINAL_CWD);

    try {
      if (TEST_BASE_DIR) {
        await fs.rm(TEST_BASE_DIR, { recursive: true, force: true });
      }
    } catch { /* ignore */ }
  });

  it('Test 1: load/save YAML読み書きテスト', async () => {
    const manager = new StateManager(testStatePath);

    // 初回load（ファイルが存在しない場合）
    await manager.load();

    // データを追加
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru1',
      task_id: 'task_001',
    });

    // 保存
    await manager.save();

    // ファイルが作成されたことを確認
    const fileExists = await fs.access(testStatePath).then(() => true).catch(() => false);
    expect(fileExists).toBe(true);

    // 新しいインスタンスで読み込み
    const manager2 = new StateManager(testStatePath);
    await manager2.load();

    const tasks = manager2.getPendingTasksFor('ashigaru1');
    expect(tasks).toEqual(['task_001']);
  });

  it('Test 2: markTaskCompleted', async () => {
    const manager = new StateManager(testStatePath);
    await manager.load();

    // タスクを追加
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru1',
      task_id: 'task_001',
    });
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru1',
      task_id: 'task_002',
    });

    let tasks = manager.getPendingTasksFor('ashigaru1');
    expect(tasks.length).toEqual(2);

    // タスク完了
    manager.markTaskCompleted('task_001');

    tasks = manager.getPendingTasksFor('ashigaru1');
    expect(tasks).toEqual(['task_002']);
  });

  it('Test 3: getPendingTasksFor', async () => {
    const manager = new StateManager(testStatePath);
    await manager.load();

    // 複数のテームメイトにタスクを追加
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru1',
      task_id: 'task_001',
    });
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru1',
      task_id: 'task_002',
    });
    manager.updateFromMessage({
      type: 'task_assigned',
      from: 'ashigaru2',
      task_id: 'task_003',
    });

    const tasks1 = manager.getPendingTasksFor('ashigaru1');
    const tasks2 = manager.getPendingTasksFor('ashigaru2');
    const tasks3 = manager.getPendingTasksFor('ashigaru3');

    expect(tasks1.length).toEqual(2);
    expect(tasks2).toEqual(['task_003']);
    expect(tasks3).toEqual([]);
  });

  it('Test 4: incrementIdleCount', async () => {
    const manager = new StateManager(testStatePath);
    await manager.load();

    // アイドルカウント増加
    manager.incrementIdleCount('ashigaru1');
    manager.incrementIdleCount('ashigaru1');
    manager.incrementIdleCount('ashigaru2');

    await manager.save();

    // 新しいインスタンスで読み込み
    const manager2 = new StateManager(testStatePath);
    await manager2.load();

    const content = await fs.readFile(testStatePath, 'utf8');
    expect(content).toContain('idle_count: 2');
    expect(content).toContain('idle_count: 1');
  });

  it('Test 5: getAcceptanceCriteria', async () => {
    // テスト用ディレクトリ構造を作成
    // queue/hq/session_state.yaml → ../tasks/test_task.yaml という構造
    const testQueueDir = path.join(TEST_BASE_DIR, 'test_queue');
    const testHqDir = path.join(testQueueDir, 'hq');
    const testTasksDirForCriteria = path.join(testQueueDir, 'tasks');

    await fs.mkdir(testHqDir, { recursive: true });
    await fs.mkdir(testTasksDirForCriteria, { recursive: true });

    const taskYamlContent = `task:
  task_id: task_test_001
  description: |
    ## Test Task

    ### 検証基準
    - [ ] テスト項目1
    - [ ] テスト項目2
    - [ ] テスト項目3
  status: assigned
`;

    await fs.writeFile(
      path.join(testTasksDirForCriteria, 'test_task.yaml'),
      taskYamlContent,
      'utf8'
    );

    // StateManager のインスタンスを作成
    const testStatePathForCriteria = path.join(testHqDir, 'session_state.yaml');

    const manager = new StateManager(testStatePathForCriteria);
    await manager.load();

    const criteria = await manager.getAcceptanceCriteria('task_test_001');

    expect(criteria.length).toEqual(3);
    expect(criteria[0]).toEqual('テスト項目1');

    // Clean up
    await fs.rm(testQueueDir, { recursive: true, force: true });
  });

  it('Test 6: getAcceptanceCriteria - 文字列（配列でない）の場合は配列に変換', async () => {
    const testQueueDir = path.join(TEST_BASE_DIR, 'test_queue_6');
    const testHqDir = path.join(testQueueDir, 'hq');
    const testTasksDirForCriteria = path.join(testQueueDir, 'tasks');

    await fs.mkdir(testHqDir, { recursive: true });
    await fs.mkdir(testTasksDirForCriteria, { recursive: true });

    const taskYamlContent = `task:
  task_id: edge_test_001
  description: "test"
  acceptance_criteria: "単一の基準文字列"
`;

    await fs.writeFile(
      path.join(testTasksDirForCriteria, 'edge_test_001.yaml'),
      taskYamlContent,
      'utf8'
    );

    const testStatePathForCriteria = path.join(testHqDir, 'session_state.yaml');
    const manager = new StateManager(testStatePathForCriteria);
    await manager.load();

    const criteria = await manager.getAcceptanceCriteria('edge_test_001');

    expect(criteria).toEqual(['単一の基準文字列']);

    await fs.rm(testQueueDir, { recursive: true, force: true });
  });

  it('Test 7: getAcceptanceCriteria - 空配列の場合は空配列が返る', async () => {
    const testQueueDir = path.join(TEST_BASE_DIR, 'test_queue_7');
    const testHqDir = path.join(testQueueDir, 'hq');
    const testTasksDirForCriteria = path.join(testQueueDir, 'tasks');

    await fs.mkdir(testHqDir, { recursive: true });
    await fs.mkdir(testTasksDirForCriteria, { recursive: true });

    const taskYamlContent = `task:
  task_id: edge_test_002
  description: "test"
  acceptance_criteria: []
`;

    await fs.writeFile(
      path.join(testTasksDirForCriteria, 'edge_test_002.yaml'),
      taskYamlContent,
      'utf8'
    );

    const testStatePathForCriteria = path.join(testHqDir, 'session_state.yaml');
    const manager = new StateManager(testStatePathForCriteria);
    await manager.load();

    const criteria = await manager.getAcceptanceCriteria('edge_test_002');

    expect(criteria).toEqual([]);

    await fs.rm(testQueueDir, { recursive: true, force: true });
  });

  it('Test 8: getAcceptanceCriteria - description も acceptance_criteria もない場合は空配列', async () => {
    const testQueueDir = path.join(TEST_BASE_DIR, 'test_queue_8');
    const testHqDir = path.join(testQueueDir, 'hq');
    const testTasksDirForCriteria = path.join(testQueueDir, 'tasks');

    await fs.mkdir(testHqDir, { recursive: true });
    await fs.mkdir(testTasksDirForCriteria, { recursive: true });

    const taskYamlContent = `task:
  task_id: edge_test_003
  status: assigned
`;

    await fs.writeFile(
      path.join(testTasksDirForCriteria, 'edge_test_003.yaml'),
      taskYamlContent,
      'utf8'
    );

    const testStatePathForCriteria = path.join(testHqDir, 'session_state.yaml');
    const manager = new StateManager(testStatePathForCriteria);
    await manager.load();

    const criteria = await manager.getAcceptanceCriteria('edge_test_003');

    expect(criteria).toEqual([]);

    await fs.rm(testQueueDir, { recursive: true, force: true });
  });
});
