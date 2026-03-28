import { NextResponse } from "next/server";
import { buildAgentPaneMap, sendKeys } from "@/lib/tmux";

export async function POST(req: Request) {
  try {
    const { agentId, command } = await req.json();

    if (!agentId || !command) {
      return NextResponse.json(
        { error: "agentId and command are required" },
        { status: 400 }
      );
    }

    const paneMap = buildAgentPaneMap();
    const paneId = paneMap.get(agentId);

    if (!paneId) {
      return NextResponse.json(
        { error: `Agent '${agentId}' not found or has no active pane` },
        { status: 404 }
      );
    }

    sendKeys(paneId, command);

    return NextResponse.json({
      success: true,
      agentId,
      paneId,
    });
  } catch {
    return NextResponse.json(
      { error: "Failed to send command" },
      { status: 500 }
    );
  }
}
