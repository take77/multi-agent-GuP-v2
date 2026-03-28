"use client";

import { useAppStore } from "@/lib/store";

const CLUSTER_TABS = [
  { id: "all", label: "全体" },
  { id: "command", label: "司令部" },
  { id: "darjeeling", label: "ダージリン隊" },
  { id: "katyusha", label: "カチューシャ隊" },
  { id: "kay", label: "ケイ隊" },
  { id: "maho", label: "まほ隊" },
] as const;

// Map agent IDs to cluster IDs
const AGENT_CLUSTER_MAP: Record<string, string> = {
  anzu: "command",
  miho: "command",
  darjeeling: "darjeeling",
  pekoe: "darjeeling",
  hana: "darjeeling",
  rosehip: "darjeeling",
  marie: "darjeeling",
  andou: "darjeeling",
  oshida: "darjeeling",
  katyusha: "katyusha",
  nonna: "katyusha",
  klara: "katyusha",
  mako: "katyusha",
  erwin: "katyusha",
  caesar: "katyusha",
  saori: "katyusha",
  kay: "kay",
  arisa: "kay",
  naomi: "kay",
  yukari: "kay",
  anchovy: "kay",
  pepperoni: "kay",
  carpaccio: "kay",
  maho: "maho",
  erika: "maho",
  mika: "maho",
  aki: "maho",
  mikko: "maho",
  kinuyo: "maho",
  fukuda: "maho",
};

export { AGENT_CLUSTER_MAP };

export function MessageFilter() {
  const { messageFilter, setMessageFilter, clusters } = useAppStore();

  const allAgents = clusters.flatMap((c) => c.agents);

  return (
    <div className="border-b border-slate-700/50 bg-slate-900/50 px-3 py-2">
      {/* Cluster tabs */}
      <div className="flex gap-1 flex-wrap">
        {CLUSTER_TABS.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setMessageFilter(tab.id)}
            className={`px-2.5 py-1 rounded text-[11px] transition-colors ${
              messageFilter === tab.id
                ? "bg-sky-900/60 text-sky-300 border border-sky-700/40"
                : "text-slate-500 hover:text-slate-300 hover:bg-slate-800/60"
            }`}
          >
            {tab.label}
          </button>
        ))}

        {/* Agent dropdown */}
        <select
          value={
            messageFilter !== "all" &&
            !CLUSTER_TABS.some((t) => t.id === messageFilter)
              ? messageFilter
              : ""
          }
          onChange={(e) => {
            if (e.target.value) setMessageFilter(e.target.value);
          }}
          className="ml-auto px-2 py-1 rounded text-[11px] bg-slate-800 border border-slate-700/50 text-slate-400 focus:outline-none focus:border-sky-700/50"
        >
          <option value="">宛先で絞り込み...</option>
          {allAgents.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}
