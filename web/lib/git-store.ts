import { create } from "zustand";
import type { Branch, Repository, Worktree } from "@/types/git";

interface GitState {
  repositories: Repository[];
  setRepositories: (repos: Repository[]) => void;

  selectedRepoId: string | null;
  setSelectedRepoId: (id: string) => void;

  branches: Branch[];
  setBranches: (branches: Branch[]) => void;

  selectedBranchId: string | null;
  setSelectedBranchId: (id: string | null) => void;

  conflicts: Record<string, string[]>; // repoId -> conflicting files
  setConflicts: (repoId: string, files: string[]) => void;

  loading: boolean;
  setLoading: (v: boolean) => void;

  worktrees: Worktree[];
  setWorktrees: (wt: Worktree[]) => void;
}

export const useGitStore = create<GitState>((set) => ({
  repositories: [],
  setRepositories: (repos) => set({ repositories: repos }),

  selectedRepoId: null,
  setSelectedRepoId: (id) => set({ selectedRepoId: id, selectedBranchId: null }),

  branches: [],
  setBranches: (branches) => set({ branches }),

  selectedBranchId: null,
  setSelectedBranchId: (id) =>
    set((s) => ({ selectedBranchId: s.selectedBranchId === id ? null : id })),

  conflicts: {},
  setConflicts: (repoId, files) =>
    set((s) => ({ conflicts: { ...s.conflicts, [repoId]: files } })),

  loading: false,
  setLoading: (v) => set({ loading: v }),

  worktrees: [],
  setWorktrees: (wt) => set({ worktrees: wt }),
}));
