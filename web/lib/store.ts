import { create } from "zustand";
import type { Agent, Cluster, ChatMessage } from "@/types/agent";

export type ViewId = "chat" | "agents" | "git" | "progress";

// Demo data matching the mock
const DEMO_CLUSTERS: Cluster[] = [
  {
    id: "command",
    name: "司令部",
    color: "#f59e0b",
    agents: [
      { id: "anzu", name: "あんず", role: "総司令", status: "active", task: "全体指揮", stuck: 0 },
      { id: "miho", name: "みほ", role: "参謀長", status: "active", task: "品質監視", stuck: 0 },
    ],
  },
  {
    id: "darjeeling",
    name: "ダージリン隊",
    color: "#3b82f6",
    agents: [
      { id: "darjeeling", name: "ダージリン", role: "隊長", status: "active", task: "API設計レビュー", stuck: 0 },
      { id: "pekoe", name: "ペコ", role: "副隊長", status: "active", task: "REST endpoint実装", stuck: 0 },
      { id: "hana", name: "華", role: "隊員", status: "active", task: "認証ミドルウェア", stuck: 0 },
      { id: "rosehip", name: "ローズヒップ", role: "隊員", status: "active", task: "テスト作成", stuck: 0 },
      { id: "marie", name: "マリー", role: "隊員", status: "idle", task: "タスク待ち", stuck: 0 },
      { id: "andou", name: "安藤", role: "隊員", status: "error", task: "git conflict", stuck: 5 },
      { id: "oshida", name: "押田", role: "隊員", status: "active", task: "DBマイグレーション", stuck: 0 },
    ],
  },
  {
    id: "katyusha",
    name: "カチューシャ隊",
    color: "#ef4444",
    agents: [
      { id: "katyusha", name: "カチューシャ", role: "隊長", status: "active", task: "フロントエンド統括", stuck: 0 },
      { id: "nonna", name: "ノンナ", role: "副隊長", status: "active", task: "コンポーネント設計", stuck: 0 },
      { id: "klara", name: "クラーラ", role: "隊員", status: "active", task: "ダッシュボードUI", stuck: 0 },
      { id: "mako", name: "麻子", role: "隊員", status: "active", task: "レスポンシブ対応", stuck: 8 },
      { id: "erwin", name: "エルヴィン", role: "隊員", status: "idle", task: "待機中", stuck: 12 },
      { id: "caesar", name: "カエサル", role: "隊員", status: "active", task: "CSS最適化", stuck: 0 },
      { id: "saori", name: "沙織", role: "隊員", status: "active", task: "アニメーション", stuck: 0 },
    ],
  },
  {
    id: "kay",
    name: "ケイ隊",
    color: "#22c55e",
    agents: [
      { id: "kay", name: "ケイ", role: "隊長", status: "active", task: "インフラ統括", stuck: 0 },
      { id: "arisa", name: "アリサ", role: "副隊長", status: "active", task: "Docker構成", stuck: 0 },
      { id: "naomi", name: "ナオミ", role: "隊員", status: "active", task: "CI/CD", stuck: 0 },
      { id: "yukari", name: "優花里", role: "隊員", status: "active", task: "モニタリング", stuck: 0 },
      { id: "anchovy", name: "アンチョビ", role: "隊員", status: "idle", task: "待機中", stuck: 0 },
      { id: "pepperoni", name: "ペパロニ", role: "隊員", status: "active", task: "ログ基盤", stuck: 0 },
      { id: "carpaccio", name: "カルパッチョ", role: "隊員", status: "active", task: "デプロイ設定", stuck: 0 },
    ],
  },
  {
    id: "maho",
    name: "まほ隊",
    color: "#a855f7",
    agents: [
      { id: "maho", name: "まほ", role: "隊長", status: "active", task: "ドキュメント統括", stuck: 0 },
      { id: "erika", name: "エリカ", role: "副隊長", status: "active", task: "API仕様書", stuck: 0 },
      { id: "mika", name: "ミカ", role: "隊員", status: "active", task: "偵察レポート", stuck: 0 },
      { id: "aki", name: "アキ", role: "隊員", status: "active", task: "テスト仕様書", stuck: 0 },
      { id: "mikko", name: "ミッコ", role: "隊員", status: "active", task: "Web UI実装", stuck: 0 },
      { id: "kinuyo", name: "絹代", role: "隊員", status: "active", task: "README更新", stuck: 0 },
      { id: "fukuda", name: "福田", role: "隊員", status: "idle", task: "待機中", stuck: 0 },
    ],
  },
];

const DEMO_CHATS: Record<string, ChatMessage[]> = {
  anzu: [
    { role: "user", text: "全隊にWeb UIのPhase 1実装を指示してくれ", time: "14:20" },
    { role: "agent", text: "了解。各隊への指示を配信しました。\n\n\u2022 ダージリン隊 \u2192 バックエンドAPI\n\u2022 カチューシャ隊 \u2192 フロントエンド\n\u2022 ケイ隊 \u2192 インフラ\n\u2022 まほ隊 \u2192 ドキュメント\n\nタスクYAML配置済み。", time: "14:21" },
    { role: "user", text: "ダージリン隊の進捗は？", time: "14:45" },
    { role: "agent", text: "ダージリン隊:\n\u2705 GET /api/agents \u2014 完了\n\u2705 GET /api/agents/:id \u2014 完了\n\ud83d\udd04 POST /api/agents/command \u2014 ペコ実装中\n\u26a0\ufe0f 安藤にgit conflict発生\n\n全体進捗: 65%", time: "14:46" },
  ],
  darjeeling: [
    { role: "user", text: "APIエンドポイントの設計方針は？", time: "14:25" },
    { role: "agent", text: "RESTful設計で進めています:\n1. /api/agents \u2014 エージェント管理\n2. /api/queue \u2014 タスクキュー\n3. /api/stream \u2014 SSE\n\nOpenAPI仕様はまほ隊と並行作成中。", time: "14:26" },
  ],
  miho: [
    { role: "agent", text: "定時レポート \u2014 14:30\n\n\u26a0\ufe0f 停滞検知:\n\u2022 麻子（8分無応答）\n\u2022 エルヴィン（12分無応答）\n\u2022 安藤（5分/conflict）\n\n全体完了率: 25%", time: "14:30" },
  ],
};

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

  clusters: DEMO_CLUSTERS,
  setClusters: (c) => set({ clusters: c }),

  selectedAgent: "anzu",
  setSelectedAgent: (id) => set({ selectedAgent: id }),
  messages: DEMO_CHATS,
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
