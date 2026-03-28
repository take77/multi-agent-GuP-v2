import { readFile, writeFile, mkdir, rmdir, stat } from "fs/promises";
import { existsSync } from "fs";
import { execSync } from "child_process";
import type { UsageData } from "@/types/agent";

const CACHE_FILE = "/tmp/claude-usage-cache.json";
const LOCK_DIR = "/tmp/claude-usage.lock";
const CACHE_MAX_AGE_SEC = 300; // 5 minutes
const LOCK_STALE_SEC = 60;

interface CacheData {
  timestamp: number;
  five_hour_pct: number;
  seven_day_pct: number;
  five_hour_reset: string;
  seven_day_reset: string;
}

interface OAuthUsageResponse {
  five_hour?: { utilization?: number; resets_at?: string };
  seven_day?: { utilization?: number; resets_at?: string };
  error?: unknown;
}

function readCache(): CacheData | null {
  try {
    if (!existsSync(CACHE_FILE)) return null;
    const raw = require("fs").readFileSync(CACHE_FILE, "utf-8");
    return JSON.parse(raw) as CacheData;
  } catch {
    return null;
  }
}

function writeCache(data: CacheData): void {
  try {
    require("fs").writeFileSync(CACHE_FILE, JSON.stringify(data));
  } catch {
    // Cache write failure is non-fatal
  }
}

async function acquireLock(): Promise<boolean> {
  // Clean stale lock
  if (existsSync(LOCK_DIR)) {
    try {
      const st = await stat(LOCK_DIR);
      const age = (Date.now() - st.mtimeMs) / 1000;
      if (age > LOCK_STALE_SEC) {
        await rmdir(LOCK_DIR);
      }
    } catch {
      // Ignore
    }
  }
  try {
    await mkdir(LOCK_DIR);
    return true;
  } catch {
    return false;
  }
}

async function releaseLock(): Promise<void> {
  try {
    await rmdir(LOCK_DIR);
  } catch {
    // Ignore
  }
}

function getAccessToken(): string | null {
  // 1. Environment variable
  const envToken =
    process.env.ANTHROPIC_ACCESS_TOKEN ?? process.env.CLAUDE_ACCESS_TOKEN;
  if (envToken) return envToken;

  // 2. Credentials file
  const credPath = `${process.env.HOME}/.config/claude/credentials.json`;
  try {
    if (!existsSync(credPath)) return null;
    const raw = require("fs").readFileSync(credPath, "utf-8");

    let parsed: Record<string, unknown>;
    if (raw.trimStart().startsWith("{")) {
      // Plain JSON
      parsed = JSON.parse(raw);
    } else {
      // Hex-encoded
      const decoded = execSync(`echo "${raw}" | xxd -r -p`, {
        encoding: "utf-8",
      });
      parsed = JSON.parse(decoded);
    }

    const oauth = parsed.claudeAiOauth as
      | { accessToken?: string }
      | undefined;
    return oauth?.accessToken ?? null;
  } catch {
    return null;
  }
}

function cacheToUsageData(cache: CacheData): UsageData {
  return {
    five_hour: {
      utilization: cache.five_hour_pct,
      resets_at: cache.five_hour_reset,
    },
    seven_day: {
      utilization: cache.seven_day_pct,
      resets_at: cache.seven_day_reset,
    },
    fetched_at: cache.timestamp,
  };
}

export async function fetchUsage(): Promise<UsageData> {
  const now = Math.floor(Date.now() / 1000);

  // Check cache
  const cached = readCache();
  if (cached && now - cached.timestamp < CACHE_MAX_AGE_SEC) {
    return cacheToUsageData(cached);
  }

  // Try to acquire lock
  const locked = await acquireLock();
  if (!locked) {
    // Another process is fetching — return stale cache or defaults
    if (cached) return cacheToUsageData(cached);
    return {
      five_hour: { utilization: 0, resets_at: "N/A" },
      seven_day: { utilization: 0, resets_at: "N/A" },
      fetched_at: now,
    };
  }

  try {
    const token = getAccessToken();
    if (!token) {
      // No token available — write zero cache and return
      const zeroCache: CacheData = {
        timestamp: now,
        five_hour_pct: 0,
        seven_day_pct: 0,
        five_hour_reset: "N/A",
        seven_day_reset: "N/A",
      };
      writeCache(zeroCache);
      return cacheToUsageData(zeroCache);
    }

    const res = await fetch("https://api.anthropic.com/api/oauth/usage", {
      headers: {
        Authorization: `Bearer ${token}`,
        "anthropic-beta": "oauth-2025-04-20",
      },
      signal: AbortSignal.timeout(5000),
    });

    const body = (await res.json()) as OAuthUsageResponse;

    if (body.error) {
      // API error — bump timestamp on existing cache to avoid hammering
      if (cached) {
        cached.timestamp = now;
        writeCache(cached);
        return cacheToUsageData(cached);
      }
      const zeroCache: CacheData = {
        timestamp: now,
        five_hour_pct: 0,
        seven_day_pct: 0,
        five_hour_reset: "N/A",
        seven_day_reset: "N/A",
      };
      writeCache(zeroCache);
      return cacheToUsageData(zeroCache);
    }

    const newCache: CacheData = {
      timestamp: now,
      five_hour_pct: Math.floor(body.five_hour?.utilization ?? 0),
      seven_day_pct: Math.floor(body.seven_day?.utilization ?? 0),
      five_hour_reset: body.five_hour?.resets_at ?? "N/A",
      seven_day_reset: body.seven_day?.resets_at ?? "N/A",
    };
    writeCache(newCache);
    return cacheToUsageData(newCache);
  } catch {
    // Network error — return stale or zero
    if (cached) {
      cached.timestamp = now;
      writeCache(cached);
      return cacheToUsageData(cached);
    }
    return {
      five_hour: { utilization: 0, resets_at: "N/A" },
      seven_day: { utilization: 0, resets_at: "N/A" },
      fetched_at: now,
    };
  } finally {
    await releaseLock();
  }
}
