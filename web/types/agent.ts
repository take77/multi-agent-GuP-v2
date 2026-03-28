export type AgentStatus = "active" | "idle" | "error" | "stuck";

export type AgentRole = "総司令" | "参謀長" | "隊長" | "副隊長" | "隊員";

export interface Agent {
  id: string;
  name: string;
  role: AgentRole;
  status: AgentStatus;
  task: string;
  stuck: number; // minutes of inactivity
  paneId?: string;
  sessionName?: string;
}

export interface AvatarDef {
  bg: string;
  ini: string;
  ring: string;
}

export interface Cluster {
  id: string;
  name: string;
  color: string;
  agents: Agent[];
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

export interface UsageData {
  five_hour: UsageWindow;
  seven_day: UsageWindow;
  fetched_at: number; // unix epoch seconds
}
