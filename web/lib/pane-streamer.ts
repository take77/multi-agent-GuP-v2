import { createHash } from "crypto";
import { listPanes, capturePaneContent, type PaneInfo } from "./tmux";
import { eventBus } from "./event-bus";

export interface PaneState {
  hash: string;
  lastChange: number;
  lastPoll: number;
  active: boolean;
  hasPrompt: boolean;
}

const ACTIVE_INTERVAL = 200;
const INACTIVE_INTERVAL = 3000;
const IDLE_THRESHOLD = 10000; // 10s without change → idle

let streaming = false;
let intervalHandle: ReturnType<typeof setInterval> | null = null;
export const paneStates = new Map<string, PaneState>();

// Cache last captured content per agent for re-emission on agent switch
const lastCapture = new Map<
  string,
  { content: string; paneId: string; sessionName: string }
>();

// Track which agent the frontend is currently viewing
let activeAgentId: string | null = null;

export function setActiveAgent(agentId: string | null): void {
  const prev = activeAgentId;
  activeAgentId = agentId;

  // Force re-emit cached content when switching to a different agent
  if (agentId && agentId !== prev) {
    const cached = lastCapture.get(agentId);
    if (cached) {
      eventBus.emit("agent-output", {
        agentId,
        output: cached.content,
        paneId: cached.paneId,
        sessionName: cached.sessionName,
        timestamp: Date.now(),
      });
    }
  }
}

export function getActiveAgent(): string | null {
  return activeAgentId;
}

function hashContent(content: string): string {
  return createHash("sha256").update(content).digest("hex");
}

/**
 * Detect if the capture-pane output shows a Claude Code prompt (❯).
 * The prompt line is `❯ ` (U+276F) near the end of the output.
 */
function detectPrompt(content: string): boolean {
  // Check the last 10 non-empty lines for the ❯ prompt
  const lines = content.split("\n");
  const tail = lines.slice(-15);
  return tail.some((line) => line.trimStart().startsWith("❯"));
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

    const prev = paneStates.get(pane.agentId);
    const isActive = pane.agentId === activeAgentId;
    const interval = isActive ? ACTIVE_INTERVAL : INACTIVE_INTERVAL;

    // Skip if not enough time has elapsed for inactive agents
    if (prev && now - prev.lastPoll < interval) {
      continue;
    }

    const content = capturePaneContent(pane.paneId);
    const hash = hashContent(content);
    const hasPrompt = detectPrompt(content);

    // Always update content cache for re-emission on agent switch
    lastCapture.set(pane.agentId, {
      content,
      paneId: pane.paneId,
      sessionName: pane.sessionName,
    });

    if (!prev || prev.hash !== hash) {
      // Content changed
      paneStates.set(pane.agentId, {
        hash,
        lastChange: now,
        lastPoll: now,
        active: true,
        hasPrompt,
      });

      eventBus.emit("agent-output", {
        agentId: pane.agentId,
        output: content,
        paneId: pane.paneId,
        sessionName: pane.sessionName,
        timestamp: now,
      });
    } else {
      // No change — update poll time, check idle transition
      const wasActive = prev.active;
      const isIdle = now - prev.lastChange > IDLE_THRESHOLD;
      paneStates.set(pane.agentId, {
        ...prev,
        lastPoll: now,
        active: wasActive && !isIdle,
        hasPrompt,
      });
    }
  }
}

export function startPaneStreaming(): void {
  if (streaming) return;
  streaming = true;

  // Global tick at ACTIVE_INTERVAL; per-agent throttling in pollPanes()
  intervalHandle = setInterval(pollPanes, ACTIVE_INTERVAL);
}

export function stopPaneStreaming(): void {
  streaming = false;
  if (intervalHandle) {
    clearInterval(intervalHandle);
    intervalHandle = null;
  }
  paneStates.clear();
  lastCapture.clear();
}

export function isStreaming(): boolean {
  return streaming;
}
