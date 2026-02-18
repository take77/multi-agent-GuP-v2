import * as fs from 'fs/promises';
import * as path from 'path';
import * as yaml from 'js-yaml';

export class StateManager {
  private statePath: string;
  private state: any;

  constructor(statePath: string) {
    this.statePath = statePath;
    this.state = null;
  }

  // YAML ファイル読み込み
  async load(): Promise<void> {
    try {
      const content = await fs.readFile(this.statePath, 'utf8');
      this.state = yaml.load(content);

      // 初期化されていない場合はデフォルト構造を作成
      if (!this.state) {
        this.state = { teammates: [] };
      }
      if (!this.state.teammates) {
        this.state.teammates = [];
      }
    } catch (error: any) {
      if (error.code === 'ENOENT') {
        // ファイルが存在しない場合は初期状態を作成
        this.state = { teammates: [] };
      } else {
        throw error;
      }
    }
  }

  // YAML ファイル書き込み
  async save(): Promise<void> {
    const content = yaml.dump(this.state);
    await fs.writeFile(this.statePath, content, 'utf8');
  }

  // メッセージからの状態更新
  updateFromMessage(msg: any): void {
    if (!this.state) {
      throw new Error('State not loaded. Call load() first.');
    }

    const { type, from, task_id, teammate_id } = msg;

    // teammate_id または from からテームメイトを特定
    const id = teammate_id || from;
    if (!id) return;

    let teammate = this.state.teammates.find((t: any) => t.id === id);
    if (!teammate) {
      teammate = { id, tasks: [], idle_count: 0 };
      this.state.teammates.push(teammate);
    }

    // メッセージタイプに応じて状態を更新
    switch (type) {
      case 'task_assigned':
        if (task_id && !teammate.tasks.includes(task_id)) {
          teammate.tasks.push(task_id);
        }
        break;
      case 'task_completed':
        if (task_id) {
          teammate.tasks = teammate.tasks.filter((t: string) => t !== task_id);
        }
        break;
      case 'idle':
        teammate.idle_count = (teammate.idle_count || 0) + 1;
        break;
    }
  }

  // タスク完了マーク
  markTaskCompleted(taskId: string): void {
    if (!this.state) {
      throw new Error('State not loaded. Call load() first.');
    }

    // 全てのテームメイトからタスクを削除
    for (const teammate of this.state.teammates) {
      if (teammate.tasks) {
        teammate.tasks = teammate.tasks.filter((t: string) => t !== taskId);
      }
    }
  }

  // 未完了タスク取得
  getPendingTasksFor(teammateId: string): string[] {
    if (!this.state) {
      throw new Error('State not loaded. Call load() first.');
    }

    const teammate = this.state.teammates.find((t: any) => t.id === teammateId);
    return teammate && teammate.tasks ? teammate.tasks : [];
  }

  // 受入基準取得（タスクYAMLから読み取り）
  async getAcceptanceCriteria(taskId: string): Promise<string[]> {
    // queue/tasks/ から該当task_idのYAMLを読み取り
    const tasksDir = path.resolve(path.dirname(this.statePath), '../tasks');

    // タスクYAMLファイルを探す（複数のファイルに分散している可能性がある）
    let files: string[];
    try {
      files = await fs.readdir(tasksDir);
    } catch (error: any) {
      if (error.code === 'ENOENT') {
        return [];
      }
      throw error;
    }

    for (const file of files) {
      if (!file.endsWith('.yaml')) continue;

      const taskFilePath = path.join(tasksDir, file);
      const content = await fs.readFile(taskFilePath, 'utf8');
      const taskData = yaml.load(content) as any;

      if (taskData && taskData.task && taskData.task.task_id === taskId) {
        // acceptance_criteria フィールドを探す
        if (taskData.task.acceptance_criteria) {
          return Array.isArray(taskData.task.acceptance_criteria)
            ? taskData.task.acceptance_criteria
            : [taskData.task.acceptance_criteria];
        }

        // description から検証基準を抽出（チェックボックス形式）
        if (taskData.task.description) {
          const lines = taskData.task.description.split('\n');
          const criteria: string[] = [];
          for (const line of lines) {
            // "- [ ]" または "- [x]" で始まる行を抽出
            const match = line.match(/^\s*-\s+\[\s*[x ]?\s*\]\s+(.+)$/);
            if (match) {
              criteria.push(match[1].trim());
            }
          }
          return criteria;
        }
      }
    }

    return [];
  }

  // アイドルカウント増加
  incrementIdleCount(teammateId: string): void {
    if (!this.state) {
      throw new Error('State not loaded. Call load() first.');
    }

    let teammate = this.state.teammates.find((t: any) => t.id === teammateId);
    if (!teammate) {
      teammate = { id: teammateId, tasks: [], idle_count: 0 };
      this.state.teammates.push(teammate);
    }

    teammate.idle_count = (teammate.idle_count || 0) + 1;
  }
}
