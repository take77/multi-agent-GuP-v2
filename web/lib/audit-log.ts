/**
 * Audit log writer for web UI commands.
 * Appends one JSON line per command to logs/web-ui-audit.jsonl
 */

import { appendFileSync, mkdirSync } from "fs";
import { join } from "path";

export interface AuditEntry {
  timestamp: string;
  agentId: string;
  command: string;
  action: "allowed" | "blocked";
  rule?: string;
  ip?: string;
}

// Resolve log path relative to project root (one level up from web/)
const LOG_DIR = join(process.cwd(), "..", "logs");
const LOG_FILE = join(LOG_DIR, "web-ui-audit.jsonl");

export function writeAuditLog(entry: AuditEntry): void {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    appendFileSync(LOG_FILE, JSON.stringify(entry) + "\n");
  } catch {
    // Audit log failure should not block command execution
    console.error("[audit-log] Failed to write audit entry");
  }
}
