import { createHash } from "crypto";
import { listPanes, capturePaneContent, type PaneInfo } from "./tmux";
import { eventBus } from "./event-bus";

export interface PaneState {
  hash: string;
  lastChange: number;
  active: boolean;
}

const ACTIVE_INTERVAL = 200;
const IDLE_INTERVAL = 2000;
const IDLE_THRESHOLD = 10000; // 10s without change → idle

let streaming = false;
let intervalHandle: ReturnType<typeof setInterval> | null = null;
export const paneStates = new Map<string, PaneState>();

function hashContent(content: string): string {
  return createHash("sha256").update(content).digest("hex");
}

function pollPanes() {
  let panes: PaneInfo[];
  try {
    panes = listPanes();
  } catch {
    return;
  }

  const now = Date.now();

  for (const pane of panes) {
    if (!pane.agentId || !pane.paneId) continue;

    const content = capturePaneContent(pane.paneId);
    const hash = hashContent(content);
    const prev = paneStates.get(pane.agentId);

    if (!prev || prev.hash !== hash) {
      // Content changed
      paneStates.set(pane.agentId, {
        hash,
        lastChange: now,
        active: true,
      });

      eventBus.emit("agent-output", {
        agentId: pane.agentId,
        output: content,
        paneId: pane.paneId,
        sessionName: pane.sessionName,
        timestamp: now,
      });
    } else if (prev.active && now - prev.lastChange > IDLE_THRESHOLD) {
      // Transition to idle
      prev.active = false;
    }
  }
}

export function startPaneStreaming(): void {
  if (streaming) return;
  streaming = true;

  // Start with active interval; adaptive polling adjusts per-pane
  // but the global poll rate uses the faster interval
  intervalHandle = setInterval(pollPanes, ACTIVE_INTERVAL);
}

export function stopPaneStreaming(): void {
  streaming = false;
  if (intervalHandle) {
    clearInterval(intervalHandle);
    intervalHandle = null;
  }
  paneStates.clear();
}

export function isStreaming(): boolean {
  return streaming;
}
