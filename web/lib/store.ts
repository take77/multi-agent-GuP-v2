import { create } from "zustand";
import type { Agent, Cluster, ChatMessage } from "@/types/agent";

export type ViewId = "chat" | "agents" | "git" | "progress";

// Initial empty state — populated by SSE /api/sse/agents
const INITIAL_CLUSTERS: Cluster[] = [];

const INITIAL_CHATS: Record<string, ChatMessage[]> = {};

interface AppState {
  // Navigation
  view: ViewId;
  setView: (v: ViewId) => void;

  // Agents
  clusters: Cluster[];
  setClusters: (c: Cluster[]) => void;

  // Chat
  selectedAgent: string;
  setSelectedAgent: (id: string) => void;
  messages: Record<string, ChatMessage[]>;
  addMessage: (agentId: string, msg: ChatMessage) => void;

  // SSE connection
  connected: boolean;
  setConnected: (v: boolean) => void;
}

export const useAppStore = create<AppState>((set) => ({
  view: "chat",
  setView: (v) => set({ view: v }),

  clusters: INITIAL_CLUSTERS,
  setClusters: (c) => set({ clusters: c }),

  selectedAgent: "anzu",
  setSelectedAgent: (id) => set({ selectedAgent: id }),
  messages: INITIAL_CHATS,
  addMessage: (agentId, msg) =>
    set((s) => ({
      messages: {
        ...s.messages,
        [agentId]: [...(s.messages[agentId] ?? []), msg],
      },
    })),

  connected: false,
  setConnected: (v) => set({ connected: v }),
}));
