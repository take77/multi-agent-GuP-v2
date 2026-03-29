"use client";

import { useEffect, useRef, useMemo, useState } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";
import { parseCapturePaneOutput } from "@/lib/capture-pane-parser";
import { segmentsToBlocks } from "@/lib/segment-to-block";
import { BlockRenderer } from "@/components/chat/BlockRenderer";
import { getAgentDisplayName } from "@/lib/agent-names";

type TabId = "conversation" | "inbox";

export function MessageList() {
  const {
    selectedAgent,
    latestOutput,
    clusters,
    inboxMessages,
  } = useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);
  const [activeTab, setActiveTab] = useState<TabId>("conversation");

  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const output = latestOutput[selectedAgent] ?? "";

  const inboxEntries = useMemo(() => {
    return inboxMessages
      .filter((m) => m.to === selectedAgent || m.from === selectedAgent)
      .map((m) => {
        const t = new Date(m.timestamp);
        const timeStr = t.toLocaleTimeString("ja-JP", {
          hour: "2-digit",
          minute: "2-digit",
        });
        return {
          kind: "inbox" as const,
          time: timeStr,
          sortKey: t.getTime(),
          text: m.content,
          from: m.from,
          to: m.to,
        };
      });
  }, [inboxMessages, selectedAgent]);

  const agentDisplayName = agent?.name ?? getAgentDisplayName(selectedAgent);

  const parsedBlocks = useMemo(() => {
    const segments = parseCapturePaneOutput(output);
    return segmentsToBlocks(segments, agentDisplayName);
  }, [output, agentDisplayName]);

  // Auto-scroll when new entries arrive or output changes
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [
    activeTab,
    inboxEntries.length,
    parsedBlocks.length,
    output,
    selectedAgent,
  ]);

  const inboxCount = inboxEntries.length;

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Tab bar */}
      <div className="flex border-b border-slate-700/60 px-3 shrink-0">
        <button
          onClick={() => setActiveTab("conversation")}
          className={`px-3 py-1.5 text-[12px] font-medium transition-colors cursor-pointer ${
            activeTab === "conversation"
              ? "text-slate-200 border-b-2 border-sky-500"
              : "text-slate-500 hover:text-slate-300"
          }`}
        >
          会話
        </button>
        <button
          onClick={() => setActiveTab("inbox")}
          className={`px-3 py-1.5 text-[12px] font-medium transition-colors cursor-pointer flex items-center gap-1.5 ${
            activeTab === "inbox"
              ? "text-slate-200 border-b-2 border-amber-500"
              : "text-slate-500 hover:text-slate-300"
          }`}
        >
          連絡
          {inboxCount > 0 && (
            <span className="bg-amber-600 text-white text-[10px] font-bold rounded-full min-w-[18px] h-[18px] flex items-center justify-center px-1">
              {inboxCount}
            </span>
          )}
        </button>
      </div>

      {/* Tab content */}
      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-2">
        {activeTab === "conversation" && (
          <>
            {/* No output placeholder */}
            {parsedBlocks.length === 0 && (
              <div className="flex flex-col items-center justify-center flex-1 text-slate-600">
                <Avatar
                  id={agent?.id ?? "anzu"}
                  size="w-12 h-12 text-[18px]"
                />
                <p className="text-[12px] mt-3">
                  {agent?.name} の出力待ち...
                </p>
              </div>
            )}

            {/* Agent terminal output — block-based rendered view */}
            {/* User input is rendered inline by BlockRenderer (UserInputBubble) */}
            {parsedBlocks.length > 0 && (
              <BlockRenderer
                blocks={parsedBlocks}
                agentId={agent?.id ?? selectedAgent}
                agentName={agentDisplayName}
              />
            )}
          </>
        )}

        {activeTab === "inbox" && (
          <>
            {inboxEntries.length === 0 && (
              <div className="flex flex-col items-center justify-center flex-1 text-slate-600">
                <p className="text-[12px]">📩 連絡はまだありません</p>
              </div>
            )}

            {inboxEntries.map((entry, i) => {
              const isSent = entry.from === selectedAgent;
              return isSent ? (
                // 送信メッセージ → 右側
                <div key={`inbox-${i}`} className="flex justify-end">
                  <div className="max-w-[85%] bg-slate-700/60 border border-slate-600/40 rounded-xl rounded-tr-sm px-3 py-1.5">
                    <span className="text-[12px] text-slate-400 font-medium">
                      📤{" "}
                      {entry.to
                        ? getAgentDisplayName(entry.to)
                        : "不明"}
                      への連絡
                    </span>
                    <p className="text-[13px] text-slate-300 mt-0.5">
                      {entry.text}
                    </p>
                    <div className="text-[11px] text-slate-500 text-right mt-0.5">
                      {entry.time}
                    </div>
                  </div>
                </div>
              ) : (
                // 受信メッセージ → 左側
                <div
                  key={`inbox-${i}`}
                  className="flex items-start gap-2 max-w-[85%]"
                >
                  <div className="w-6 h-6 rounded-full bg-amber-600/30 flex items-center justify-center text-[12px] shrink-0">
                    📩
                  </div>
                  <div className="bg-amber-900/30 border border-amber-700/40 rounded-xl rounded-tl-sm px-3 py-1.5">
                    <span className="text-[12px] text-amber-300 font-medium">
                      {entry.from
                        ? getAgentDisplayName(entry.from)
                        : "不明"}
                      から連絡
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
            })}
          </>
        )}

        <div ref={bottomRef} />
      </div>
    </div>
  );
}
