"use client";

import { useEffect, useCallback, useRef } from "react";
import { useGitStore } from "@/lib/git-store";
import type { Branch, Repository, MergeEntry } from "@/types/git";
import BranchTree from "@/components/git/BranchTree";
import BranchList from "@/components/git/BranchList";
import BranchDetail from "@/components/git/BranchDetail";
import MergeHistory from "@/components/git/MergeHistory";
import WorktreeSection from "@/components/git/WorktreeSection";

// Worktree type — hana が types/git.ts に追加中。マージ後は import { Worktree } from "@/types/git" に切り替え可能
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

// Build flat tree ordering (DFS)
function flattenTree(branches: Branch[]): Branch[] {
  const flat: Branch[] = [];
  const walk = (id: string | null) => {
    const node = branches.find((b) => b.id === id);
    if (!node) return;
    flat.push(node);
    branches.filter((b) => b.parent === id).forEach((child) => walk(child.id));
  };
  // Start from root (no parent)
  const roots = branches.filter((b) => !b.parent);
  roots.forEach((r) => walk(r.id));
  // Add orphans (branches whose parent isn't in the list)
  for (const b of branches) {
    if (!flat.includes(b)) flat.push(b);
  }
  return flat;
}

// Extract merge history from branch commits
function extractMergeHistory(branches: Branch[]): MergeEntry[] {
  const entries: MergeEntry[] = [];
  for (const b of branches) {
    const m = b.commit.match(/^Merge\s+(\S+)/i);
    if (m) {
      entries.push({ from: m[1], to: b.name, time: b.time });
    }
  }
  return entries;
}

export default function GitPage() {
  // worktrees/setWorktrees は hana が git-store.ts に追加中。マージ後に型エラーが解消される
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const store = useGitStore() as any;
  const repositories: Repository[] = store.repositories;
  const setRepositories: (repos: Repository[]) => void = store.setRepositories;
  const selectedRepoId: string | null = store.selectedRepoId;
  const setSelectedRepoId: (id: string) => void = store.setSelectedRepoId;
  const branches: Branch[] = store.branches;
  const setBranches: (branches: Branch[]) => void = store.setBranches;
  const selectedBranchId: string | null = store.selectedBranchId;
  const setSelectedBranchId: (id: string | null) => void = store.setSelectedBranchId;
  const loading: boolean = store.loading;
  const setLoading: (v: boolean) => void = store.setLoading;
  const worktrees: Worktree[] = store.worktrees ?? [];
  const setWorktrees: (wt: Worktree[]) => void = store.setWorktrees ?? (() => {});

  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const worktreeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchRepos = useCallback(async () => {
    try {
      const res = await fetch("/api/git/_repos/branches");
      const data = await res.json();
      if (data.repositories) {
        setRepositories(data.repositories);
        if (!selectedRepoId && data.repositories.length > 0) {
          setSelectedRepoId(data.repositories[0].id);
        }
      }
    } catch { /* */ }
  }, [setRepositories, setSelectedRepoId, selectedRepoId]);

  const fetchBranches = useCallback(async (repoId: string) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/git/${repoId}/branches`);
      const data = await res.json();
      if (data.branches) {
        setBranches(data.branches);
      }
    } catch { /* */ }
    setLoading(false);
  }, [setBranches, setLoading]);

  const fetchWorktrees = useCallback(async () => {
    try {
      const res = await fetch("/api/git/worktrees");
      const data = await res.json();
      if (data.worktrees) {
        setWorktrees(data.worktrees);
      }
    } catch { /* */ }
  }, [setWorktrees]);

  // Initial load
  useEffect(() => {
    fetchRepos();
  }, [fetchRepos]);

  // Fetch worktrees on mount + polling
  useEffect(() => {
    fetchWorktrees();
    worktreeIntervalRef.current = setInterval(fetchWorktrees, 5000);
    return () => {
      if (worktreeIntervalRef.current) clearInterval(worktreeIntervalRef.current);
    };
  }, [fetchWorktrees]);

  // Fetch branches on repo change + polling
  useEffect(() => {
    if (!selectedRepoId) return;
    fetchBranches(selectedRepoId);

    if (intervalRef.current) clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => {
      fetchBranches(selectedRepoId);
    }, 5000);

    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [selectedRepoId, fetchBranches]);

  const flat = flattenTree(branches);
  const selectedBranch = branches.find((b) => b.id === selectedBranchId);
  const mergeHistory = extractMergeHistory(branches);
  const featureCount = flat.filter((b) => b.type === "feature").length;
  const selectedRepo = repositories.find((r: Repository) => r.id === selectedRepoId);

  const handleSelect = (id: string) => {
    setSelectedBranchId(id);
  };

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Repo tabs */}
      <div className="flex items-center gap-2 px-3 py-2 border-b border-slate-700/50 bg-slate-900/30 overflow-x-auto">
        {repositories.map((r: Repository) => {
          const isActive = selectedRepoId === r.id;
          return (
            <button
              key={r.id}
              onClick={() => setSelectedRepoId(r.id)}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] border shrink-0 transition-colors ${
                isActive
                  ? "bg-slate-700 border-slate-600 text-white"
                  : "border-transparent text-slate-400 hover:text-slate-200 hover:bg-slate-800"
              }`}
            >
              <span className="font-mono">{r.name}</span>
            </button>
          );
        })}
        <div className="ml-auto flex items-center gap-2 text-[9px] text-slate-500 shrink-0">
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-slate-400" />
            保護
          </span>
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-cyan-400" />
            統合
          </span>
          <span className="flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-emerald-400" />
            作業中
          </span>
        </div>
      </div>

      {/* Repo info subheader */}
      {selectedRepo && (
        <div className="px-4 py-1.5 border-b border-slate-800/50 bg-slate-900/20 flex items-center gap-2">
          <span className="text-[11px] text-slate-500">{selectedRepo.desc}</span>
          <span className="text-[10px] text-slate-600">{selectedRepo.lang}</span>
          <span className="text-[10px] text-slate-600 ml-auto">
            {featureCount} ブランチ稼働中
          </span>
        </div>
      )}

      {/* Main content */}
      <div className="flex flex-1 overflow-hidden">
        {loading && flat.length === 0 ? (
          <div className="flex items-center justify-center flex-1 text-slate-500 text-[13px]">
            読み込み中...
          </div>
        ) : flat.length === 0 ? (
          <div className="flex items-center justify-center flex-1 text-slate-500 text-[13px]">
            ブランチが見つかりません
          </div>
        ) : (
          <div className="flex-1 overflow-y-auto">
            {/* Worktree section — ブランチツリーの上部に配置 */}
            <WorktreeSection worktrees={worktrees} />
            <div className="flex">
              <BranchTree
                branches={branches}
                flat={flat}
                selectedId={selectedBranchId}
                onSelect={handleSelect}
              />
              <BranchList
                flat={flat}
                selectedId={selectedBranchId}
                onSelect={handleSelect}
              />
            </div>
            <MergeHistory entries={mergeHistory} />
          </div>
        )}

        {/* Detail panel */}
        {selectedBranch && (
          <BranchDetail
            branch={selectedBranch}
            allBranches={branches}
            onClose={() => setSelectedBranchId(null)}
          />
        )}
      </div>
    </div>
  );
}
