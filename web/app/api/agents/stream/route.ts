import { eventBus } from "@/lib/event-bus";
import { startPaneStreaming } from "@/lib/pane-streamer";
import { startYamlWatcher } from "@/lib/yaml-watcher";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Start background services on first import
startPaneStreaming();
startYamlWatcher();

export async function GET(req: Request) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      function send(event: string, data: unknown) {
        try {
          controller.enqueue(
            encoder.encode(
              `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`
            )
          );
        } catch {
          // Controller closed
        }
      }

      // Send initial connection event
      send("connected", { status: "ok" });

      // Subscribe to agent output events
      const unsubOutput = eventBus.on("agent-output", (data: unknown) => {
        send("agent-output", data);
      });

      // Subscribe to YAML change events
      const unsubTask = eventBus.on("task-update", (data: unknown) => {
        send("task-update", data);
      });

      const unsubReport = eventBus.on("report-update", (data: unknown) => {
        send("report-update", data);
      });

      const unsubInbox = eventBus.on("inbox-update", (data: unknown) => {
        send("inbox-update", data);
      });

      // Heartbeat every 30 seconds
      const heartbeat = setInterval(() => {
        send("heartbeat", Date.now());
      }, 30000);

      // Clean up on client disconnect
      req.signal.addEventListener("abort", () => {
        clearInterval(heartbeat);
        unsubOutput();
        unsubTask();
        unsubReport();
        unsubInbox();
        try {
          controller.close();
        } catch {
          // already closed
        }
      });
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
