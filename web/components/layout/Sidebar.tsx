"use client";

import { useAppStore, type ViewId } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { UsagePanel } from "@/components/shared/UsagePanel";
import { useEffect, useState } from "react";

const NAV: { id: ViewId; label: string; icon: string }[] = [
  { id: "chat", label: "チャット", icon: "\ud83d\udcac" },
  { id: "messages", label: "メッセージ", icon: "\ud83d\udce8" },
  { id: "agents", label: "状態", icon: "\ud83d\udcca" },
  { id: "git", label: "Git", icon: "\ud83d\udd00" },
  { id: "progress", label: "進捗", icon: "\ud83d\udcc8" },
];

const STUCK_THRESHOLD = 5;

export function Sidebar() {
  const { view, setView, clusters, connected } = useAppStore();
  const [clock, setClock] = useState("");

  useEffect(() => {
    const tick = () =>
      setClock(
        new Date().toLocaleTimeString("ja-JP", {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        })
      );
    tick();
    const t = setInterval(tick, 1000);
    return () => clearInterval(t);
  }, []);

  const allAgents = clusters.flatMap((c) => c.agents);
  const activeCount = allAgents.filter((a) => a.status === "active").length;
  const stuckCount = allAgents.filter((a) => a.stuck >= STUCK_THRESHOLD).length;

  const priorities: Record<string, number> = {
    "総司令": 0,
    "参謀長": 1,
    "隊長": 2,
    "副隊長": 3,
  };
  const leaders = allAgents
    .filter((a) => a.status === "active" && priorities[a.role] !== undefined)
    .sort((a, b) => (priorities[a.role] ?? 9) - (priorities[b.role] ?? 9));
  const restCount = activeCount - leaders.length;

  return (
    <nav className="w-full h-full flex flex-col border-r border-slate-700/50 bg-slate-900 shrink-0">
      {/* Logo */}
      <div className="h-11 flex items-center px-3 border-b border-slate-700/50 gap-2">
        <div className="w-6 h-6 rounded-lg bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center text-[10px] font-bold text-black shrink-0">
          G
        </div>
        <span className="text-sm font-semibold text-slate-200">GuP v2</span>
      </div>

      {/* Nav */}
      <div className="py-2 px-1.5 space-y-0.5">
        {NAV.map((n) => (
          <button
            key={n.id}
            onClick={() => setView(n.id)}
            className={`w-full flex items-center gap-2.5 px-2.5 py-2 rounded-lg ${
              view === n.id
                ? "bg-slate-700 text-white"
                : "text-slate-500 hover:text-slate-300 hover:bg-slate-800"
            }`}
          >
            <span>{n.icon}</span>
            <span className="text-[13px]">{n.label}</span>
            {n.id === "agents" && stuckCount > 0 && (
              <span className="ml-auto text-[10px] bg-orange-900/50 text-orange-300 px-1.5 py-0.5 rounded">
                {stuckCount}\u26a0
              </span>
            )}
            {n.id === "agents" && stuckCount === 0 && (
              <span className="ml-auto text-[10px] bg-emerald-900/50 text-emerald-300 px-1.5 py-0.5 rounded">
                {activeCount}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Active leaders */}
      <div className="px-2.5 py-2 border-t border-slate-700/50">
        <div className="flex items-center justify-between mb-1.5">
          <span className="text-[10px] text-slate-600">稼働中</span>
          <span className="text-[10px] text-emerald-400 font-medium">
            {activeCount}体
          </span>
        </div>
        {leaders.slice(0, 6).map((a) => (
          <div key={a.id} className="flex items-center gap-1.5 py-0.5">
            <Avatar id={a.id} size="w-6 h-6 text-[10px]" />
            <span className="text-xs text-slate-400 truncate">{a.name}</span>
          </div>
        ))}
        {restCount > 0 && (
          <div className="text-[10px] text-slate-600 mt-1">
            + 隊員 {restCount}体
          </div>
        )}
      </div>

      <div className="flex-1" />

      {/* Claude usage */}
      <UsagePanel />

      {/* Connection status */}
      <div className="px-2.5 py-2 border-t border-slate-700/50 text-[10px] text-slate-600">
        <div className="flex items-center gap-1.5 mb-1">
          <span
            className={`w-1.5 h-1.5 rounded-full ${
              connected ? "bg-emerald-400" : "bg-red-400"
            }`}
          />
          {connected ? "tmux connected" : "disconnected"}
        </div>
        <div>{clock}</div>
      </div>
    </nav>
  );
}
