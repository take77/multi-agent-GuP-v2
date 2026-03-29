"use client";

import type { Agent } from "@/types/agent";
import { Avatar } from "@/components/shared/Avatar";

const STUCK_THRESHOLD = 5;

export function AgentCard({
  agent,
  onClick,
}: {
  agent: Agent;
  onClick: () => void;
}) {
  const isStuck = agent.stuck >= STUCK_THRESHOLD;

  return (
    <button
      onClick={onClick}
      className={`text-left rounded-lg p-2.5 border group ${
        isStuck
          ? "bg-orange-950/40 border-orange-800/40"
          : "bg-slate-800/60 border-slate-700/40 hover:bg-slate-800 hover:border-slate-600"
      }`}
    >
      <div className="flex items-center gap-2 mb-1.5">
        <Avatar id={agent.id} online={agent.status === "active"} />
        <div className="min-w-0">
          <span className="text-sm font-medium text-slate-300 group-hover:text-white block truncate">
            {agent.name}
          </span>
          <div className="flex items-center gap-1">
            <span className="text-[10px] text-slate-500">{agent.role}</span>
            {agent.model && (
              <span className="text-[9px] px-1 rounded bg-slate-700/60 text-slate-400">
                {agent.model}
              </span>
            )}
          </div>
        </div>
        {isStuck && agent.status !== "idle" && (
          <span className="text-[9px] px-1 rounded bg-orange-500/20 text-orange-300 ml-auto">
            {agent.stuck}m
          </span>
        )}
      </div>
      <p
        className={`text-[11px] truncate ${
          isStuck ? "text-orange-300/60" : "text-slate-500"
        }`}
      >
        {agent.task}
      </p>
    </button>
  );
}
