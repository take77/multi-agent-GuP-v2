import { execFileSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";

export interface PaneInfo {
  paneId: string;
  sessionName: string;
  agentId: string;
  agentRole: string;
  agentName: string;
  modelName: string;
  currentTask: string;
}

const EXEC_OPTIONS = { encoding: "utf-8" as const, timeout: 5000 };

/**
 * List all tmux panes with agent metadata.
 * Uses custom tmux variables (@agent_id, @agent_role, @agent_name) set by gup_v2_launch.sh.
 */
export function listPanes(): PaneInfo[] {
  try {
    const format =
      "#{pane_id}\t#{session_name}\t#{@agent_id}\t#{@agent_role}\t#{@agent_name}\t#{@model_name}\t#{@current_task}";
    const output = execFileSync(
      "tmux",
      ["list-panes", "-a", "-F", format],
      EXEC_OPTIONS
    );
    return output
      .trim()
      .split("\n")
      .filter((line) => line.trim())
      .map((line) => {
        const [paneId, sessionName, agentId, agentRole, agentName, modelName, currentTask] =
          line.split("\t");
        return { paneId, sessionName, agentId, agentRole, agentName, modelName: modelName || "", currentTask: currentTask || "" };
      })
      .filter((p) => p.agentId); // Only panes with @agent_id set
  } catch {
    return [];
  }
}

/**
 * Capture the last 500 lines of a tmux pane's output.
 * Plain text (no ANSI escape sequences) for chat/text display.
 */
export function capturePaneContent(paneId: string): string {
  try {
    return execFileSync(
      "tmux",
      ["capture-pane", "-p", "-t", paneId, "-S", "-500"],
      EXEC_OPTIONS
    );
  } catch {
    return "";
  }
}

/**
 * Send keys (command) to a tmux pane.
 * Uses send-keys with literal flag (-l) for reliable delivery.
 * Do NOT use paste-buffer -p (bracketed paste) — Claude Code interprets
 * bracketed paste as "pasted text" and won't execute it as a command.
 */
export function sendKeys(paneId: string, command: string): void {
  // send-keys -l sends the text literally (no key name interpretation)
  execFileSync("tmux", ["send-keys", "-t", paneId, "-l", command], EXEC_OPTIONS);
  // Small wait then send Enter separately
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50);
  execFileSync("tmux", ["send-keys", "-t", paneId, "Enter"], EXEC_OPTIONS);
}

/**
 * Send Escape key to a tmux pane (no Enter).
 * Used for interrupting running processes in Claude Code agents.
 */
export function sendEscape(paneId: string): void {
  execFileSync(
    "tmux",
    ["send-keys", "-t", paneId, "Escape"],
    EXEC_OPTIONS
  );
}

/**
 * Build a mapping from agentId to paneId for quick lookups.
 */
export function buildAgentPaneMap(): Map<string, string> {
  const panes = listPanes();
  const map = new Map<string, string>();
  for (const p of panes) {
    if (p.agentId) {
      map.set(p.agentId, p.paneId);
    }
  }
  return map;
}
