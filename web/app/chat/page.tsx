"use client";

import { useState, useCallback, useRef } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { ChatSidebar } from "@/components/chat/ChatSidebar";
import { MessageList } from "@/components/chat/MessageList";
import { CommandInput } from "@/components/chat/CommandInput";

const STUCK_THRESHOLD = 5;
const SIDEBAR_MIN = 120;
const SIDEBAR_MAX = 400;
const SIDEBAR_DEFAULT = 160;

export default function ChatPage() {
  const { selectedAgent, clusters } = useAppStore();
  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const [sidebarWidth, setSidebarWidth] = useState(SIDEBAR_DEFAULT);
  const dragging = useRef(false);
  const startX = useRef(0);
  const startWidth = useRef(0);

  const onHandleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      dragging.current = true;
      startX.current = e.clientX;
      startWidth.current = sidebarWidth;
      e.preventDefault();
    },
    [sidebarWidth]
  );

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (!dragging.current) return;
    const delta = e.clientX - startX.current;
    const next = Math.min(
      SIDEBAR_MAX,
      Math.max(SIDEBAR_MIN, startWidth.current + delta)
    );
    setSidebarWidth(next);
  }, []);

  const onMouseUp = useCallback(() => {
    dragging.current = false;
  }, []);

  return (
    <div
      className="flex h-full overflow-hidden"
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseUp}
    >
      {/* Sidebar with dynamic width */}
      <div style={{ width: sidebarWidth }} className="shrink-0 overflow-hidden">
        <ChatSidebar />
      </div>

      {/* Resize handle */}
      <div
        className="w-1 bg-slate-700/30 hover:bg-slate-500/70 active:bg-sky-500/60 cursor-col-resize shrink-0 transition-colors"
        onMouseDown={onHandleMouseDown}
      />

      {/* Main chat area */}
      <div className="flex-1 flex flex-col bg-slate-950 min-w-0">
        {agent && (
          <div className="flex items-center gap-2 px-3 py-2 border-b border-slate-700/50 bg-slate-900/50 overflow-hidden">
            <Avatar id={agent.id} size="w-8 h-8 text-xs" />
            <span className="text-sm font-medium text-white shrink-0">
              {agent.name}
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded border border-slate-600 text-slate-400 shrink-0">
              {agent.role}
            </span>
            {agent.stuck >= STUCK_THRESHOLD && (
              <span className="text-[10px] px-1.5 py-0.5 rounded bg-orange-900/50 text-orange-300 border border-orange-700/50 shrink-0">
                \u26a0 {agent.stuck}m
              </span>
            )}
            <span className="text-[11px] text-slate-500 truncate ml-auto">
              {agent.task}
            </span>
          </div>
        )}
        <MessageList />
        <CommandInput />
      </div>
    </div>
  );
}
