import { NextResponse } from "next/server";
import { setActiveAgent, getActiveAgent } from "@/lib/pane-streamer";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const agentId = typeof body.agentId === "string" ? body.agentId : null;
    setActiveAgent(agentId);
    return NextResponse.json({ activeAgent: agentId });
  } catch {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}

export async function GET() {
  return NextResponse.json({ activeAgent: getActiveAgent() });
}
