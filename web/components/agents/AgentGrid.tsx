"use client";

import { useState } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { StuckAlert } from "./StuckAlert";
import { AgentCard } from "./AgentCard";
import { TerminalLogView } from "./TerminalLogView";
import type { ClusterStatus } from "@/types/agent";

const STUCK_THRESHOLD = 5;

const CLUSTER_STATUS_CONFIG: Record<
  ClusterStatus,
  { label: string; bg: string; text: string; border: string }
> = {
  active: { label: "稼働中", bg: "bg-emerald-900/40", text: "text-emerald-300", border: "border-emerald-700/40" },
  idle: { label: "待機中", bg: "bg-slate-700/40", text: "text-slate-400", border: "border-slate-600/40" },
  attention: { label: "要注意", bg: "bg-orange-900/40", text: "text-orange-300", border: "border-orange-700/40" },
};

export function AgentGrid() {
  const { clusters } = useAppStore();
  const connected = useAppStore((s) => s.connected);
  const [expanded, setExpanded] = useState<string | null>(null);

  const allAgents = clusters.flatMap((c) => c.agents);

  // Expanded terminal view
  if (expanded) {
    const agent = allAgents.find((a) => a.id === expanded);
    const cluster = clusters.find((c) =>
      c.agents.some((a) => a.id === expanded)
    );

    return (
      <div className="flex flex-col h-full">
        <div className="flex items-center gap-3 px-4 py-2.5 border-b border-slate-700/50 bg-slate-900/50">
          <button
            onClick={() => setExpanded(null)}
            className="text-slate-500 hover:text-white text-[13px]"
          >
            ← 戻る
          </button>
          <Avatar
            id={agent?.id ?? ""}
            size="w-6 h-6 text-[10px]"
            online={agent?.status === "active"}
          />
          <span className="text-sm font-medium text-white">{agent?.name}</span>
          <span className="text-[11px] text-slate-500">
            — {cluster?.name} / {agent?.task}
          </span>
          {agent?.model && (
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-700/60 text-slate-400">
              {agent.model}
            </span>
          )}
        </div>
        <TerminalLogView agentId={expanded} />
      </div>
    );
  }

  // Loading state: waiting for first SSE data
  if (clusters.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-600">
        <div className="w-5 h-5 border-2 border-slate-600 border-t-sky-500 rounded-full animate-spin" />
        <span className="text-[12px]">
          {connected ? "エージェント情報を取得中..." : "接続中..."}
        </span>
      </div>
    );
  }

  return (
    <div className="overflow-y-auto h-full">
      <StuckAlert agents={allAgents} onSelect={setExpanded} />

      {/* Connection status */}
      <div className="px-4 pt-3 flex items-center gap-2">
        <span className={`w-1.5 h-1.5 rounded-full ${connected ? "bg-emerald-400" : "bg-red-400 animate-pulse"}`} />
        <span className="text-[10px] text-slate-600">
          {connected ? "ライブ接続中" : "再接続中..."}
        </span>
      </div>

      <div className="p-4 space-y-5">
        {clusters.map((cl) => (
          <div key={cl.id}>
            <div className="flex items-center gap-2 mb-2.5">
              <div
                className="w-2.5 h-2.5 rounded-sm"
                style={{ background: cl.color }}
              />
              <h3 className="text-sm font-semibold text-slate-200">
                {cl.name}
              </h3>
              <span className="text-[11px] text-slate-500">
                {cl.agents.filter((a) => a.status === "active").length}/
                {cl.agents.length}
              </span>
              {(() => {
                const cfg = CLUSTER_STATUS_CONFIG[cl.clusterStatus];
                return (
                  <span className={`text-[10px] px-1.5 py-0.5 rounded ${cfg.bg} ${cfg.text} border ${cfg.border}`}>
                    {cfg.label}
                  </span>
                );
              })()}
            </div>
            <div className="grid grid-cols-2 lg:grid-cols-3 gap-2">
              {cl.agents.map((a) => (
                <AgentCard
                  key={a.id}
                  agent={a}
                  onClick={() => setExpanded(a.id)}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
