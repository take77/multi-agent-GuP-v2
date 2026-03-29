export type BranchType = "protected" | "integration" | "feature";

export interface Branch {
  id: string;
  name: string;
  type: BranchType;
  parent: string | null;
  squad: string | null;
  squadColor: string | null;
  commit: string;
  time: string;
  ahead: number;
  behind: number;
  files?: [number, number, number]; // modified, added, deleted
  conflict?: string[];
  stale?: boolean;
}

export interface Repository {
  id: string;
  name: string;
  desc: string;
  lang: string;
  path: string;
}

export interface MergeEntry {
  from: string;
  to: string;
  time: string;
  tag?: string;
}

export interface Worktree {
  path: string;
  branch: string;
  head: string;
  squad: string | null;
  squadColor: string | null;
  member: string | null;
  taskId: string | null;
  taskDescription: string | null;
}
