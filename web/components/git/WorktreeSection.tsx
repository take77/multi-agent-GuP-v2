"use client";

// Worktree interface — hana が types/git.ts に追加中。マージ後は import に切り替え可能
interface Worktree {
  path: string;
  branch: string;
  head: string;
  squad: string | null;
  squadColor: string | null;
  member: string | null;
  taskId: string | null;
  taskDescription: string | null;
}

export interface WorktreeSectionProps {
  worktrees: Worktree[];
}

function lastTwoSegments(path: string): string {
  const parts = path.replace(/\\/g, "/").split("/").filter(Boolean);
  return parts.slice(-2).join("/");
}

function truncate(text: string, max = 50): string {
  return text.length <= max ? text : text.slice(0, max - 1) + "…";
}

export default function WorktreeSection({ worktrees }: WorktreeSectionProps) {
  return (
    <div className="px-3 py-2 border-b border-slate-800/50">
      {/* Section header */}
      <div className="flex items-center gap-2 mb-2">
        <span className="text-[11px] text-slate-300 font-medium">🌲 Worktree</span>
        <span className="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700/50">
          {worktrees.length}
        </span>
      </div>

      {worktrees.length === 0 ? (
        <p className="text-[11px] text-slate-600 italic py-1">
          アクティブなworktreeはありません
        </p>
      ) : (
        <div className="flex flex-col gap-1.5">
          {worktrees.map((wt, i) => (
            <div
              key={i}
              className="rounded-lg border border-slate-700/50 bg-slate-900/40 px-3 py-2"
            >
              <div className="flex items-center gap-2 flex-wrap mb-1">
                {/* Branch name */}
                <span className="text-[11px] font-mono text-cyan-300">{wt.branch}</span>

                {/* Squad badge */}
                <span
                  className="text-[9px] px-1.5 py-0.5 rounded border"
                  style={
                    wt.squadColor
                      ? {
                          color: wt.squadColor,
                          borderColor: `${wt.squadColor}40`,
                          background: `${wt.squadColor}12`,
                        }
                      : {
                          color: "#94a3b8",
                          borderColor: "#334155",
                          background: "transparent",
                        }
                  }
                >
                  {wt.squad ?? "—"}
                </span>

                {/* Task ID badge */}
                {wt.taskId && (
                  <span className="text-[9px] px-1.5 py-0.5 rounded bg-slate-800 text-slate-400 border border-slate-700/50 font-mono">
                    {wt.taskId}
                  </span>
                )}

                {/* Member name */}
                {wt.member && (
                  <span className="text-[10px] text-slate-500 ml-auto">{wt.member}</span>
                )}
              </div>

              {/* Task description */}
              {wt.taskDescription && (
                <p className="text-[10px] text-slate-400 truncate mb-1">
                  {truncate(wt.taskDescription)}
                </p>
              )}

              {/* Path */}
              <p className="text-[9px] text-slate-600 font-mono">
                …/{lastTwoSegments(wt.path)}
              </p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
