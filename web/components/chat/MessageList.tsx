"use client";

import { useEffect, useRef } from "react";
import { useAppStore } from "@/lib/store";
import { Avatar } from "@/components/shared/Avatar";

export function MessageList() {
  const { selectedAgent, messages, clusters } = useAppStore();
  const bottomRef = useRef<HTMLDivElement>(null);
  const msgs = messages[selectedAgent] ?? [];
  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [selectedAgent, msgs.length]);

  return (
    <div className="flex-1 overflow-y-auto px-3 py-3 space-y-3">
      {msgs.length === 0 && (
        <div className="flex flex-col items-center justify-center h-full text-slate-600">
          <Avatar
            id={agent?.id ?? "anzu"}
            size="w-12 h-12 text-[18px]"
          />
          <p className="text-[12px] mt-3">
            {agent?.name} とのチャット履歴なし
          </p>
        </div>
      )}
      {msgs.map((m, i) => (
        <div
          key={i}
          className={`flex gap-2 ${m.role === "user" ? "flex-row-reverse" : ""}`}
        >
          {m.role !== "user" && (
            <Avatar id={selectedAgent} size="w-6 h-6 text-[10px]" />
          )}
          <div
            className={`rounded-xl px-3 py-2 ${
              m.role === "user"
                ? "bg-sky-900/60 border border-sky-700/40 max-w-[80%]"
                : "bg-slate-800 border border-slate-700/50 max-w-[85%]"
            }`}
          >
            <p className="text-[12px] text-slate-200 leading-relaxed whitespace-pre-line break-words">
              {m.text}
            </p>
            <span className="text-[10px] text-slate-600 mt-1 block text-right">
              {m.time}
            </span>
          </div>
        </div>
      ))}
      <div ref={bottomRef} />
    </div>
  );
}
