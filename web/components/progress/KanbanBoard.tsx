"use client";

import type { Task, KanbanColumn } from "@/types/progress";
import { TaskCard } from "./TaskCard";

const COLUMNS: { key: KanbanColumn; label: string; color: string }[] = [
  { key: "queued", label: "待機中", color: "text-amber-400" },
  { key: "in_progress", label: "実行中", color: "text-blue-400" },
  { key: "completed", label: "完了", color: "text-emerald-400" },
];

export function KanbanBoard({
  columns,
}: {
  columns: Record<KanbanColumn, Task[]>;
}) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      {COLUMNS.map((col) => {
        const tasks = columns[col.key];
        return (
          <div key={col.key} className="space-y-2">
            {/* Column header */}
            <div className="flex items-center justify-between px-1">
              <h3 className={`text-xs font-medium ${col.color}`}>
                {col.label}
              </h3>
              <span className="text-[11px] text-slate-500 bg-slate-800 px-1.5 py-0.5 rounded">
                {tasks.length}
              </span>
            </div>

            {/* Task list */}
            <div className="space-y-2 min-h-[100px] rounded-lg bg-slate-900/40 border border-slate-800/50 p-2">
              {tasks.length === 0 ? (
                <div className="flex items-center justify-center h-20 text-[11px] text-slate-600">
                  タスクなし
                </div>
              ) : (
                tasks.map((task) => (
                  <TaskCard key={task.task_id} task={task} />
                ))
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
