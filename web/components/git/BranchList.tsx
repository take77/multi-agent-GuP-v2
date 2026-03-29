"use client";

import type { Branch, BranchType } from "@/types/git";

const ROW_HEIGHT = 58;
const TYPE_LABELS: Record<BranchType, string> = {
  protected: "保護",
  integration: "統合",
  feature: "機能",
};

interface BranchListProps {
  flat: Branch[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}

export default function BranchList({ flat, selectedId, onSelect }: BranchListProps) {
  return (
    <div className="flex-1 min-w-0">
      {flat.map((b) => {
        const isSelected = selectedId === b.id;
        const typeBorder =
          b.type === "protected"
            ? "border-slate-600 text-slate-400"
            : b.type === "integration"
              ? "border-cyan-700 text-cyan-400"
              : "border-slate-700 text-slate-500";

        return (
          <button
            key={b.id}
            onClick={() => onSelect(b.id)}
            style={{ height: ROW_HEIGHT }}
            className={`w-full flex items-center px-3 text-left border-b border-slate-800/50 transition-colors ${
              isSelected ? "bg-slate-800" : "hover:bg-slate-900"
            }`}
          >
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 mb-0.5 flex-wrap">
                <span className="text-[12px] font-mono text-slate-200">{b.name}</span>
                <span className={`text-[9px] px-1.5 py-0.5 rounded border ${typeBorder}`}>
                  {TYPE_LABELS[b.type]}
                </span>
                {b.squad && (
                  <span
                    className="text-[10px] px-1.5 py-0.5 rounded border"
                    style={{
                      color: b.squadColor ?? undefined,
                      borderColor: b.squadColor ? `${b.squadColor}40` : undefined,
                      background: b.squadColor ? `${b.squadColor}12` : undefined,
                    }}
                  >
                    {b.squad}
                  </span>
                )}
                {b.conflict?.length && (
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-900/50 text-red-300 border border-red-700/50 animate-pulse">
                    CONFLICT
                  </span>
                )}
                {b.stale && (
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-900/50 text-amber-300 border border-amber-700/50">
                    STALE
                  </span>
                )}
              </div>
              <div className="flex items-center gap-3">
                <span className="text-[11px] text-slate-500 truncate">{b.commit}</span>
                <span className="text-[10px] text-slate-600">{b.time}</span>
                <div className="flex items-center gap-2 ml-auto shrink-0">
                  {b.ahead > 0 && (
                    <span className="text-[10px] text-emerald-400">↑{b.ahead}</span>
                  )}
                  {b.behind > 0 && (
                    <span className="text-[10px] text-red-400">↓{b.behind}</span>
                  )}
                </div>
              </div>
            </div>
          </button>
        );
      })}
    </div>
  );
}
