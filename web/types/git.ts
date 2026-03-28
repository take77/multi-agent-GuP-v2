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
}
