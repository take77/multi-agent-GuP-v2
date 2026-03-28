import { NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import { execFileSync } from "child_process";
import { parse } from "yaml";
import path from "path";
import type { Branch, BranchType, Repository } from "@/types/git";

const EXEC_OPTIONS = { encoding: "utf-8" as const, timeout: 10000 };
const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const PROJECTS_YAML = path.join(PROJECT_ROOT, "config/projects.yaml");
const SQUADS_YAML = path.join(PROJECT_ROOT, "config/squads.yaml");

// Squad colors (matching store.ts demo data)
const SQUAD_COLORS: Record<string, string> = {
  darjeeling: "#3b82f6",
  katyusha: "#ef4444",
  kay: "#22c55e",
  maho: "#a855f7",
};

const SQUAD_NAMES: Record<string, string> = {
  darjeeling: "ダージリン隊",
  katyusha: "カチューシャ隊",
  kay: "ケイ隊",
  maho: "まほ隊",
};

// Protected and integration branch names
const PROTECTED_BRANCHES = new Set(["main", "master"]);
const INTEGRATION_BRANCHES = new Set(["develop", "dev", "staging"]);

function classifyBranch(name: string): BranchType {
  if (PROTECTED_BRANCHES.has(name)) return "protected";
  if (INTEGRATION_BRANCHES.has(name)) return "integration";
  return "feature";
}

function detectSquad(branchName: string, squads: Record<string, { members: string[] }>): { squad: string | null; color: string | null } {
  const lower = branchName.toLowerCase();
  for (const [squadId, squadInfo] of Object.entries(squads)) {
    if (lower.includes(squadId)) return { squad: SQUAD_NAMES[squadId] ?? squadId, color: SQUAD_COLORS[squadId] ?? null };
    for (const member of squadInfo.members ?? []) {
      if (lower.includes(member)) return { squad: SQUAD_NAMES[squadId] ?? squadId, color: SQUAD_COLORS[squadId] ?? null };
    }
  }
  return { squad: null, color: null };
}

function estimateParent(branchName: string, type: BranchType, allBranches: string[]): string | null {
  if (type === "protected") return null;
  if (type === "integration") {
    if (allBranches.includes("main")) return "main";
    if (allBranches.includes("master")) return "master";
    return null;
  }
  // Feature branches: try to derive parent from naming
  const parts = branchName.split("/");
  if (parts.length > 2) {
    const candidate = parts.slice(0, -1).join("/");
    if (allBranches.includes(candidate)) return candidate;
  }
  // Default parent: develop > main > master
  if (allBranches.includes("develop")) return "develop";
  if (allBranches.includes("dev")) return "dev";
  if (allBranches.includes("main")) return "main";
  if (allBranches.includes("master")) return "master";
  return null;
}

function git(repoPath: string, args: string[]): string {
  return execFileSync("git", ["-C", repoPath, ...args], EXEC_OPTIONS).trim();
}

function getRepoPath(repoId: string): string | null {
  if (!existsSync(PROJECTS_YAML)) return null;
  const data = parse(readFileSync(PROJECTS_YAML, "utf-8"));
  const project = data?.projects?.find((p: { id: string }) => p.id === repoId);
  if (!project) return null;
  if (typeof project.path === "string") return project.path;
  // Multi-path project: return first existing path
  if (typeof project.path === "object") {
    for (const p of Object.values(project.path)) {
      if (typeof p === "string" && existsSync(p)) return p;
    }
  }
  return null;
}

function getRepos(): Repository[] {
  if (!existsSync(PROJECTS_YAML)) return [];
  const data = parse(readFileSync(PROJECTS_YAML, "utf-8"));
  return (data?.projects ?? []).map((p: Record<string, unknown>) => {
    const repoPath = typeof p.path === "string" ? p.path : typeof p.path === "object" ? Object.values(p.path as Record<string, string>)[0] : "";
    let lang = "";
    try {
      if (existsSync(path.join(repoPath as string, "package.json"))) lang = "TypeScript";
      else if (existsSync(path.join(repoPath as string, "Gemfile"))) lang = "Ruby";
      else if (existsSync(path.join(repoPath as string, "go.mod"))) lang = "Go";
    } catch { /* */ }
    return { id: p.id as string, name: (p.name ?? p.id) as string, desc: (p.notes ?? "") as string, lang, path: repoPath as string };
  });
}

function loadSquads(): Record<string, { captain: string; members: string[] }> {
  if (!existsSync(SQUADS_YAML)) return {};
  const data = parse(readFileSync(SQUADS_YAML, "utf-8"));
  return data?.squads ?? {};
}

function timeAgo(dateStr: string): string {
  const date = new Date(dateStr);
  const now = Date.now();
  const diffMs = now - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return "just now";
  if (diffMin < 60) return `${diffMin}m ago`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `${diffH}h ago`;
  const diffD = Math.floor(diffH / 24);
  return `${diffD}d ago`;
}

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ repoId: string }> }
) {
  try {
    const { repoId } = await params;

    // Special case: return repo list
    if (repoId === "_repos") {
      return NextResponse.json({ repositories: getRepos() });
    }

    const repoPath = getRepoPath(repoId);
    if (!repoPath || !existsSync(repoPath)) {
      return NextResponse.json({ error: "Repository not found" }, { status: 404 });
    }

    const squads = loadSquads();

    // Get all branch names
    const branchOutput = git(repoPath, ["branch", "--format=%(refname:short)"]);
    const branchNames = branchOutput.split("\n").filter(Boolean);

    // Build branch info
    const branches: Branch[] = branchNames.map((name) => {
      const type = classifyBranch(name);
      const parent = estimateParent(name, type, branchNames);
      const { squad, color } = detectSquad(name, squads);

      // Last commit
      let commit = "";
      let time = "";
      try {
        commit = git(repoPath, ["log", "--oneline", "-1", "--format=%s", name]);
        const isoDate = git(repoPath, ["log", "-1", "--format=%ci", name]);
        time = timeAgo(isoDate);
      } catch { /* */ }

      // Ahead/behind
      let ahead = 0;
      let behind = 0;
      if (parent) {
        try {
          const counts = git(repoPath, ["rev-list", "--left-right", "--count", `${parent}...${name}`]);
          const [b, a] = counts.split("\t").map(Number);
          ahead = a || 0;
          behind = b || 0;
        } catch { /* */ }
      }

      // Changed files (diffstat against parent)
      let files: [number, number, number] | undefined;
      if (parent && type === "feature") {
        try {
          const stat = git(repoPath, ["diff", "--numstat", `${parent}...${name}`]);
          let modified = 0, added = 0, deleted = 0;
          for (const line of stat.split("\n").filter(Boolean)) {
            const [a, d] = line.split("\t");
            const addN = parseInt(a) || 0;
            const delN = parseInt(d) || 0;
            if (addN > 0 && delN > 0) modified++;
            else if (addN > 0) added++;
            else if (delN > 0) deleted++;
          }
          files = [modified, added, deleted];
        } catch { /* */ }
      }

      // Stale detection: behind > 3 and no commit in last 30 min
      let stale = false;
      if (behind > 3) {
        try {
          const lastCommitTime = git(repoPath, ["log", "-1", "--format=%ct", name]);
          const ageSec = Math.floor(Date.now() / 1000) - parseInt(lastCommitTime);
          if (ageSec > 1800) stale = true;
        } catch { /* */ }
      }

      // Conflicts
      let conflict: string[] | undefined;
      try {
        const conflictFiles = git(repoPath, ["diff", "--name-only", "--diff-filter=U"]);
        if (conflictFiles) conflict = conflictFiles.split("\n").filter(Boolean);
      } catch { /* */ }

      return {
        id: name,
        name,
        type,
        parent,
        squad,
        squadColor: color,
        commit,
        time,
        ahead,
        behind,
        files,
        conflict: conflict?.length ? conflict : undefined,
        stale: stale || undefined,
      };
    });

    return NextResponse.json({ branches });
  } catch (err) {
    return NextResponse.json(
      { error: String(err) },
      { status: 500 }
    );
  }
}
