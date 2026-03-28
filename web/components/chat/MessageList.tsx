"use client";

import { useEffect, useRef } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";

export function MessageList() {
  const { selectedAgent, messages, latestOutput, clusters } = useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);
  const outputRef = useRef<HTMLPreElement>(null);
  const userMsgs = messages[selectedAgent] ?? [];
  const output = latestOutput[selectedAgent] ?? "";
  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  // Auto-scroll terminal output to bottom on update
  useEffect(() => {
    if (outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [output]);

  // Scroll to bottom when switching agents
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [selectedAgent]);

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Terminal output area — latest capture-pane snapshot */}
      <div className="flex-1 overflow-hidden flex flex-col min-h-0">
        {!output && (
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
        {output && (
          <pre
            ref={outputRef}
            className="flex-1 overflow-y-auto px-3 py-2 text-[11px] leading-[1.4] text-slate-300 font-mono bg-slate-950 whitespace-pre-wrap break-words"
          >
            {output}
          </pre>
        )}
      </div>

      {/* User command history — compact bar at bottom */}
      {userMsgs.length > 0 && (
        <div className="border-t border-slate-700/50 bg-slate-900/50 px-3 py-1.5 max-h-24 overflow-y-auto">
          <div className="space-y-1">
            {userMsgs.map((m, i) => (
              <div key={i} className="flex items-center gap-2 text-[10px]">
                <span className="text-slate-600">{m.time}</span>
                <span className="text-sky-400 font-mono">$ {m.text}</span>
              </div>
            ))}
          </div>
        </div>
      )}
      <div ref={bottomRef} />
    </div>
  );
}
