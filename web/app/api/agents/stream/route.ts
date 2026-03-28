export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(req: Request) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      // Send initial connection event
      controller.enqueue(
        encoder.encode(`event: connected\ndata: {"status":"ok"}\n\n`)
      );

      // Heartbeat every 30 seconds
      const heartbeat = setInterval(() => {
        try {
          controller.enqueue(
            encoder.encode(`event: heartbeat\ndata: ${Date.now()}\n\n`)
          );
        } catch {
          clearInterval(heartbeat);
        }
      }, 30000);

      // Clean up on client disconnect
      req.signal.addEventListener("abort", () => {
        clearInterval(heartbeat);
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
