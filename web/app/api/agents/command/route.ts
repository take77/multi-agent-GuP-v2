import { NextResponse } from "next/server";
import { buildAgentPaneMap, sendKeys, sendEscape } from "@/lib/tmux";
import { sanitizeCommand } from "@/lib/command-sanitizer";
import { writeAuditLog } from "@/lib/audit-log";

export async function POST(req: Request) {
  try {
    const { agentId, command, type } = await req.json();

    if (!agentId) {
      return NextResponse.json(
        { error: "agentId is required" },
        { status: 400 }
      );
    }

    const ip =
      req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      req.headers.get("x-real-ip") ??
      "unknown";

    // Escape: skip command validation — send Escape key to pane
    if (type === "escape") {
      const paneMap = buildAgentPaneMap();
      const paneId = paneMap.get(agentId);
      if (!paneId) {
        return NextResponse.json(
          { error: `Agent '${agentId}' not found or has no active pane` },
          { status: 404 }
        );
      }
      writeAuditLog({ timestamp: new Date().toISOString(), agentId, command: "ESCAPE", action: "allowed", ip });
      sendEscape(paneId);
      return NextResponse.json({ success: true, agentId, paneId });
    }

    if (!command) {
      return NextResponse.json(
        { error: "command is required" },
        { status: 400 }
      );
    }

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

    // ESCAPE_KEY: legacy support for StopButton
    if (command === "ESCAPE_KEY") {
      sendEscape(paneId);
    } else {
      sendKeys(paneId, command);
    }

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
