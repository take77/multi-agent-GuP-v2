import { create } from "zustand";
import type { Agent, Cluster, ChatMessage } from "@/types/agent";
import type { InboxMessage, MessageFilter } from "@/types/message";

export type ViewId = "chat" | "agents" | "git" | "progress" | "messages";

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

  // Inbox messages
  inboxMessages: InboxMessage[];
  setInboxMessages: (msgs: InboxMessage[]) => void;
  addInboxMessage: (msg: InboxMessage) => void;
  messageFilter: MessageFilter;
  setMessageFilter: (f: MessageFilter) => void;

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

  inboxMessages: [],
  setInboxMessages: (msgs) => set({ inboxMessages: msgs }),
  addInboxMessage: (msg) =>
    set((s) => {
      if (s.inboxMessages.some((m) => m.id === msg.id)) return s;
      return { inboxMessages: [...s.inboxMessages, msg] };
    }),
  messageFilter: "all",
  setMessageFilter: (f) => set({ messageFilter: f }),

  connected: false,
  setConnected: (v) => set({ connected: v }),
}));
