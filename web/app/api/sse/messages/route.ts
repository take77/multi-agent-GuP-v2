import { readdirSync, readFileSync } from "fs";
import { join, basename } from "path";
import { parse as parseYaml } from "yaml";
import { eventBus } from "@/lib/event-bus";
import { startYamlWatcher } from "@/lib/yaml-watcher";
import { getAgentDisplayName } from "@/lib/agent-names";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

startYamlWatcher();

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");
const INBOX_DIR = join(PROJECT_ROOT, "queue", "inbox");

interface RawInboxEntry {
  id: string;
  from: string;
  content: string;
  type: string;
  timestamp: string;
  read: boolean;
}

type EnrichedInboxEntry = RawInboxEntry & {
  to: string;
  fromName: string;
  toName: string;
};

function loadRecentMessages(limit = 50) {
  const messages: EnrichedInboxEntry[] = [];

  try {
    const files = readdirSync(INBOX_DIR).filter(
      (f) => f.endsWith(".yaml") && !f.endsWith(".lock")
    );

    for (const file of files) {
      const agentId = basename(file, ".yaml");
      try {
        const content = readFileSync(join(INBOX_DIR, file), "utf-8");
        const data = parseYaml(content) as { messages?: RawInboxEntry[] };
        if (data?.messages) {
          for (const msg of data.messages) {
            messages.push({
              ...msg,
              to: agentId,
              fromName: getAgentDisplayName(msg.from),
              toName: getAgentDisplayName(agentId),
            });
          }
        }
      } catch {
        // skip unparseable files
      }
    }
  } catch {
    // inbox dir not accessible
  }

  messages.sort(
    (a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
  );

  return messages.slice(-limit);
}

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

      // Send initial batch of recent messages
      const recent = loadRecentMessages();
      send("initial", recent);

      // Subscribe to inbox changes
      const unsubInbox = eventBus.on(
        "inbox-update",
        (payload: unknown) => {
          const { path: filePath, data } = payload as {
            path: string;
            data: { messages?: RawInboxEntry[] };
          };

          const agentId = basename(filePath, ".yaml");
          const msgs = data?.messages;
          if (!msgs) return;

          // Send only unread messages (new arrivals)
          const unread = msgs
            .filter((m) => !m.read)
            .map((m) => ({
              ...m,
              to: agentId,
              fromName: getAgentDisplayName(m.from),
              toName: getAgentDisplayName(agentId),
            }));

          if (unread.length > 0) {
            send("new-messages", unread);
          }
        }
      );

      // Heartbeat
      const heartbeat = setInterval(() => {
        send("heartbeat", Date.now());
      }, 30000);

      req.signal.addEventListener("abort", () => {
        clearInterval(heartbeat);
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
