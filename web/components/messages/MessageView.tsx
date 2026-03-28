"use client";

import { useEffect, useRef, useMemo } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { MessageFilter, AGENT_CLUSTER_MAP } from "./MessageFilter";
import type { InboxMessage, MessageType } from "@/types/message";

const TYPE_CONFIG: Record<
  MessageType,
  { icon: string; color: string; label: string }
> = {
  task_assigned: { icon: "📋", color: "text-sky-400", label: "タスク配信" },
  report_received: {
    icon: "✅",
    color: "text-emerald-400",
    label: "完了報告",
  },
  qc_request: { icon: "🔍", color: "text-violet-400", label: "QC依頼" },
  qc_result: { icon: "📝", color: "text-violet-300", label: "QC結果" },
  cmd_done: { icon: "🎯", color: "text-green-400", label: "施策完了" },
  cmd_failed: { icon: "❌", color: "text-red-400", label: "施策失敗" },
  cmd_new: { icon: "📨", color: "text-blue-400", label: "新施策" },
  clear_command: { icon: "🔄", color: "text-amber-400", label: "セッションリセット" },
  model_switch: { icon: "🔧", color: "text-slate-400", label: "モデル切替" },
  system: { icon: "⚙️", color: "text-slate-500", label: "システム" },
};

function formatTimestamp(ts: string) {
  try {
    const d = new Date(ts);
    return `${d.getHours().toString().padStart(2, "0")}:${d
      .getMinutes()
      .toString()
      .padStart(2, "0")}`;
  } catch {
    return ts;
  }
}

function MessageBubble({ msg }: { msg: InboxMessage }) {
  const cfg = TYPE_CONFIG[msg.type] ?? TYPE_CONFIG.system;

  return (
    <div className="flex gap-2 items-start">
      <Avatar id={msg.from} size="w-6 h-6 text-[10px]" />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-0.5">
          <span className="text-[11px] font-medium text-slate-300">
            {msg.from}
          </span>
          <span className="text-[10px] text-slate-600">→</span>
          <span className="text-[11px] text-slate-400">{msg.to}</span>
          <span className={`text-[10px] ${cfg.color}`}>
            {cfg.icon} {cfg.label}
          </span>
          <span className="text-[10px] text-slate-600 ml-auto shrink-0">
            {formatTimestamp(msg.timestamp)}
          </span>
        </div>
        <div className="rounded-lg px-3 py-2 bg-slate-800 border border-slate-700/50">
          <p className="text-[12px] text-slate-200 leading-relaxed whitespace-pre-line break-words">
            {msg.content}
          </p>
        </div>
      </div>
    </div>
  );
}

export function MessageView() {
  const { inboxMessages, messageFilter } = useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);

  const filteredMessages = useMemo(() => {
    if (messageFilter === "all") return inboxMessages;

    // Check if filter is a cluster ID
    const clusterIds = [
      "command",
      "darjeeling",
      "katyusha",
      "kay",
      "maho",
    ];
    if (clusterIds.includes(messageFilter)) {
      return inboxMessages.filter((m) => {
        const fromCluster = AGENT_CLUSTER_MAP[m.from];
        const toCluster = AGENT_CLUSTER_MAP[m.to];
        return fromCluster === messageFilter || toCluster === messageFilter;
      });
    }

    // Agent-specific filter
    return inboxMessages.filter(
      (m) => m.from === messageFilter || m.to === messageFilter
    );
  }, [inboxMessages, messageFilter]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [filteredMessages.length]);

  return (
    <div className="flex flex-col h-full">
      <MessageFilter />
      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-3">
        {filteredMessages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-slate-600">
            <span className="text-2xl mb-2">📭</span>
            <p className="text-[12px]">メッセージなし</p>
          </div>
        )}
        {filteredMessages.map((msg) => (
          <MessageBubble key={msg.id} msg={msg} />
        ))}
        <div ref={bottomRef} />
      </div>
      <div className="px-3 py-2 border-t border-slate-700/50 bg-slate-900/50">
        <p className="text-[10px] text-slate-600">
          {filteredMessages.length} 件のメッセージ
          {messageFilter !== "all" && " (フィルタ適用中)"}
        </p>
      </div>
    </div>
  );
}
