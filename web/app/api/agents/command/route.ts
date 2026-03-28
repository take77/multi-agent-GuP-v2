import { NextResponse } from "next/server";

export async function POST(req: Request) {
  try {
    const { agentId, command } = await req.json();

    if (!agentId || !command) {
      return NextResponse.json(
        { error: "agentId and command are required" },
        { status: 400 }
      );
    }

    // Phase 1: stub response
    // Phase 2: tmux send-keys integration
    return NextResponse.json({
      success: true,
      agentId,
      message: "Command queued (Phase 1 stub)",
    });
  } catch {
    return NextResponse.json(
      { error: "Invalid request body" },
      { status: 400 }
    );
  }
}
