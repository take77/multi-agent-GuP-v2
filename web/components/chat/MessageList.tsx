"use client";

import { useEffect, useRef, useMemo } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { parseCapturePaneOutput } from "@/lib/capture-pane-parser";
import { ParsedOutput } from "@/components/chat/ParsedOutput";
import { getAgentDisplayName } from "@/lib/agent-names";

/** Unified chat entry for timeline display */
interface ChatEntry {
  kind: "user" | "agent-output" | "inbox";
  time: string;
  sortKey: number;
  text: string;
  from?: string;
  agentId?: string;
}

export function MessageList() {
  const {
    selectedAgent,
    messages,
    latestOutput,
    clusters,
    inboxMessages,
  } = useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);

  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const userMsgs = messages[selectedAgent] ?? [];
  const output = latestOutput[selectedAgent] ?? "";

  // Build unified timeline (B-1 + B-2)
  const timeline = useMemo(() => {
    const entries: ChatEntry[] = [];

    // User commands → right bubbles (B-1)
    userMsgs.forEach((m, i) => {
      entries.push({
        kind: "user",
        time: m.time,
        sortKey: i,
        text: m.text,
      });
    });

    // Inbox messages for selected agent → interleaved (B-2)
    inboxMessages
      .filter((m) => m.to === selectedAgent || m.from === selectedAgent)
      .forEach((m) => {
        const t = new Date(m.timestamp);
        const timeStr = t.toLocaleTimeString("ja-JP", {
          hour: "2-digit",
          minute: "2-digit",
        });
        entries.push({
          kind: "inbox",
          time: timeStr,
          sortKey: t.getTime(),
          text: m.content,
          from: m.from,
        });
      });

    return entries;
  }, [userMsgs, inboxMessages, selectedAgent]);

  const parsedSegments = useMemo(
    () => parseCapturePaneOutput(output),
    [output]
  );

  // Auto-scroll when new entries arrive or output changes
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [timeline.length, parsedSegments.length, output, selectedAgent]);

  return (
    <div className="flex-1 flex flex-col overflow-y-auto px-3 py-3 space-y-2">
      {/* No output placeholder */}
      {parsedSegments.length === 0 && timeline.length === 0 && (
        <div className="flex flex-col items-center justify-center flex-1 text-slate-600">
          <Avatar id={agent?.id ?? "anzu"} size="w-12 h-12 text-[18px]" />
          <p className="text-[12px] mt-3">{agent?.name} の出力待ち...</p>
        </div>
      )}

      {/* Agent terminal output — structured parsed view */}
      {parsedSegments.length > 0 && (
        <div className="flex items-start gap-2 max-w-[90%]">
          <Avatar
            id={agent?.id ?? "anzu"}
            size="w-6 h-6 text-[9px]"
          />
          <div className="bg-slate-800 rounded-xl rounded-tl-sm px-3 py-2 min-w-0 flex-1 max-h-[60vh] overflow-y-auto">
            <ParsedOutput segments={parsedSegments} />
          </div>
        </div>
      )}

      {/* Interleaved user commands (right) and inbox messages (left) */}
      {timeline.map((entry, i) => {
        if (entry.kind === "user") {
          const isSlashCommand = entry.text.startsWith("/");
          // User command → right bubble (B-1)
          // Slash commands get a distinct badge style
          return (
            <div key={`u-${i}`} className="flex justify-end">
              <div
                className={`max-w-[75%] rounded-xl rounded-tr-sm px-3 py-1.5 ${
                  isSlashCommand
                    ? "bg-violet-700/80 border border-violet-500/40"
                    : "bg-sky-600"
                }`}
              >
                <span className="text-[13px] text-white font-mono">
                  {isSlashCommand ? "🔧 " : "$ "}
                  {entry.text}
                </span>
                <div
                  className={`text-[11px] text-right mt-0.5 ${
                    isSlashCommand ? "text-violet-300" : "text-sky-200"
                  }`}
                >
                  {entry.time}
                </div>
              </div>
            </div>
          );
        }

        if (entry.kind === "inbox") {
          // Inbox interleave → left info bubble (B-2)
          return (
            <div key={`inbox-${i}`} className="flex items-start gap-2 max-w-[85%]">
              <div className="w-6 h-6 rounded-full bg-amber-600/30 flex items-center justify-center text-[12px] shrink-0">
                📩
              </div>
              <div className="bg-amber-900/30 border border-amber-700/40 rounded-xl rounded-tl-sm px-3 py-1.5">
                <span className="text-[12px] text-amber-300 font-medium">
                  {entry.from ? getAgentDisplayName(entry.from) : "不明"}から連絡
                </span>
                <p className="text-[13px] text-slate-300 mt-0.5">
                  {entry.text}
                </p>
                <div className="text-[11px] text-amber-400/60 text-right mt-0.5">
                  {entry.time}
                </div>
              </div>
            </div>
          );
        }

        return null;
      })}

      <div ref={bottomRef} />
    </div>
  );
}
