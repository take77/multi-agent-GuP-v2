"use client";

import { useEffect, useState } from "react";
import { useAppStore } from "@/lib/store";
import type { UsageData } from "@/types/agent";

const STUCK_THRESHOLD = 5;
const USAGE_WARNING_PCT = 80;
const USAGE_POLL_MS = 60_000;

const VIEW_LABELS: Record<string, string> = {
  chat: "チャット",
  agents: "状態",
  git: "Git",
  progress: "進捗",
};

function getAuthToken(): string {
  if (typeof document === "undefined") return "";
  return (
    document.cookie
      .split("; ")
      .find((c) => c.startsWith("auth_token="))
      ?.split("=")[1] ?? ""
  );
}

export function Header() {
  const { view, clusters } = useAppStore();
  const allAgents = clusters.flatMap((c) => c.agents);
  const activeCount = allAgents.filter((a) => a.status === "active").length;
  const stuckCount = allAgents.filter(
    (a) => a.stuck >= STUCK_THRESHOLD
  ).length;

  const [usageWarning, setUsageWarning] = useState(false);
  const [usagePct, setUsagePct] = useState(0);
  const [codexLimited, setCodexLimited] = useState(false);

  useEffect(() => {
    let mounted = true;

    async function checkUsage() {
      try {
        const token = getAuthToken();
        const res = await fetch("/api/usage", {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        });
        if (!res.ok) return;
        const data = (await res.json()) as UsageData;
        if (!mounted) return;
        const maxPct = Math.max(
          data.five_hour.utilization,
          data.seven_day.utilization
        );
        setUsagePct(maxPct);
        setUsageWarning(maxPct >= USAGE_WARNING_PCT);
        setCodexLimited(
          data.codex?.status === "rate_limited" ||
          data.codex?.status === "error"
        );
      } catch {
        // Non-fatal
      }
    }

    checkUsage();
    const interval = setInterval(checkUsage, USAGE_POLL_MS);
    return () => {
      mounted = false;
      clearInterval(interval);
    };
  }, []);

  return (
    <header className="h-11 flex items-center justify-between px-4 border-b border-slate-700/50 bg-slate-900/50 shrink-0">
      <h1 className="text-sm font-medium text-slate-400">
        {VIEW_LABELS[view] ?? view}
      </h1>
      <div className="flex items-center gap-3">
        {codexLimited && (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-amber-900/40 border border-amber-700/40">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
            <span className="text-[10px] text-amber-300">
              Codex limited
            </span>
          </div>
        )}
        {usageWarning && (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-red-900/40 border border-red-700/40">
            <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
            <span className="text-[10px] text-red-300">
              Usage {usagePct}%
            </span>
          </div>
        )}
        {stuckCount > 0 && (
          <div className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-orange-900/40 border border-orange-700/40">
            <span className="w-1.5 h-1.5 rounded-full bg-orange-500 animate-pulse" />
            <span className="text-[10px] text-orange-300">
              {stuckCount} stuck
            </span>
          </div>
        )}
        <div className="flex items-center gap-1.5 text-[11px] text-slate-500">
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400" />
          {activeCount} agents
        </div>
      </div>
    </header>
  );
}
