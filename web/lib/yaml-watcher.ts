import { watch, type FSWatcher } from "chokidar";
import { readFileSync } from "fs";
import { parse as parseYaml } from "yaml";
import { eventBus } from "./event-bus";

const PROJECT_ROOT = process.cwd().replace(/\/web$/, "");

const WATCH_PATHS = [
  `${PROJECT_ROOT}/queue/tasks/*.yaml`,
  `${PROJECT_ROOT}/queue/reports/*.yaml`,
  `${PROJECT_ROOT}/queue/inbox/*.yaml`,
];

let watcher: FSWatcher | null = null;

function parseYamlWithRetry(
  filePath: string,
  maxRetries = 3,
  delayMs = 200
): unknown | null {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const content = readFileSync(filePath, "utf-8");
      return parseYaml(content);
    } catch {
      if (i < maxRetries - 1) {
        const start = Date.now();
        while (Date.now() - start < delayMs) {
          // busy-wait (sync context)
        }
      }
    }
  }
  return null;
}

export function startYamlWatcher(): FSWatcher {
  if (watcher) return watcher;

  watcher = watch(WATCH_PATHS, {
    awaitWriteFinish: {
      stabilityThreshold: 300,
      pollInterval: 100,
    },
    ignoreInitial: true,
  });

  watcher.on("change", (path) => {
    const data = parseYamlWithRetry(path);
    if (data) {
      const category = path.includes("/tasks/")
        ? "task-update"
        : path.includes("/reports/")
          ? "report-update"
          : "inbox-update";
      eventBus.emit(category, { path, data });
    }
  });

  watcher.on("add", (path) => {
    const data = parseYamlWithRetry(path);
    if (data) {
      eventBus.emit("yaml-add", { path, data });
    }
  });

  return watcher;
}

export function stopYamlWatcher(): void {
  if (watcher) {
    watcher.close();
    watcher = null;
  }
}
