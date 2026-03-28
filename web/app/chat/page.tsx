"use client";

import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { ChatSidebar } from "@/components/chat/ChatSidebar";
import { MessageList } from "@/components/chat/MessageList";
import { CommandInput } from "@/components/chat/CommandInput";

const STUCK_THRESHOLD = 5;

export default function ChatPage() {
  const { selectedAgent, clusters } = useAppStore();
  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  return (
    <div className="flex h-full overflow-hidden">
      <ChatSidebar />
      <div className="flex-1 flex flex-col bg-slate-950 min-w-0">
        {agent && (
          <div className="flex items-center gap-2 px-3 py-2 border-b border-slate-700/50 bg-slate-900/50 overflow-hidden">
            <Avatar id={agent.id} size="w-6 h-6 text-[10px]" />
            <span className="text-[13px] font-medium text-white shrink-0">
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
