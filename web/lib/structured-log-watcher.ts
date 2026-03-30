import { watch, type FSWatcher } from "chokidar";
import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { eventBus } from "./event-bus";
import type { StructuredEvent } from "@/types/structured-event";

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");
const STRUCTURED_LOG_DIR = join(PROJECT_ROOT, "logs", "structured");
const WATCH_GLOB = `${STRUCTURED_LOG_DIR}/*.jsonl`;

// Track file read positions to detect new lines only
const filePositions = new Map<string, number>();

let watcher: FSWatcher | null = null;

function parseNewLines(filePath: string): StructuredEvent[] {
  const events: StructuredEvent[] = [];

  try {
    const content = readFileSync(filePath, "utf-8");
    const prevPos = filePositions.get(filePath) ?? 0;
    const newContent = content.slice(prevPos);
    filePositions.set(filePath, content.length);

    for (const line of newContent.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const parsed = JSON.parse(trimmed) as StructuredEvent;
        if (parsed.event && parsed.agent_id && parsed.timestamp) {
          events.push(parsed);
        }
      } catch {
        // Skip malformed JSON lines — never crash
      }
    }
  } catch {
    // File unreadable — skip silently
  }

  return events;
}

export function startStructuredLogWatcher(): FSWatcher | null {
  if (watcher) return watcher;

  // Graceful degradation: if logs/structured/ doesn't exist, skip silently
  if (!existsSync(STRUCTURED_LOG_DIR)) {
    return null;
  }

  watcher = watch(WATCH_GLOB, {
    awaitWriteFinish: {
      stabilityThreshold: 100,
      pollInterval: 50,
    },
    ignoreInitial: false, // Read existing files on startup to set positions
  });

  watcher.on("add", (filePath) => {
    // Initialize position without emitting on startup
    try {
      const content = readFileSync(filePath, "utf-8");
      filePositions.set(filePath, content.length);
    } catch {
      filePositions.set(filePath, 0);
    }
  });

  watcher.on("change", (filePath) => {
    const events = parseNewLines(filePath);
    for (const event of events) {
      eventBus.emit("structured-event", event);
    }
  });

  return watcher;
}

export function stopStructuredLogWatcher(): void {
  if (watcher) {
    watcher.close();
    watcher = null;
  }
  filePositions.clear();
}
