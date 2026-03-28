"use client";

import type { AgentStatus } from "@/types/agent";

const STATUS_COLORS: Record<AgentStatus, string> = {
  active: "bg-emerald-400",
  idle: "bg-amber-400",
  error: "bg-red-500 animate-pulse",
  stuck: "bg-orange-500 animate-pulse",
};

export function StatusDot({
  status,
  stuck,
}: {
  status: AgentStatus;
  stuck?: number;
}) {
  const effectiveStatus = stuck && stuck >= 5 ? "stuck" : status;
  return (
    <span
      className={`inline-block w-2 h-2 rounded-full ${STATUS_COLORS[effectiveStatus]}`}
    />
  );
}
