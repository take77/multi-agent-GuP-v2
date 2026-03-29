import { NextResponse } from "next/server";
import { readFileSync, existsSync } from "fs";
import { parse } from "yaml";
import path from "path";
import { listWorktrees } from "@/lib/git";
import type { Worktree } from "@/types/git";

const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const SQUADS_YAML = path.join(PROJECT_ROOT, "config/squads.yaml");
const TASKS_DIR = path.join(PROJECT_ROOT, "queue/tasks");

const SQUAD_COLORS: Record<string, string> = {
  darjeeling: "#3b82f6",
  katyusha: "#ef4444",
  kay: "#22c55e",
  maho: "#a855f7",
};

function loadSquads(): Record<string, { captain: string; members: string[] }> {
  if (!existsSync(SQUADS_YAML)) return {};
  const data = parse(readFileSync(SQUADS_YAML, "utf-8"));
  return data?.squads ?? {};
}

function detectMemberAndSquad(
  branchName: string,
  squads: Record<string, { captain: string; members: string[] }>
): { member: string | null; squad: string | null; squadColor: string | null } {
  // Pattern: cmd_XXX/{member_name}/...
  const parts = branchName.split("/");
  if (parts.length >= 2) {
    const memberCandidate = parts[1].toLowerCase();
    for (const [squadId, squadInfo] of Object.entries(squads)) {
      const allMembers = [squadInfo.captain, ...(squadInfo.members ?? [])];
      if (allMembers.includes(memberCandidate)) {
        return {
          member: memberCandidate,
          squad: squadId,
          squadColor: SQUAD_COLORS[squadId] ?? null,
        };
      }
    }
    // Also try matching the member name anywhere in the branch parts
    for (const [squadId, squadInfo] of Object.entries(squads)) {
      const allMembers = [squadInfo.captain, ...(squadInfo.members ?? [])];
      for (const part of parts) {
        if (allMembers.includes(part.toLowerCase())) {
          return {
            member: part.toLowerCase(),
            squad: squadId,
            squadColor: SQUAD_COLORS[squadId] ?? null,
          };
        }
      }
    }
  }
  return { member: null, squad: null, squadColor: null };
}

function loadTaskInfo(
  memberName: string | null
): { taskId: string | null; taskDescription: string | null } {
  if (!memberName || !existsSync(TASKS_DIR)) {
    return { taskId: null, taskDescription: null };
  }
  const taskFile = path.join(TASKS_DIR, `${memberName}.yaml`);
  if (!existsSync(taskFile)) {
    return { taskId: null, taskDescription: null };
  }
  try {
    const data = parse(readFileSync(taskFile, "utf-8"));
    const taskId = data?.task?.task_id ?? null;
    const rawDesc = data?.task?.description ?? null;
    const taskDescription =
      typeof rawDesc === "string" ? rawDesc.trim().slice(0, 50) : null;
    return { taskId, taskDescription };
  } catch {
    return { taskId: null, taskDescription: null };
  }
}

export async function GET() {
  try {
    const rawWorktrees = listWorktrees();
    const squads = loadSquads();

    const worktrees: Worktree[] = rawWorktrees.map((wt) => {
      const { member, squad, squadColor } = detectMemberAndSquad(
        wt.branch,
        squads
      );
      const { taskId, taskDescription } = loadTaskInfo(member);

      return {
        path: wt.path,
        branch: wt.branch,
        head: wt.head,
        squad,
        squadColor,
        member,
        taskId,
        taskDescription,
      };
    });

    return NextResponse.json({ worktrees });
  } catch (err) {
    return NextResponse.json({ error: String(err) }, { status: 500 });
  }
}
