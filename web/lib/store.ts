import { create } from "zustand";
import type { Agent, Cluster, ChatMessage } from "@/types/agent";
import type { InboxMessage, MessageFilter } from "@/types/message";

export type ViewId = "chat" | "agents" | "git" | "progress" | "messages";

// Initial empty state — populated by SSE /api/sse/agents
const INITIAL_CLUSTERS: Cluster[] = [];

const INITIAL_CHATS: Record<string, ChatMessage[]> = {};

export interface CommandError {
  rule?: string;
  message: string;
}

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

  // Terminal output (latest capture-pane, replaced on each update)
  latestOutput: Record<string, string>;
  setLatestOutput: (agentId: string, output: string) => void;

  // Command history (per agent)
  commandHistory: Record<string, string[]>;
  addCommandHistory: (agentId: string, command: string) => void;

  // Command sending
  sendCommand: (
    agentId: string,
    command: string
  ) => Promise<{ success: boolean; error?: CommandError }>;

  // Inbox messages
  inboxMessages: InboxMessage[];
  setInboxMessages: (msgs: InboxMessage[]) => void;
  addInboxMessage: (msg: InboxMessage) => void;
  messageFilter: MessageFilter;
  setMessageFilter: (f: MessageFilter) => void;
  showCommands: boolean;
  setShowCommands: (v: boolean) => void;

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
  setSelectedAgent: (id) => {
    set({ selectedAgent: id });
    // Notify server so pane-streamer adjusts polling frequency
    const token = typeof document !== "undefined"
      ? document.cookie.split("; ").find((c) => c.startsWith("auth_token="))?.split("=")[1] ?? ""
      : "";
    fetch("/api/agents/active", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ agentId: id }),
    }).catch(() => {});
  },
  messages: INITIAL_CHATS,
  addMessage: (agentId, msg) =>
    set((s) => ({
      messages: {
        ...s.messages,
        [agentId]: [...(s.messages[agentId] ?? []), msg],
      },
    })),

  latestOutput: {},
  setLatestOutput: (agentId, output) =>
    set((s) => ({
      latestOutput: {
        ...s.latestOutput,
        [agentId]: output,
      },
    })),

  commandHistory: {},
  addCommandHistory: (agentId, command) =>
    set((s) => {
      const prev = s.commandHistory[agentId] ?? [];
      // Dedupe consecutive duplicates, keep last 50
      if (prev[prev.length - 1] === command) return s;
      return {
        commandHistory: {
          ...s.commandHistory,
          [agentId]: [...prev, command].slice(-50),
        },
      };
    }),

  sendCommand: async (agentId, command) => {
    try {
      const token =
        typeof window !== "undefined"
          ? document.cookie
              .split("; ")
              .find((c) => c.startsWith("auth_token="))
              ?.split("=")[1] ?? ""
          : "";

      const res = await fetch("/api/agents/command", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ agentId, command }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        return {
          success: false,
          error: {
            rule: body.rule,
            message:
              body.message ?? body.error ?? `HTTP ${res.status}`,
          },
        };
      }

      return { success: true };
    } catch {
      return {
        success: false,
        error: { message: "ネットワークエラー — サーバーに接続できません" },
      };
    }
  },

  inboxMessages: [],
  setInboxMessages: (msgs) => set({ inboxMessages: msgs }),
  addInboxMessage: (msg) =>
    set((s) => {
      if (s.inboxMessages.some((m) => m.id === msg.id)) return s;
      return { inboxMessages: [...s.inboxMessages, msg] };
    }),
  messageFilter: "all",
  setMessageFilter: (f) => set({ messageFilter: f }),
  showCommands: true,
  setShowCommands: (v) => set({ showCommands: v }),

  connected: false,
  setConnected: (v) => set({ connected: v }),
}));
