"use client";

import { useEffect, useState, useCallback } from "react";
import type { UsageData, CodexUsageData, CodexStatus } from "@/types/agent";

type Tab = "claude" | "codex";

function formatTimeRemaining(isoTimestamp: string): string {
  if (!isoTimestamp || isoTimestamp === "N/A" || isoTimestamp === "0") {
    return "N/A";
  }
  try {
    const resetMs = new Date(isoTimestamp).getTime();
    const nowMs = Date.now();
    const diffMs = resetMs - nowMs;
    if (diffMs <= 0) return "まもなく";

    const hours = Math.floor(diffMs / (1000 * 60 * 60));
    const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

    if (hours >= 24) {
      const days = Math.floor(hours / 24);
      const remHours = hours % 24;
      return `${days}日 ${remHours}h`;
    }
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  } catch {
    return "N/A";
  }
}

function getBarGradient(
  pct: number,
  defaultGradient: string
): string {
  if (pct >= 95) return "from-red-500 to-red-600";
  if (pct >= 80) return "from-orange-500 to-orange-600";
  return defaultGradient;
}

function getTextColor(pct: number, defaultColor: string): string {
  if (pct >= 95) return "text-red-400";
  if (pct >= 80) return "text-orange-400";
  return defaultColor;
}

const STATUS_BADGE: Record<CodexStatus, { bg: string; text: string; label: string }> = {
  available: { bg: "bg-emerald-900/40 border-emerald-700/40", text: "text-emerald-300", label: "Available" },
  rate_limited: { bg: "bg-yellow-900/40 border-yellow-700/40", text: "text-yellow-300", label: "Rate Limited" },
  error: { bg: "bg-red-900/40 border-red-700/40", text: "text-red-300", label: "Error" },
};

const STATUS_DOT: Record<CodexStatus, string> = {
  available: "bg-emerald-400",
  rate_limited: "bg-yellow-400",
  error: "bg-red-400",
};

function CodexTab({ codex }: { codex: CodexUsageData }) {
  const badge = STATUS_BADGE[codex.status];
  const dot = STATUS_DOT[codex.status];
  const usagePct = codex.estimated_remaining != null
    ? Math.round(((30 - codex.estimated_remaining) / 30) * 100)
    : 0;

  return (
    <div className="space-y-1.5">
      {/* Status badge */}
      <div className={`flex items-center gap-1.5 px-2 py-0.5 rounded border ${badge.bg}`}>
        <span className={`w-1.5 h-1.5 rounded-full ${dot} ${codex.status !== "available" ? "animate-pulse" : ""}`} />
        <span className={`text-[10px] ${badge.text}`}>{badge.label}</span>
      </div>

      {/* Today's reviews */}
      <div>
        <div className="flex items-center justify-between mb-0.5">
          <span className="text-[10px] text-slate-500">本日 review</span>
          <span className="text-[10px] font-mono text-slate-400">
            {codex.total_reviews_today}回
          </span>
        </div>
        <div className="flex items-center gap-2 text-[9px]">
          <span className="text-emerald-400">PASS {codex.pass_count}</span>
          <span className="text-red-400">FAIL {codex.fail_count}</span>
        </div>
      </div>

      {/* Usage bar */}
      <div>
        <div className="flex items-center justify-between mb-0.5">
          <span className="text-[10px] text-slate-500">使用量(推定)</span>
          <span className={`text-[10px] font-mono ${getTextColor(usagePct, "text-teal-400")}`}>
            {usagePct}%
          </span>
        </div>
        <div className="w-full h-1 bg-slate-800 rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full bg-gradient-to-r ${getBarGradient(usagePct, "from-teal-500 to-cyan-500")} transition-all duration-500`}
            style={{ width: `${Math.min(usagePct, 100)}%` }}
          />
        </div>
        <div className="flex items-center justify-between mt-0.5">
          <span className="text-[9px] text-slate-600">残り推定</span>
          <span className="text-[9px] font-mono text-teal-400">
            {codex.estimated_remaining ?? "N/A"}回
          </span>
        </div>
      </div>

      {/* Cooldown (only when rate limited) */}
      {codex.status === "rate_limited" && codex.cooldown_until && (
        <div className="pt-1 border-t border-slate-800">
          <div className="flex items-center justify-between">
            <span className="text-[10px] text-yellow-500">Cooldown</span>
            <span className="text-[9px] font-mono text-yellow-400">
              {formatTimeRemaining(codex.cooldown_until)}
            </span>
          </div>
          <div className="text-[9px] text-yellow-600 mt-0.5">
            Claude-only fallback 中
          </div>
        </div>
      )}

      {codex.status === "error" && (
        <div className="pt-1 border-t border-slate-800">
          <div className="text-[9px] text-red-500">Codex 接続エラー</div>
        </div>
      )}
    </div>
  );
}

