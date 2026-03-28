import { NextResponse } from "next/server";
import { buildAgentPaneMap, sendKeys } from "@/lib/tmux";
import { sanitizeCommand } from "@/lib/command-sanitizer";
import { writeAuditLog } from "@/lib/audit-log";

export async function POST(req: Request) {
  try {
    const { agentId, command } = await req.json();

    if (!agentId || !command) {
      return NextResponse.json(
        { error: "agentId and command are required" },
        { status: 400 }
      );
    }

    // Extract client IP for audit
    const ip =
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      req.headers.get("x-real-ip") ??
      "unknown";

    const timestamp = new Date().toISOString();

    // D001-D012 command sanitization
    const result = sanitizeCommand(command);

    if (!result.allowed) {
      writeAuditLog({
        timestamp,
        agentId,
        command,
        action: "blocked",
        rule: result.rule,
        ip,
      });

      return NextResponse.json(
        {
          error: "BLOCKED",
          rule: result.rule,
          message: result.message,
        },
        { status: 403 }
      );
    }

    // Audit: allowed command
    writeAuditLog({
      timestamp,
      agentId,
      command,
      action: "allowed",
      ip,
    });

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
