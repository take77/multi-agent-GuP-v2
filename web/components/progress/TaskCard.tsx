"use client";

import type { Task, TaskPriority } from "@/types/progress";
import { Avatar } from "@/components/shared/Avatar";

const PRIORITY_STYLES: Record<TaskPriority, { bg: string; text: string }> = {
  HIGH: { bg: "bg-red-500/20", text: "text-red-400" },
  MEDIUM: { bg: "bg-amber-500/20", text: "text-amber-400" },
  LOW: { bg: "bg-emerald-500/20", text: "text-emerald-400" },
};

const SQUAD_COLORS: Record<string, string> = {
  darjeeling: "#3b82f6",
  katyusha: "#ef4444",
  kay: "#22c55e",
  maho: "#a855f7",
  command: "#f59e0b",
};

const STATUS_DOT: Record<string, string> = {
  in_progress: "bg-blue-400 animate-pulse",
  done: "bg-emerald-400",
  failed: "bg-red-500",
  blocked: "bg-orange-500",
  assigned: "bg-slate-400",
  idle: "bg-slate-600",
};

export function TaskCard({ task }: { task: Task }) {
  const priority = PRIORITY_STYLES[task.priority] ?? PRIORITY_STYLES.MEDIUM;
  const squadColor = SQUAD_COLORS[task.squad] ?? "#64748b";

  return (
    <div className="rounded-lg bg-slate-800/80 border border-slate-700/50 p-3 space-y-2">
      {/* Header: status dot + task ID + priority badge */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          <span
            className={`w-2 h-2 rounded-full shrink-0 ${STATUS_DOT[task.status] ?? "bg-slate-600"}`}
          />
          <span className="text-[11px] font-mono text-slate-400 truncate">
            {task.task_id}
          </span>
        </div>
        <span
          className={`text-[10px] font-medium px-1.5 py-0.5 rounded ${priority.bg} ${priority.text} shrink-0`}
        >
          {task.priority}
        </span>
      </div>

      {/* Description */}
      <p className="text-xs text-slate-300 line-clamp-2 leading-relaxed">
        {task.description}
      </p>

      {/* Footer: assignee + squad */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-1.5">
          <Avatar id={task.assignee} size="w-6 h-6 text-[10px]" />
          <span className="text-xs text-slate-400">{task.assignee}</span>
        </div>
        <span
          className="text-[10px] px-1.5 py-0.5 rounded-full border"
          style={{
            color: squadColor,
            borderColor: `${squadColor}40`,
            background: `${squadColor}10`,
          }}
        >
          {task.squad}
        </span>
      </div>

      {/* Progress bar for in_progress tasks */}
      {task.status === "in_progress" && (
        <div className="w-full h-1 bg-slate-700 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full bg-blue-500 animate-pulse"
            style={{ width: "60%" }}
          />
        </div>
      )}
    </div>
  );
}
