"use client";

import { useEffect, useState, useCallback } from "react";
import type { UsageData } from "@/types/agent";

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

export function UsagePanel() {
  const [usage, setUsage] = useState<UsageData | null>(null);

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
    const interval = setInterval(fetchData, 60_000); // poll every 60s
    return () => clearInterval(interval);
  }, [fetchData]);

  const fiveHour = usage?.five_hour ?? { utilization: 0, resets_at: "N/A" };
  const sevenDay = usage?.seven_day ?? { utilization: 0, resets_at: "N/A" };

  return (
    <div className="px-2.5 py-2 border-t border-slate-700/50">
      <div className="text-[10px] text-slate-600 mb-1.5">Claude 使用量</div>
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
    </div>
  );
}
