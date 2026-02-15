import * as fs from 'fs/promises';
import * as path from 'path';
import { StateManager } from './state_manager.js';

// Simple assertion helper
function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

async function assertEquals(actual: any, expected: any, message: string): Promise<void> {
  const actualStr = JSON.stringify(actual);
  const expectedStr = JSON.stringify(expected);
  if (actualStr !== expectedStr) {
    throw new Error(`Assertion failed: ${message}\nExpected: ${expectedStr}\nActual: ${actualStr}`);
  }
}

// Test state file path
const testStatePath = path.join(process.cwd(), 'test_session_state.yaml');
const testTasksDir = path.join(process.cwd(), 'test_tasks');

// Clean up test files
async function cleanup(): Promise<void> {
  try {
    await fs.unlink(testStatePath);
  } catch (error: any) {
    // Ignore if file doesn't exist
  }
  try {
    await fs.rm(testTasksDir, { recursive: true, force: true });
  } catch (error: any) {
    // Ignore if directory doesn't exist
  }
}

// Test 1: load/save YAML読み書きテスト
async function testLoadSave(): Promise<void> {
  console.log('Test 1: load/save YAML read/write...');

  await cleanup();

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
  assert(fileExists, 'State file should exist after save()');

  // 新しいインスタンスで読み込み
  const manager2 = new StateManager(testStatePath);
  await manager2.load();

  const tasks = manager2.getPendingTasksFor('ashigaru1');
  await assertEquals(tasks, ['task_001'], 'Loaded state should contain task_001');

  console.log('✓ Test 1 passed');
}

// Test 2: markTaskCompleted のテスト
async function testMarkTaskCompleted(): Promise<void> {
  console.log('Test 2: markTaskCompleted...');

  await cleanup();

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
  await assertEquals(tasks.length, 2, 'Should have 2 tasks before completion');

  // タスク完了
  manager.markTaskCompleted('task_001');

  tasks = manager.getPendingTasksFor('ashigaru1');
  await assertEquals(tasks, ['task_002'], 'Should only have task_002 after completing task_001');

  console.log('✓ Test 2 passed');
}

// Test 3: getPendingTasksFor のテスト
async function testGetPendingTasksFor(): Promise<void> {
  console.log('Test 3: getPendingTasksFor...');

  await cleanup();

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

  await assertEquals(tasks1.length, 2, 'ashigaru1 should have 2 tasks');
  await assertEquals(tasks2, ['task_003'], 'ashigaru2 should have task_003');
  await assertEquals(tasks3, [], 'ashigaru3 should have no tasks');

  console.log('✓ Test 3 passed');
}

// Test 4: incrementIdleCount のテスト
async function testIncrementIdleCount(): Promise<void> {
  console.log('Test 4: incrementIdleCount...');

  await cleanup();

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
  assert(content.includes('idle_count: 2'), 'ashigaru1 should have idle_count: 2');
  assert(content.includes('idle_count: 1'), 'ashigaru2 should have idle_count: 1');

  console.log('✓ Test 4 passed');
}

// Test 5: getAcceptanceCriteria のテスト
async function testGetAcceptanceCriteria(): Promise<void> {
  console.log('Test 5: getAcceptanceCriteria...');

  await cleanup();

  // テスト用ディレクトリ構造を作成
  // queue/hq/session_state.yaml → ../tasks/test_task.yaml という構造
  const testQueueDir = path.join(process.cwd(), 'test_queue');
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

  await assertEquals(criteria.length, 3, 'Should have 3 acceptance criteria');
  await assertEquals(criteria[0], 'テスト項目1', 'First criterion should be "テスト項目1"');

  // Clean up
  await fs.rm(testQueueDir, { recursive: true, force: true });

  console.log('✓ Test 5 passed');
}

// Run all tests
async function runTests(): Promise<void> {
  console.log('=== Running StateManager Tests ===\n');

  try {
    await testLoadSave();
    await testMarkTaskCompleted();
    await testGetPendingTasksFor();
    await testIncrementIdleCount();
    await testGetAcceptanceCriteria();

    console.log('\n=== All tests passed! ===');
  } catch (error: any) {
    console.error('\n=== Test failed ===');
    console.error(error.message);
    process.exit(1);
  } finally {
    await cleanup();
  }
}

// Execute tests
runTests();
