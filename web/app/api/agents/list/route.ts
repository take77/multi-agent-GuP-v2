import { NextResponse } from "next/server";
import { readFileSync } from "fs";
import { parse as parseYaml } from "yaml";
import { join } from "path";
import { listPanes, type PaneInfo } from "@/lib/tmux";
import { paneStates } from "@/lib/pane-streamer";

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");

interface SquadConfig {
  captain: string;
  vice_captain: string;
  members: string[];
}

interface SquadsYaml {
  squads: Record<string, SquadConfig>;
}

// Cluster display config
const CLUSTER_META: Record<string, { name: string; color: string }> = {
  command: { name: "司令部", color: "#f59e0b" },
  darjeeling: { name: "ダージリン隊", color: "#3b82f6" },
  katyusha: { name: "カチューシャ隊", color: "#ef4444" },
  kay: { name: "ケイ隊", color: "#22c55e" },
  maho: { name: "まほ隊", color: "#a855f7" },
};

// Agent display names
const AGENT_NAMES: Record<string, string> = {
  anzu: "あんず",
  miho: "みほ",
  darjeeling: "ダージリン",
  pekoe: "ペコ",
  hana: "華",
  rosehip: "ローズヒップ",
  marie: "マリー",
  andou: "安藤",
  oshida: "押田",
  katyusha: "カチューシャ",
  nonna: "ノンナ",
  klara: "クラーラ",
  mako: "麻子",
  erwin: "エルヴィン",
  caesar: "カエサル",
  saori: "沙織",
  kay: "ケイ",
  arisa: "アリサ",
  naomi: "ナオミ",
  yukari: "優花里",
  anchovy: "アンチョビ",
  pepperoni: "ペパロニ",
  carpaccio: "カルパッチョ",
  maho: "まほ",
  erika: "エリカ",
  mika: "ミカ",
  aki: "アキ",
  mikko: "ミッコ",
  kinuyo: "絹代",
  fukuda: "福田",
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
    const content = readFileSync(
      join(PROJECT_ROOT, "config/squads.yaml"),
      "utf-8"
    );
    return parseYaml(content) as SquadsYaml;
  } catch {
    return null;
  }
}

function getTaskInfo(
  agentId: string
): { task: string; status: string } | null {
  try {
    const content = readFileSync(
      join(PROJECT_ROOT, `queue/tasks/${agentId}.yaml`),
      "utf-8"
    );
    const data = parseYaml(content) as { task?: { description?: string; status?: string } };
    return {
      task: data.task?.description?.split("\n")[0]?.trim() || "タスクなし",
      status: data.task?.status || "idle",
    };
  } catch {
    return null;
  }
}

function computeStatus(agentId: string, pane: PaneInfo | undefined): { status: "active" | "idle" | "stuck" | "error"; stuckMin: number } {
  if (!pane) return { status: "idle", stuckMin: 0 };

  const state = paneStates.get(agentId);
  if (!state) return { status: "idle", stuckMin: 0 };

  const stuckMin = Math.floor((Date.now() - state.lastChange) / 60000);

  if (state.active) return { status: "active", stuckMin: 0 };
  if (state.hasPrompt) return { status: "idle", stuckMin: 0 };
  if (stuckMin >= 5) return { status: "stuck", stuckMin };
  return { status: "active", stuckMin: 0 };
}

export async function GET() {
  const panes = listPanes();
  const paneMap = new Map<string, PaneInfo>();
  for (const p of panes) {
    if (p.agentId) paneMap.set(p.agentId, p);
  }

  const squads = loadSquads();
  const clusters = [];

  // Command cluster (anzu + miho)
  const commandAgents = ["anzu", "miho"].map((id) => {
    const pane = paneMap.get(id);
    const taskInfo = getTaskInfo(id);
    const { status, stuckMin } = computeStatus(id, pane);
    return {
      id,
      name: AGENT_NAMES[id] || id,
      role: id === "anzu" ? "総司令" : "参謀長",
      status,
      task: taskInfo?.task || "待機中",
      stuck: stuckMin,
      model: pane?.modelName || "",
      paneId: pane?.paneId || null,
      sessionName: pane?.sessionName || null,
    };
  });

  clusters.push({
    id: "command",
    ...CLUSTER_META.command,
    agents: commandAgents,
  });

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
        const { status, stuckMin } = computeStatus(id, pane);
        return {
          id,
          name: AGENT_NAMES[id] || id,
          role: ROLE_LABELS[role] || role,
          status,
          task: taskInfo?.task || "待機中",
          stuck: stuckMin,
          model: pane?.modelName || "",
          paneId: pane?.paneId || null,
          sessionName: pane?.sessionName || null,
        };
      });

      const meta = CLUSTER_META[squadId] || {
        name: squadId,
        color: "#6b7280",
      };
      clusters.push({ id: squadId, ...meta, agents });
    }
  }

  return NextResponse.json({ clusters });
}
