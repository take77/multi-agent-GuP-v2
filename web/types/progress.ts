export type TaskStatus = "idle" | "assigned" | "in_progress" | "done" | "failed" | "blocked";

export type TaskPriority = "HIGH" | "MEDIUM" | "LOW";

export interface Task {
  task_id: string;
  parent_cmd: string;
  description: string;
  assignee: string; // agent_id
  squad: string; // cluster/squad id (e.g. "darjeeling", "kay")
  status: TaskStatus;
  priority: TaskPriority;
  bloom_level?: string;
  project?: string;
  timestamp?: string;
  // From report
  report?: {
    status: "done" | "failed" | "blocked";
    summary?: string;
    timestamp?: string;
    branch?: string;
    commit_hash?: string;
  };
}

export type KanbanColumn = "queued" | "in_progress" | "completed";

export interface SquadProgress {
  id: string;
  name: string;
  color: string;
  total: number;
  completed: number;
}

export interface ProgressSummary {
  total: number;
  inProgress: number;
  completed: number;
  queued: number;
  completionRate: number;
}

export interface ProjectInfo {
  id: string;
  name: string;
}
