"use client";

import type { MergeEntry } from "@/types/git";

interface MergeHistoryProps {
  entries: MergeEntry[];
}

export default function MergeHistory({ entries }: MergeHistoryProps) {
  if (entries.length === 0) return null;

  return (
    <div className="border-t border-slate-800/50 px-3 py-2">
      <div className="text-[10px] text-slate-600 mb-1.5">── マージ履歴 ──</div>
      <div className="space-y-1">
        {entries.map((e, i) => (
          <div key={i} className="flex items-center gap-2 text-[11px]">
            <span className="text-emerald-400">✓</span>
            <span className="text-slate-400">
              <span className="font-mono">{e.from}</span>
              <span className="text-slate-600 mx-1">→</span>
              <span className="font-mono">{e.to}</span>
            </span>
            {e.tag && (
              <span className="text-[9px] px-1 py-0.5 rounded border border-slate-700 text-slate-500">
                {e.tag}
              </span>
            )}
            <span className="text-[10px] text-slate-600 ml-auto">{e.time}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
