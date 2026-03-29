import { NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import { execFileSync } from "child_process";
import { parse } from "yaml";
import path from "path";

const EXEC_OPTIONS = { encoding: "utf-8" as const, timeout: 10000 };
const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const PROJECTS_YAML = path.join(PROJECT_ROOT, "config/projects.yaml");

function getRepoPaths(): { id: string; path: string }[] {
  if (!existsSync(PROJECTS_YAML)) return [];
  const data = parse(readFileSync(PROJECTS_YAML, "utf-8"));
  const result: { id: string; path: string }[] = [];
  for (const p of data?.projects ?? []) {
    if (typeof p.path === "string") {
      result.push({ id: p.id, path: p.path });
    } else if (typeof p.path === "object") {
      for (const [key, val] of Object.entries(p.path)) {
        if (typeof val === "string" && existsSync(val)) {
          result.push({ id: `${p.id}_${key}`, path: val });
        }
      }
    }
  }
  return result;
}

export async function GET() {
  try {
    const repos = getRepoPaths();
    const conflicts: Record<string, string[]> = {};

    for (const repo of repos) {
      if (!existsSync(repo.path)) continue;
      try {
        const output = execFileSync(
          "git",
          ["-C", repo.path, "diff", "--name-only", "--diff-filter=U"],
          EXEC_OPTIONS
        ).trim();
        if (output) {
          conflicts[repo.id] = output.split("\n").filter(Boolean);
        }
      } catch { /* no conflicts or not a git repo */ }
    }

    return NextResponse.json({ conflicts });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
