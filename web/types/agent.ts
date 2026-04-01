export type AgentStatus = "active" | "idle" | "error" | "stuck";
export type ClusterStatus = "active" | "idle" | "attention";

export type AgentRole = "総司令" | "参謀長" | "隊長" | "副隊長" | "隊員";

export interface Agent {
  id: string;
  name: string;
  role: AgentRole;
  status: AgentStatus;
  task: string;
  stuck: number; // minutes of inactivity
  model?: string;
  paneId?: string;
  sessionName?: string;
}

export interface AvatarDef {
  bg: string;
  ini: string;
  ring: string;
  objectPosition?: string; // CSS object-position for face framing (e.g., "50% 20%")
}

export interface Cluster {
  id: string;
  name: string;
  color: string;
  agents: Agent[];
  clusterStatus: ClusterStatus;
}

export interface ChatMessage {
  role: "user" | "agent";
  text: string;
  time: string;
}

export interface UsageWindow {
  utilization: number; // 0-100 percentage
  resets_at: string; // ISO8601 timestamp
}

export type CodexStatus = "available" | "rate_limited" | "error";

export interface CodexUsageData {
  status: CodexStatus;
  cooldown_until: string | null;
  total_reviews_today: number;
  pass_count: number;
  fail_count: number;
  last_checked: string | null;
  plan: string;
  estimated_remaining: number | null;
}

export interface UsageData {
  five_hour: UsageWindow;
  seven_day: UsageWindow;
  codex?: CodexUsageData;
  fetched_at: number; // unix epoch seconds
}
