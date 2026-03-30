import { readdirSync, readFileSync, existsSync } from "fs";
import { join, basename } from "path";
import { parse as parseYaml } from "yaml";
import type { Task, TaskPriority } from "@/types/progress";

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");
const TASKS_DIR = join(PROJECT_ROOT, "queue/tasks");
const CLUSTERS_DIR = join(PROJECT_ROOT, "clusters");
const REPORTS_DIR = join(PROJECT_ROOT, "queue/reports");
const SQUADS_PATH = join(PROJECT_ROOT, "config/squads.yaml");
const PROJECTS_PATH = join(PROJECT_ROOT, "config/projects.yaml");

// How long to keep "done" tasks visible in the completed column
const DONE_VISIBLE_MS = 4 * 60 * 60 * 1000; // 4 hours

// Build agent → squad mapping from config/squads.yaml
function loadSquadMapping(): Record<string, string> {
  const mapping: Record<string, string> = {};
  try {
    const content = readFileSync(SQUADS_PATH, "utf-8");
    const data = parseYaml(content) as {
      squads: Record<
        string,
        {
          captain: string;
          vice_captain: string;
          members: string[];
        }
      >;
    };
    for (const [squadId, squad] of Object.entries(data.squads)) {
      mapping[squad.captain] = squadId;
      mapping[squad.vice_captain] = squadId;
      for (const m of squad.members) {
        mapping[m] = squadId;
      }
    }
  } catch {
    // fallback: no mapping
  }
  // Command staff
  mapping["anzu"] = "command";
  mapping["miho"] = "command";
  return mapping;
}

function loadProjects(): Array<{ id: string; name: string }> {
  try {
    const content = readFileSync(PROJECTS_PATH, "utf-8");
    const data = parseYaml(content) as {
      projects: Array<{ id: string; name: string }>;
    };
    return data.projects.map((p) => ({ id: p.id, name: p.name }));
  } catch {
    return [];
  }
}

function loadReports(): Record<
  string,
  {
    status: string;
    summary?: string;
    timestamp?: string;
    branch?: string;
    commit_hash?: string;
  }
> {
  const reports: Record<string, { status: string; summary?: string; timestamp?: string; branch?: string; commit_hash?: string }> = {};
  if (!existsSync(REPORTS_DIR)) return reports;
  try {
    const files = readdirSync(REPORTS_DIR).filter((f) => f.endsWith(".yaml"));
    for (const file of files) {
      try {
        const content = readFileSync(join(REPORTS_DIR, file), "utf-8");
        const data = parseYaml(content) as Record<string, unknown>;
        if (data && data.task_id) {
          reports[data.task_id as string] = {
            status: (data.status as string) || "unknown",
            summary: (data.result as { summary?: string })?.summary,
            timestamp: data.timestamp as string,
            branch: (data.commit_info as { branch?: string })?.branch,
            commit_hash: (data.commit_info as { commit_hash?: string })?.commit_hash,
          };
        }
      } catch {
        // skip unreadable report
      }
    }
  } catch {
    // skip
  }
  return reports;
}

// Collect all task file paths: queue/tasks/ + clusters/*/queue/tasks/
function collectTaskFiles(): Array<{ dir: string; file: string }> {
  const entries: Array<{ dir: string; file: string }> = [];

  // Main queue
  if (existsSync(TASKS_DIR)) {
    try {
      for (const f of readdirSync(TASKS_DIR).filter((f) => f.endsWith(".yaml"))) {
        entries.push({ dir: TASKS_DIR, file: f });
      }
    } catch { /* skip */ }
  }

  // Cluster queues
  if (existsSync(CLUSTERS_DIR)) {
    try {
      for (const cluster of readdirSync(CLUSTERS_DIR)) {
        const clusterTasksDir = join(CLUSTERS_DIR, cluster, "queue", "tasks");
        if (!existsSync(clusterTasksDir)) continue;
        try {
          for (const f of readdirSync(clusterTasksDir).filter((f) => f.endsWith(".yaml"))) {
            entries.push({ dir: clusterTasksDir, file: f });
          }
        } catch { /* skip */ }
      }
    } catch { /* skip */ }
  }

  return entries;
}

export async function GET() {
  const squadMapping = loadSquadMapping();
  const reports = loadReports();
  const projects = loadProjects();
  const tasks: Task[] = [];
  const now = Date.now();

  const taskFiles = collectTaskFiles();
  // Deduplicate by agentId (cluster file takes precedence)
  const seen = new Set<string>();

  for (const { dir, file } of taskFiles) {
    try {
      const agentId = basename(file, ".yaml");
      // squads.yaml に存在しないエージェント（member1〜8, pending 等の残骸）を除外
      if (!(agentId in squadMapping)) continue;
      // Use only first occurrence (main queue first, then clusters)
      if (seen.has(agentId)) continue;
      seen.add(agentId);

      const content = readFileSync(join(dir, file), "utf-8");
      const data = parseYaml(content) as {
        task?: {
          task_id?: string;
          parent_cmd?: string;
          description?: string;
          status?: string;
          bloom_level?: string;
          project?: string;
          timestamp?: string;
        };
      };
      if (!data?.task?.task_id) continue;

      const t = data.task;
      // idle は非表示
      if (t.status === "idle") continue;
      // done は直近 DONE_VISIBLE_MS 以内のみ表示
      if (t.status === "done") {
        if (t.timestamp) {
          const age = now - new Date(t.timestamp).getTime();
          if (age > DONE_VISIBLE_MS) continue;
        } else {
          continue; // タイムスタンプなしの done は非表示
        }
      }

      const report = reports[t.task_id!];

      tasks.push({
        task_id: t.task_id!,
        parent_cmd: t.parent_cmd || "",
        description: (t.description || "").split("\n")[0].trim(),
        assignee: agentId,
        squad: squadMapping[agentId] || "unknown",
        status: (t.status as Task["status"]) || "idle",
        priority: bloomToPriority(t.bloom_level),
        bloom_level: t.bloom_level,
        project: t.project,
        timestamp: t.timestamp,
        report: report
          ? {
              status: report.status as "done" | "failed" | "blocked",
              summary: report.summary,
              timestamp: report.timestamp,
              branch: report.branch,
              commit_hash: report.commit_hash,
            }
          : undefined,
      });
    } catch {
      // skip unreadable task
    }
  }

  return Response.json({ tasks, projects });
}

function bloomToPriority(bloom?: string): TaskPriority {
  if (!bloom) return "MEDIUM";
  const level = parseInt(bloom.replace(/\D/g, ""), 10);
  if (level >= 5) return "HIGH";
  if (level >= 3) return "MEDIUM";
  return "LOW";
}
