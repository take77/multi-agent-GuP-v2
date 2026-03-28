"use client";

import { useEffect, useRef, useMemo } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";

/** Strip tmux input prompt line from capture-pane output (B-3) */
function stripPromptLine(output: string): string {
  const lines = output.split("\n");
  // Remove trailing empty lines and the last prompt line (typically ends with ❯, $, %, or >)
  while (lines.length > 0) {
    const last = lines[lines.length - 1].trim();
    if (last === "") {
      lines.pop();
      continue;
    }
    // Common prompt patterns: ends with ❯, $, %, >, or contains typical prompt chars
    if (/[❯$%>]\s*$/.test(last) || /^\s*[\w.~\/-]*[❯$%>]\s*$/.test(last)) {
      lines.pop();
      break;
    }
    break;
  }
  return lines.join("\n");
}

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
        // Summarize: first 60 chars of content
        const summary =
          m.content.length > 60
            ? m.content.slice(0, 60) + "…"
            : m.content;
        entries.push({
          kind: "inbox",
          time: timeStr,
          sortKey: t.getTime(),
          text: summary,
          from: m.from,
        });
      });

    return entries;
  }, [userMsgs, inboxMessages, selectedAgent]);

  // Auto-scroll when new entries arrive or output changes
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [timeline.length, output, selectedAgent]);

  const cleanOutput = useMemo(() => stripPromptLine(output), [output]);

  return (
    <div className="flex-1 flex flex-col overflow-y-auto px-3 py-3 space-y-2">
      {/* No output placeholder */}
      {!cleanOutput && timeline.length === 0 && (
        <div className="flex flex-col items-center justify-center flex-1 text-slate-600">
          <Avatar id={agent?.id ?? "anzu"} size="w-12 h-12 text-[18px]" />
          <p className="text-[12px] mt-3">{agent?.name} の出力待ち...</p>
        </div>
      )}

      {/* Agent terminal output — left bubble with <pre> (B-1) */}
      {cleanOutput && (
        <div className="flex items-start gap-2 max-w-[90%]">
          <Avatar
            id={agent?.id ?? "anzu"}
            size="w-6 h-6 text-[9px]"
          />
          <div className="bg-slate-800 rounded-xl rounded-tl-sm px-3 py-2 min-w-0">
            <pre className="text-[11px] leading-[1.4] text-slate-300 font-mono whitespace-pre-wrap break-words max-h-[60vh] overflow-y-auto">
              {cleanOutput}
            </pre>
          </div>
        </div>
      )}

      {/* Interleaved user commands (right) and inbox messages (left) */}
      {timeline.map((entry, i) => {
        if (entry.kind === "user") {
          // User command → right bubble (B-1)
          return (
            <div key={`u-${i}`} className="flex justify-end">
              <div className="max-w-[75%] bg-sky-600 rounded-xl rounded-tr-sm px-3 py-1.5">
                <span className="text-[11px] text-white font-mono">
                  $ {entry.text}
                </span>
                <div className="text-[9px] text-sky-200 text-right mt-0.5">
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
                <span className="text-[10px] text-amber-300 font-medium">
                  {entry.from}から連絡
                </span>
                <p className="text-[11px] text-slate-300 mt-0.5">
                  {entry.text}
                </p>
                <div className="text-[9px] text-amber-400/60 text-right mt-0.5">
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