export function UsagePanel() {
  const [usage, setUsage] = useState<UsageData | null>(null);
  const [tab, setTab] = useState<Tab>("claude");

  const fetchData = useCallback(async () => {
    try {
      const res = await fetch("/api/usage");
      if (res.ok) {
        const data = (await res.json()) as UsageData;
        setUsage(data);
      }
    } catch {
      // Silently fail — keep existing data
    }
  }, []);

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 300_000); // poll every 5 min
    return () => clearInterval(interval);
  }, [fetchData]);

  const fiveHour = usage?.five_hour ?? { utilization: 0, resets_at: "N/A" };
  const sevenDay = usage?.seven_day ?? { utilization: 0, resets_at: "N/A" };
  const hasCodex = usage?.codex != null;

  return (
    <div className="px-2.5 py-2 border-t border-slate-700/50">
      {/* Tab switcher */}
      <div className="flex items-center gap-1 mb-1.5">
        <button
          onClick={() => setTab("claude")}
          className={`text-[10px] px-1.5 py-0.5 rounded transition-colors ${
            tab === "claude"
              ? "bg-slate-700 text-slate-300"
              : "text-slate-600 hover:text-slate-400"
          }`}
        >
          Claude
        </button>
        <button
          onClick={() => setTab("codex")}
          className={`text-[10px] px-1.5 py-0.5 rounded transition-colors ${
            tab === "codex"
              ? "bg-slate-700 text-slate-300"
              : "text-slate-600 hover:text-slate-400"
          }`}
        >
          Codex
        </button>
      </div>

      {tab === "claude" ? (
        <div className="space-y-1.5">
          {/* 5-hour window */}
          <div>
            <div className="flex items-center justify-between mb-0.5">
              <span className="text-[10px] text-slate-500">5時間枠</span>
              <span
                className={`text-[10px] font-mono ${getTextColor(fiveHour.utilization, "text-slate-400")}`}
              >
                {fiveHour.utilization}%
              </span>
            </div>
            <div className="w-full h-1 bg-slate-800 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full bg-gradient-to-r ${getBarGradient(fiveHour.utilization, "from-sky-500 to-violet-500")} transition-all duration-500`}
                style={{ width: `${Math.min(fiveHour.utilization, 100)}%` }}
              />
            </div>
            <div className="flex items-center justify-between mt-0.5">
              <span className="text-[9px] text-slate-600">リセット</span>
              <span
                className={`text-[9px] font-mono ${getTextColor(fiveHour.utilization, "text-sky-400")}`}
              >
                {formatTimeRemaining(fiveHour.resets_at)}
              </span>
            </div>
          </div>

          {/* 7-day window */}
          <div>
            <div className="flex items-center justify-between mb-0.5">
              <span className="text-[10px] text-slate-500">週間枠</span>
              <span
                className={`text-[10px] font-mono ${getTextColor(sevenDay.utilization, "text-amber-300")}`}
              >
                {sevenDay.utilization}%
              </span>
            </div>
            <div className="w-full h-1 bg-slate-800 rounded-full overflow-hidden">
              <div
                className={`h-full rounded-full bg-gradient-to-r ${getBarGradient(sevenDay.utilization, "from-amber-500 to-orange-500")} transition-all duration-500`}
                style={{ width: `${Math.min(sevenDay.utilization, 100)}%` }}
              />
            </div>
            <div className="flex items-center justify-between mt-0.5">
              <span className="text-[9px] text-slate-600">リセット</span>
              <span
                className={`text-[9px] font-mono ${getTextColor(sevenDay.utilization, "text-amber-400")}`}
              >
                {formatTimeRemaining(sevenDay.resets_at)}
              </span>
            </div>
          </div>

          {/* Session cost stub */}
          <div className="pt-1 border-t border-slate-800">
            <div className="flex items-center justify-between">
              <span className="text-[10px] text-slate-500">今セッション</span>
              <span className="text-[9px] text-slate-600 italic">Coming Soon</span>
            </div>
          </div>
        </div>
      ) : hasCodex ? (
        <CodexTab codex={usage!.codex!} />
      ) : (
        <div className="text-[10px] text-slate-600 py-2">
          Codex 未導入
        </div>
      )}
    </div>
  );
}
