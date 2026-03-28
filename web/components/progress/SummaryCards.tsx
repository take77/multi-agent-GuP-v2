"use client";

import type { ProgressSummary } from "@/types/progress";

const CARDS: {
  key: keyof ProgressSummary;
  label: string;
  icon: string;
  color: string;
}[] = [
  { key: "total", label: "全タスク", icon: "📋", color: "text-slate-200" },
  {
    key: "inProgress",
    label: "実行中",
    icon: "🔄",
    color: "text-blue-400",
  },
  {
    key: "completionRate",
    label: "完了率",
    icon: "✅",
    color: "text-emerald-400",
  },
  { key: "queued", label: "待機中", icon: "⏳", color: "text-amber-400" },
];

export function SummaryCards({ summary }: { summary: ProgressSummary }) {
  return (
    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
      {CARDS.map((card) => {
        const value = summary[card.key];
        return (
          <div
            key={card.key}
            className="flex items-center gap-3 rounded-lg bg-slate-800/60 border border-slate-700/50 px-4 py-3"
          >
            <span className="text-xl">{card.icon}</span>
            <div>
              <div className={`text-lg font-bold ${card.color}`}>
                {card.key === "completionRate" ? `${value}%` : value}
              </div>
              <div className="text-[11px] text-slate-500">{card.label}</div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
