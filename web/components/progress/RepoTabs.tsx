"use client";

import type { ProjectInfo } from "@/types/progress";

export function RepoTabs({
  projects,
  selected,
  onSelect,
}: {
  projects: ProjectInfo[];
  selected: string | null;
  onSelect: (id: string | null) => void;
}) {
  return (
    <div className="flex items-center gap-1 overflow-x-auto pb-1 scrollbar-thin">
      <button
        onClick={() => onSelect(null)}
        className={`shrink-0 px-3 py-1.5 rounded-md text-xs transition-colors ${
          selected === null
            ? "bg-slate-700 text-slate-200 font-medium"
            : "text-slate-400 hover:text-slate-300 hover:bg-slate-800/60"
        }`}
      >
        全リポ
      </button>
      {projects.map((p) => (
        <button
          key={p.id}
          onClick={() => onSelect(p.id)}
          className={`shrink-0 px-3 py-1.5 rounded-md text-xs transition-colors ${
            selected === p.id
              ? "bg-slate-700 text-slate-200 font-medium"
              : "text-slate-400 hover:text-slate-300 hover:bg-slate-800/60"
          }`}
        >
          {p.name}
        </button>
      ))}
    </div>
  );
}
