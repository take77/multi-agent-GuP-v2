import { execFileSync } from "child_process";

const EXEC_OPTIONS = { encoding: "utf-8" as const, timeout: 10000 };

export interface BranchInfo {
  name: string;
  current: boolean;
  upstream: string | null;
}

export interface AheadBehind {
  ahead: number;
  behind: number;
}

export interface WorktreeInfo {
  path: string;
  head: string;
  branch: string;
}

/**
 * List all branches in a git repository.
 */
export function listBranches(repoPath: string): BranchInfo[] {
  try {
    const output = execFileSync(
      "git",
      ["-C", repoPath, "branch", "-vv", "--no-color"],
      EXEC_OPTIONS
    );
    return output
      .trim()
      .split("\n")
      .filter((line) => line.trim())
      .map((line) => {
        const current = line.startsWith("*");
        const trimmed = line.replace(/^\*?\s+/, "");
        const name = trimmed.split(/\s+/)[0];
        const upstreamMatch = trimmed.match(/\[([^\]]+)\]/);
        const upstream = upstreamMatch ? upstreamMatch[1].split(":")[0] : null;
        return { name, current, upstream };
      });
  } catch {
    return [];
  }
}

/**
 * Get ahead/behind counts between two refs.
 */
export function getAheadBehind(
  repoPath: string,
  base: string,
  branch: string
): AheadBehind {
  try {
    const output = execFileSync(
      "git",
      [
        "-C",
        repoPath,
        "rev-list",
        "--left-right",
        "--count",
        `${base}...${branch}`,
      ],
      EXEC_OPTIONS
    );
    const [behind, ahead] = output.trim().split("\t").map(Number);
    return { ahead: ahead || 0, behind: behind || 0 };
  } catch {
    return { ahead: 0, behind: 0 };
  }
}

/**
 * Get files with merge conflicts.
 */
export function getConflicts(repoPath: string): string[] {
  try {
    const output = execFileSync(
      "git",
      ["-C", repoPath, "diff", "--name-only", "--diff-filter=U"],
      EXEC_OPTIONS
    );
    return output
      .trim()
      .split("\n")
      .filter((f) => f.trim());
  } catch {
    return [];
  }
}

/**
 * List all git worktrees.
 */
export function listWorktrees(): WorktreeInfo[] {
  try {
    const output = execFileSync(
      "git",
      ["worktree", "list", "--porcelain"],
      EXEC_OPTIONS
    );
    const worktrees: WorktreeInfo[] = [];
    let current: Partial<WorktreeInfo> = {};

    for (const line of output.split("\n")) {
      if (line.startsWith("worktree ")) {
        if (current.path) worktrees.push(current as WorktreeInfo);
        current = { path: line.slice(9) };
      } else if (line.startsWith("HEAD ")) {
        current.head = line.slice(5);
      } else if (line.startsWith("branch ")) {
        current.branch = line.slice(7).replace("refs/heads/", "");
      }
    }
    if (current.path) worktrees.push(current as WorktreeInfo);
    return worktrees;
  } catch {
    return [];
  }
}
