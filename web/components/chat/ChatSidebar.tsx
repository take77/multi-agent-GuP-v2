"use client";

import { useState } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";

const STUCK_THRESHOLD = 5;

export function ChatSidebar() {
  const clusters = useAppStore((s) => s.clusters);
  const selectedAgent = useAppStore((s) => s.selectedAgent);
  const setSelectedAgent = useAppStore((s) => s.setSelectedAgent);
  const messages = useAppStore((s) => s.messages);
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});

  const toggle = (id: string) =>
    setCollapsed((p) => ({ ...p, [id]: !p[id] }));

  const selectedAgentData = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  return (
    <div className="w-40 border-r border-slate-700/50 flex flex-col bg-slate-900/80 shrink-0">
      <div className="flex-1 overflow-y-auto py-1">
        {clusters.map((cl) => {
          const isOpen = !collapsed[cl.id];
          const activeN = cl.agents.filter(
            (a) => a.status === "active"
          ).length;
          const hasSel = cl.agents.some((a) => a.id === selectedAgent);

          return (
            <div key={cl.id}>
              <button
                onClick={() => toggle(cl.id)}
                className="w-full flex items-center gap-1.5 px-2.5 pt-2.5 pb-1 hover:bg-slate-800/40"
              >
                <svg
                  width="10"
                  height="10"
                  viewBox="0 0 10 10"
                  className={`text-slate-600 transition-transform ${
                    isOpen ? "rotate-90" : ""
                  }`}
                >
                  <path
                    d="M3 1l4 4-4 4"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
                <div
                  className="w-1.5 h-1.5 rounded-sm shrink-0"
                  style={{ background: cl.color }}
                />
                <span className="text-[10px] font-medium text-slate-500 truncate">
                  {cl.name}
                </span>
                <span className="text-[9px] text-slate-600 ml-auto">
                  {activeN}/{cl.agents.length}
                </span>
              </button>
              {isOpen &&
                cl.agents.map((a) => (
                  <button
                    key={a.id}
                    onClick={() => setSelectedAgent(a.id)}
                    className={`w-full flex items-center gap-2 px-3 py-1.5 text-left ${
                      selectedAgent === a.id
                        ? "bg-slate-700/60 border-l-2 border-sky-400"
                        : "border-l-2 border-transparent hover:bg-slate-800/60"
                    }`}
                  >
                    <Avatar id={a.id} online={a.status === "active"} />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5">
                        <span
                          className={`text-[11px] truncate ${
                            selectedAgent === a.id
                              ? "text-white"
                              : "text-slate-400"
                          }`}
                        >
                          {a.name}
                        </span>
                        {a.stuck >= STUCK_THRESHOLD && (
                          <span className="text-[9px] px-1 rounded bg-orange-500/20 text-orange-300">
                            {a.stuck}m
                          </span>
                        )}
                      </div>
                      {messages[a.id] && (
                        <p className="text-[9px] text-slate-600 truncate">
                          {messages[a.id].slice(-1)[0].text.split("\n")[0]}
                        </p>
                      )}
                    </div>
                  </button>
                ))}
              {!isOpen && hasSel && (
                <div className="px-3 py-1 text-[9px] text-sky-400 truncate">
                  \u25cf {selectedAgentData?.name}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
