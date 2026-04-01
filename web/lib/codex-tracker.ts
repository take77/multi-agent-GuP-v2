import { existsSync, readFileSync } from "fs";
import path from "path";
import YAML from "yaml";
import type { CodexUsageData } from "@/types/agent";

const PROJECT_ROOT = path.resolve(process.cwd(), "..");
const STATUS_FILE = path.join(PROJECT_ROOT, "queue/hq/codex_status.yaml");
const REVIEWS_FILE = path.join(PROJECT_ROOT, "queue/hq/codex_reviews.jsonl");

export async function fetchCodexStatus(): Promise<CodexUsageData | null> {
  // 1. codex_status.yaml を読む — ファイルが無ければ Codex 未導入
  if (!existsSync(STATUS_FILE)) return null;

  const raw = readFileSync(STATUS_FILE, "utf-8");
  const status = YAML.parse(raw) as Record<string, unknown>;

  // 2. codex_reviews.jsonl から本日分を集計
  let todayReviews = 0;
  let passCount = 0;
  let failCount = 0;
  const today = new Date().toISOString().slice(0, 10);

  if (existsSync(REVIEWS_FILE)) {
    const lines = readFileSync(REVIEWS_FILE, "utf-8")
      .split("\n")
      .filter(Boolean);
    for (const line of lines) {
      try {
        const entry = JSON.parse(line) as {
          ts?: string;
          result?: string;
        };
        if (entry.ts?.startsWith(today)) {
          todayReviews++;
          if (entry.result === "pass") passCount++;
          else failCount++;
        }
      } catch {
        /* skip malformed lines */
      }
    }
  }

  // 3. 残りレビュー推定（Plus: ~30 msg/5h, review ≈ 1 msg）
  const estimatedRemaining =
    status.status === "rate_limited" ? 0 : Math.max(0, 30 - todayReviews);

  return {
    status: (status.status as CodexUsageData["status"]) ?? "available",
    cooldown_until: (status.cooldown_until as string) ?? null,
    total_reviews_today: todayReviews,
    pass_count: passCount,
    fail_count: failCount,
    last_checked: (status.last_checked as string) ?? null,
    plan: "plus",
    estimated_remaining: estimatedRemaining,
  };
}
