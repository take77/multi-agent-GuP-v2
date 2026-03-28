"use client";

import { useAppStore } from "@/lib/store";

const STUCK_THRESHOLD = 5;

const VIEW_LABELS: Record<string, string> = {
  chat: "チャット",
  agents: "状態",
  git: "Git",
  progress: "進捗",
};

export function Header() {
  const { view, clusters } = useAppStore();
  const allAgents = clusters.flatMap((c) => c.agents);
  const activeCount = allAgents.filter((a) => a.status === "active").length;
  const stuckCount = allAgents.filter((a) => a.stuck >= STUCK_THRESHOLD).length;

  return (
    <header className="h-11 flex items-center justify-between px-4 border-b border-slate-700/50 bg-slate-900/50 shrink-0">
      <h1 className="text-sm font-medium text-slate-400">
        {VIEW_LABELS[view] ?? view}
      </h1>
      <div className="flex items-center gap-3">
        {stuckCount > 0 && (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-orange-900/40 border border-orange-700/40">
            <span className="w-1.5 h-1.5 rounded-full bg-orange-500 animate-pulse" />
            <span className="text-[10px] text-orange-300">
              {stuckCount} stuck
            </span>
          </div>
        )}
        <div className="flex items-center gap-1.5 text-[11px] text-slate-500">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
          {activeCount} agents
        </div>
      </div>
    </header>
  );
}
