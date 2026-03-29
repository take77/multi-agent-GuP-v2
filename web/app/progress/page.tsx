"use client";

import { useEffect, useCallback } from "react";
import {
  useProgressStore,
  getFilteredTasks,
  getSummary,
  getSquadProgress,
  getKanbanTasks,
} from "@/lib/progress-store";
import type { Task, ProjectInfo } from "@/types/progress";
import { SummaryCards } from "@/components/progress/SummaryCards";
import { SquadProgressBar } from "@/components/progress/SquadProgressBar";
import { KanbanBoard } from "@/components/progress/KanbanBoard";
import { RepoTabs } from "@/components/progress/RepoTabs";

const POLL_INTERVAL = 5000;

export default function ProgressPage() {
  const store = useProgressStore();
  const { setTasks, setProjects, selectedProject, setSelectedProject } = store;

  const fetchTasks = useCallback(async () => {
    try {
      const res = await fetch("/api/tasks");
      if (!res.ok) return;
      const data = (await res.json()) as {
        tasks: Task[];
        projects: ProjectInfo[];
      };
      setTasks(data.tasks);
      setProjects(data.projects);
    } catch {
      // silent retry on next interval
    }
  }, [setTasks, setProjects]);

  useEffect(() => {
    fetchTasks();
    const id = setInterval(fetchTasks, POLL_INTERVAL);
    return () => clearInterval(id);
  }, [fetchTasks]);

  const filtered = getFilteredTasks(store);
  const summary = getSummary(filtered);
  const squads = getSquadProgress(filtered);
  const kanban = getKanbanTasks(filtered);

  return (
    <div className="h-full overflow-y-auto p-4 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-base font-semibold text-slate-200">
          進捗ビュー
        </h1>
        <span className="text-[11px] text-slate-500">
          {store.tasks.length} タスク検出
        </span>
      </div>

      {/* Repo Tabs */}
      <RepoTabs
        projects={store.projects}
        selected={selectedProject}
        onSelect={setSelectedProject}
      />

      {/* Summary Cards */}
      <SummaryCards summary={summary} />

      {/* Squad Progress */}
      <SquadProgressBar squads={squads} />

      {/* Kanban Board */}
      <KanbanBoard columns={kanban} />
    </div>
  );
}
