import { eventBus } from "@/lib/event-bus";
import { startStructuredLogWatcher } from "@/lib/structured-log-watcher";
import type { StructuredEvent } from "@/types/structured-event";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

// Start watcher once per process (no-op if logs/structured/ doesn't exist)
startStructuredLogWatcher();

export async function GET(req: Request) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      function send(event: string, data: unknown) {
        try {
          controller.enqueue(
            encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`)
          );
        } catch {
          // Controller closed
        }
      }

      // Subscribe to structured events
      const unsubStructured = eventBus.on(
        "structured-event",
        (payload: unknown) => {
          send("structured-event", payload as StructuredEvent);
        }
      );

      // Heartbeat
      const heartbeat = setInterval(() => {
        send("heartbeat", Date.now());
      }, 30000);

      req.signal.addEventListener("abort", () => {
        clearInterval(heartbeat);
        unsubStructured();
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
