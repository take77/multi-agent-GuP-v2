import { NextResponse } from "next/server";

export async function GET() {
  // Phase 1: return stub data
  // Phase 2: tmux list-panes + squads.yaml integration
  return NextResponse.json({
    clusters: [
      {
        id: "command",
        name: "司令部",
        color: "#f59e0b",
        agents: [
          { id: "anzu", name: "あんず", role: "総司令", status: "active" },
          { id: "miho", name: "みほ", role: "参謀長", status: "active" },
        ],
      },
    ],
    message: "Phase 1 stub - live data in Phase 2",
  });
}
