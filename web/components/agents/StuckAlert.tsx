"use client";

import type { Agent } from "@/types/agent";
import { Avatar } from "@/components/shared/Avatar";

const STUCK_THRESHOLD = 5;

export function StuckAlert({
  agents,
  onSelect,
}: {
  agents: Agent[];
  onSelect: (id: string) => void;
}) {
  const stuck = agents.filter((a) => a.stuck >= STUCK_THRESHOLD);
  if (stuck.length === 0) return null;

  return (
    <div className="mx-4 mt-4 p-3 rounded-lg bg-orange-950/60 border border-orange-800/50">
      <div className="flex items-center gap-2 mb-2">
        <span className="w-2 h-2 rounded-full bg-orange-500 animate-pulse" />
        <span className="text-[12px] font-medium text-orange-300">
          停滞検知: {stuck.length}体が無応答
        </span>
      </div>
      <div className="flex flex-wrap gap-2">
        {stuck.map((a) => (
          <button
            key={a.id}
            onClick={() => onSelect(a.id)}
            className="flex items-center gap-2 px-2 py-1 rounded bg-orange-900/40 hover:bg-orange-900/60 border border-orange-700/40"
          >
            <Avatar id={a.id} size="w-5 h-5 text-[9px]" />
            <span className="text-[11px] text-orange-200">{a.name}</span>
            <span className="text-[10px] text-orange-400">{a.stuck}分</span>
          </button>
        ))}
      </div>
    </div>
  );
}
