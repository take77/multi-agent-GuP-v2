"use client";

import { useEffect, useRef, useMemo } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { MessageFilter, AGENT_CLUSTER_MAP } from "./MessageFilter";
import { getAgentDisplayName } from "@/lib/agent-names";
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
  clear_command: { icon: "🔄", color: "text-amber-400", label: "/clear" },
  model_switch: { icon: "🔧", color: "text-slate-400", label: "モデル切替" },
  system: { icon: "⚙️", color: "text-slate-500", label: "システム" },
};

// Message types treated as commands (displayed as compact badges)
const COMMAND_TYPES = new Set<MessageType>([
  "model_switch",
  "clear_command",
  "system",
]);

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

function extractModelName(content: string): string {
  // "/model sonnet" → "sonnet", "/model opus" → "opus"
  const m = content.match(/\/model\s+(\S+)/);
  return m ? m[1] : content;
}

function CommandBadge({ msg }: { msg: InboxMessage }) {
  const cfg = TYPE_CONFIG[msg.type] ?? TYPE_CONFIG.system;

  const label =
    msg.type === "model_switch"
      ? `${cfg.icon} ${extractModelName(msg.content)}`
      : `${cfg.icon} ${cfg.label}`;

  return (
    <div className="flex items-center gap-1.5 py-0.5">
      <span className="text-[9px] text-slate-700 font-mono shrink-0">
        {formatTimestamp(msg.timestamp)}
      </span>
      <span className="text-[9px] text-slate-600 shrink-0">{getAgentDisplayName(msg.from)}</span>
      <span
        className={`inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-mono bg-slate-800/60 border border-slate-700/30 ${cfg.color}`}
      >
        {label}
      </span>
    </div>
  );
}

function MessageBubble({ msg }: { msg: InboxMessage }) {
  const cfg = TYPE_CONFIG[msg.type] ?? TYPE_CONFIG.system;

  return (
    <div className="flex gap-2 items-start">
      <Avatar id={msg.from} size="w-8 h-8 text-xs" />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-0.5">
          <span className="text-xs font-medium text-slate-300">
            {getAgentDisplayName(msg.from)}
          </span>
          <span className="text-[10px] text-slate-600">→</span>
          <span className="text-xs text-slate-400">{getAgentDisplayName(msg.to)}</span>
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
  const { inboxMessages, messageFilter, showCommands, setShowCommands } =
    useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);

  const filteredMessages = useMemo(() => {
    let msgs = inboxMessages;

    if (messageFilter !== "all") {
      const clusterIds = [
        "command",
        "darjeeling",
        "katyusha",
        "kay",
        "maho",
      ];
      if (clusterIds.includes(messageFilter)) {
        msgs = msgs.filter((m) => {
          const fromCluster = AGENT_CLUSTER_MAP[m.from];
          const toCluster = AGENT_CLUSTER_MAP[m.to];
          return fromCluster === messageFilter || toCluster === messageFilter;
        });
      } else {
        msgs = msgs.filter(
          (m) => m.from === messageFilter || m.to === messageFilter
        );
      }
    }

    return msgs;
  }, [inboxMessages, messageFilter]);

  const visibleMessages = useMemo(() => {
    if (showCommands) return filteredMessages;
    return filteredMessages.filter((m) => !COMMAND_TYPES.has(m.type));
  }, [filteredMessages, showCommands]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [visibleMessages.length]);

  const commandCount = filteredMessages.filter((m) =>
    COMMAND_TYPES.has(m.type)
  ).length;

  return (
    <div className="flex flex-col h-full">
      <MessageFilter />

      {/* Command visibility toggle */}
      <div className="flex items-center gap-2 px-3 py-1.5 border-b border-slate-800/60 bg-slate-900/30">
        <button
          onClick={() => setShowCommands(!showCommands)}
          className={`flex items-center gap-1 px-2 py-0.5 rounded text-[10px] transition-colors ${
            showCommands
              ? "bg-slate-700/60 text-slate-300 border border-slate-600/40"
              : "text-slate-600 hover:text-slate-400 hover:bg-slate-800/40"
          }`}
        >
          🔧 コマンド{showCommands ? "を非表示" : "を表示"}
          {commandCount > 0 && (
            <span className="text-[9px] text-slate-500 ml-0.5">
              ({commandCount})
            </span>
          )}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-3 py-2 space-y-1.5">
        {visibleMessages.length === 0 && (
          <div className="flex flex-col items-center justify-center h-full text-slate-600">
            <span className="text-2xl mb-2">📭</span>
            <p className="text-[12px]">メッセージなし</p>
          </div>
        )}
        {visibleMessages.map((msg) =>
          COMMAND_TYPES.has(msg.type) ? (
            <CommandBadge key={msg.id} msg={msg} />
          ) : (
            <MessageBubble key={msg.id} msg={msg} />
          )
        )}
        <div ref={bottomRef} />
      </div>
      <div className="px-3 py-2 border-t border-slate-700/50 bg-slate-900/50">
        <p className="text-[10px] text-slate-600">
          {visibleMessages.length} 件のメッセージ
          {messageFilter !== "all" && " (フィルタ適用中)"}
          {!showCommands && commandCount > 0 && (
            <span className="text-slate-700 ml-1">
              (+{commandCount} コマンド非表示)
            </span>
          )}
        </p>
      </div>
    </div>
  );
}
