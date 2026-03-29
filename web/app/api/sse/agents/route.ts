import { readFileSync, readdirSync } from "fs";
import { parse as parseYaml } from "yaml";
import { join } from "path";
import { listPanes, type PaneInfo } from "@/lib/tmux";
import { paneStates } from "@/lib/pane-streamer";
import type { ClusterStatus } from "@/types/agent";
import { getAgentDisplayName } from "@/lib/agent-names";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");
const POLL_INTERVAL = 5000; // 5 seconds
const STUCK_THRESHOLD_MS = 5 * 60 * 1000; // 5 minutes

interface SquadConfig {
  captain: string;
  vice_captain: string;
  members: string[];
}

interface SquadsYaml {
  squads: Record<string, SquadConfig>;
}

const CLUSTER_META: Record<string, { name: string; color: string }> = {
  command: { name: "司令部", color: "#f59e0b" },
  darjeeling: { name: "ダージリン隊", color: "#3b82f6" },
  katyusha: { name: "カチューシャ隊", color: "#ef4444" },
  kay: { name: "ケイ隊", color: "#22c55e" },
  maho: { name: "まほ隊", color: "#a855f7" },
};

const ROLE_LABELS: Record<string, string> = {
  battalion_commander: "総司令",
  chief_of_staff: "参謀長",
  captain: "隊長",
  vice_captain: "副隊長",
  member: "隊員",
};

function loadSquads(): SquadsYaml | null {
  try {
    const content = readFileSync(join(PROJECT_ROOT, "config/squads.yaml"), "utf-8");
    return parseYaml(content) as SquadsYaml;
  } catch {
    return null;
  }
}

function getTaskInfo(agentId: string): { task: string; status: string } | null {
  try {
    const content = readFileSync(join(PROJECT_ROOT, `queue/tasks/${agentId}.yaml`), "utf-8");
    const data = parseYaml(content) as { task?: { description?: string; status?: string } };
    return {
      task: data.task?.description?.split("\n")[0]?.trim() || "タスクなし",
      status: data.task?.status || "idle",
    };
  } catch {
    return null;
  }
}

function computeStuckMinutes(agentId: string): number {
  const state = paneStates.get(agentId);
  if (!state) return 0;
  const elapsed = Date.now() - state.lastChange;
  return Math.floor(elapsed / 60000);
}

function determineStatus(pane: PaneInfo | undefined, stuckMin: number, _taskStatus: string, agentId: string): "active" | "idle" | "stuck" | "error" {
  if (!pane) return "idle";

  const state = paneStates.get(agentId);

  // If pane-streamer considers the output actively changing → active
  if (state?.active) return "active";

  // If prompt (❯) is visible → agent is idle (normal wait state)
  if (state?.hasPrompt) return "idle";

  // No output change for 5+ min AND no prompt → stuck
  if (stuckMin >= 5) return "stuck";

  // Brief inactivity without prompt — still could be processing (e.g. long tool call)
  return "active";
}

function hasUnreadInbox(agentId: string): boolean {
  try {
    const content = readFileSync(join(PROJECT_ROOT, `queue/inbox/${agentId}.yaml`), "utf-8");
    const data = parseYaml(content) as { messages?: Array<{ read?: boolean }> };
    if (!data?.messages) return false;
    return data.messages.some((m) => m.read === false);
  } catch {
    return false;
  }
}

function computeClusterStatus(agents: Array<{ id: string; status: string }>): ClusterStatus {
  const hasActive = agents.some((a) => a.status === "active");
  if (hasActive) return "active";

  // All idle/stuck/error — check inbox for unread messages
  const hasUnread = agents.some((a) => hasUnreadInbox(a.id));
  if (hasUnread) return "attention";

  return "idle";
}

function buildClusters() {
  const panes = listPanes();
  const paneMap = new Map<string, PaneInfo>();
  for (const p of panes) {
    if (p.agentId) paneMap.set(p.agentId, p);
  }

  const squads = loadSquads();
  const clusters = [];

  // Command cluster
  const commandAgents = ["anzu", "miho"].map((id) => {
    const pane = paneMap.get(id);
    const taskInfo = getTaskInfo(id);
    const stuckMin = computeStuckMinutes(id);
    const status = determineStatus(pane, stuckMin, taskInfo?.status || "idle", id);
    return {
      id,
      name: getAgentDisplayName(id),
      role: id === "anzu" ? "総司令" : "参謀長",
      status,
      task: taskInfo?.task || "待機中",
      stuck: status === "stuck" ? stuckMin : 0,
      model: pane?.modelName || "",
      paneId: pane?.paneId || null,
      sessionName: pane?.sessionName || null,
    };
  });

  clusters.push({ id: "command", ...CLUSTER_META.command, agents: commandAgents, clusterStatus: computeClusterStatus(commandAgents) });

  // Squad clusters
  if (squads) {
    for (const [squadId, squad] of Object.entries(squads.squads)) {
      const allMembers = [
        { id: squad.captain, role: "captain" },
        { id: squad.vice_captain, role: "vice_captain" },
        ...squad.members.map((m) => ({ id: m, role: "member" })),
      ];

      const agents = allMembers.map(({ id, role }) => {
        const pane = paneMap.get(id);
        const taskInfo = getTaskInfo(id);
        const stuckMin = computeStuckMinutes(id);
        const status = determineStatus(pane, stuckMin, taskInfo?.status || "idle", id);
        return {
          id,
          name: getAgentDisplayName(id),
          role: ROLE_LABELS[role] || role,
          status,
          task: taskInfo?.task || "待機中",
          stuck: status === "stuck" ? stuckMin : 0,
          model: pane?.modelName || "",
          paneId: pane?.paneId || null,
          sessionName: pane?.sessionName || null,
        };
      });

      const meta = CLUSTER_META[squadId] || { name: squadId, color: "#6b7280" };
      clusters.push({ id: squadId, ...meta, agents, clusterStatus: computeClusterStatus(agents) });
    }
  }

  return clusters;
}

export async function GET(req: Request) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      function send(event: string, data: unknown) {
        try {
          controller.enqueue(
            encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          );
        } catch {
          // Controller closed
        }
      }

      // Send initial state immediately
      send("agent-status", { clusters: buildClusters() });

      // Poll and send updates every 5 seconds
      const interval = setInterval(() => {
        send("agent-status", { clusters: buildClusters() });
      }, POLL_INTERVAL);

      // Heartbeat every 30 seconds
      const heartbeat = setInterval(() => {
        send("heartbeat", Date.now());
      }, 30000);

      // Clean up on disconnect
      req.signal.addEventListener("abort", () => {
        clearInterval(interval);
        clearInterval(heartbeat);
        try {
          controller.close();
        } catch {
          // already closed
        }
      });
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
