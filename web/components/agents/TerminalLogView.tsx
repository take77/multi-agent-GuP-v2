"use client";

import { useEffect, useRef } from "react";
import { useAppStore } from "@/lib/store";

export function TerminalLogView({ agentId }: { agentId: string }) {
  const output = useAppStore((s) => s.latestOutput[agentId] ?? "");
  const scrollRef = useRef<HTMLPreElement>(null);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    // Auto-scroll only if already near bottom
    const nearBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
    if (nearBottom) {
      el.scrollTop = el.scrollHeight;
    }
  }, [output]);

  return (
    <pre
      ref={scrollRef}
      className="flex-1 bg-black font-mono text-[12px] leading-[1.7] p-4 overflow-y-auto text-emerald-400 whitespace-pre-wrap break-words"
    >
      {output || (
        <span className="text-slate-600">待機中...</span>
      )}
    </pre>
  );
}
