import { create } from "zustand";
import type {
  Task,
  ProgressSummary,
  SquadProgress,
  ProjectInfo,
  KanbanColumn,
} from "@/types/progress";

interface ProgressState {
  // Data
  tasks: Task[];
  projects: ProjectInfo[];

  // Filters
  selectedProject: string | null; // null = "全リポ"
  setSelectedProject: (id: string | null) => void;

  // Actions
  setTasks: (tasks: Task[]) => void;
  setProjects: (projects: ProjectInfo[]) => void;

  // Derived (computed via selectors)
}

export const useProgressStore = create<ProgressState>((set) => ({
  tasks: [],
  projects: [],
  selectedProject: null,
  setSelectedProject: (id) => set({ selectedProject: id }),
  setTasks: (tasks) => set({ tasks }),
  setProjects: (projects) => set({ projects }),
}));

// Selectors
export function getFilteredTasks(state: ProgressState): Task[] {
  if (!state.selectedProject) return state.tasks;
  return state.tasks.filter((t) => t.project === state.selectedProject);
}

export function getSummary(tasks: Task[]): ProgressSummary {
  const total = tasks.length;
  const inProgress = tasks.filter((t) => t.status === "in_progress").length;
  const completed = tasks.filter((t) => t.status === "done").length;
  const queued = tasks.filter(
    (t) => t.status === "assigned" || t.status === "idle"
  ).length;
  const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;
  return { total, inProgress, completed, queued, completionRate };
}

const SQUAD_META: Record<string, { name: string; color: string }> = {
  darjeeling: { name: "ダージリン隊", color: "#3b82f6" },
  katyusha: { name: "カチューシャ隊", color: "#ef4444" },
  kay: { name: "ケイ隊", color: "#22c55e" },
  maho: { name: "まほ隊", color: "#a855f7" },
  command: { name: "司令部", color: "#f59e0b" },
};

export function getSquadProgress(tasks: Task[]): SquadProgress[] {
  const squads = new Map<string, { total: number; completed: number }>();
  for (const task of tasks) {
    const squad = task.squad || "unknown";
    if (!squads.has(squad)) squads.set(squad, { total: 0, completed: 0 });
    const s = squads.get(squad)!;
    s.total++;
    if (task.status === "done") s.completed++;
  }
  return Array.from(squads.entries()).map(([id, { total, completed }]) => ({
    id,
    name: SQUAD_META[id]?.name ?? id,
    color: SQUAD_META[id]?.color ?? "#64748b",
    total,
    completed,
  }));
}

export function getKanbanTasks(
  tasks: Task[]
): Record<KanbanColumn, Task[]> {
  const result: Record<KanbanColumn, Task[]> = {
    queued: [],
    in_progress: [],
    completed: [],
  };
  for (const task of tasks) {
    switch (task.status) {
      case "done":
        result.completed.push(task);
        break;
      case "in_progress":
        result.in_progress.push(task);
        break;
      case "failed":
      case "blocked":
        result.in_progress.push(task); // Show blocked/failed in "in_progress" column
        break;
      default:
        result.queued.push(task);
    }
  }
  return result;
}
