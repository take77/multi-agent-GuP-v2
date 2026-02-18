import * as fs from 'fs/promises';
import * as path from 'path';

/**
 * Audit Logger Hook Handler
 *
 * PostToolUse フックハンドラ（async: true で非ブロッキング）。
 * ツール使用履歴を logs/monitor/audit_YYYYMMDD.jsonl に記録。
 */
export async function auditLoggerHook(input: any): Promise<any> {
  try {
    const { tool_name, tool_input, tool_output, timestamp } = input;

    const logDir = 'logs/monitor';
    const logFile = path.join(logDir, `audit_${new Date().toISOString().split('T')[0].replace(/-/g, '')}.jsonl`);

    await fs.mkdir(logDir, { recursive: true });

    const logEntry = JSON.stringify({
      timestamp: timestamp || new Date().toISOString(),
      tool_name,
      tool_input,
      tool_output
    }) + '\n';

    await fs.appendFile(logFile, logEntry);

    return {};
  } catch (error) {
    console.error('AuditLogger hook error:', error);
    return {};
  }
}
