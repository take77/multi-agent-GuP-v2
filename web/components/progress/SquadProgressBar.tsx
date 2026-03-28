"use client";

import type { SquadProgress } from "@/types/progress";

export function SquadProgressBar({ squads }: { squads: SquadProgress[] }) {
  if (squads.length === 0) return null;

  return (
    <div className="space-y-3">
      <h3 className="text-xs font-medium text-slate-400 uppercase tracking-wide">
        クラスター別進捗
      </h3>
      <div className="space-y-2">
        {squads.map((squad) => {
          const pct =
            squad.total > 0
              ? Math.round((squad.completed / squad.total) * 100)
              : 0;
          return (
            <div key={squad.id} className="flex items-center gap-3">
              <span
                className="w-2 h-2 rounded-full shrink-0"
                style={{ background: squad.color }}
              />
              <span className="text-xs text-slate-300 w-28 truncate">
                {squad.name}
              </span>
              <div className="flex-1 h-1.5 bg-slate-800 rounded-full overflow-hidden">
                <div
                  className="h-full rounded-full transition-all"
                  style={{ width: `${pct}%`, background: squad.color }}
                />
              </div>
              <span className="text-[11px] text-slate-500 w-14 text-right">
                {squad.completed}/{squad.total}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
