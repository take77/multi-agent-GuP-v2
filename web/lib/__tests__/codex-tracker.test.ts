import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { fetchCodexStatus } from "../codex-tracker";

vi.mock("fs", async () => {
  const actual = await vi.importActual<typeof import("fs")>("fs");
  return {
    ...actual,
    existsSync: vi.fn(),
    readFileSync: vi.fn(),
  };
});

import { existsSync, readFileSync } from "fs";

const mockExistsSync = vi.mocked(existsSync);
const mockReadFileSync = vi.mocked(readFileSync);

describe("fetchCodexStatus", () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("returns null when codex_status.yaml does not exist", async () => {
    mockExistsSync.mockReturnValue(false);

    const result = await fetchCodexStatus();
    expect(result).toBeNull();
  });

  it("returns CodexUsageData when status file exists but no reviews file", async () => {
    mockExistsSync.mockImplementation((p) => {
      if (String(p).includes("codex_status.yaml")) return true;
      return false; // reviews file doesn't exist
    });
    mockReadFileSync.mockReturnValue(
      "status: available\nlast_checked: '2026-04-01T10:00:00Z'\ncooldown_until: null\n"
    );

    const result = await fetchCodexStatus();
    expect(result).not.toBeNull();
    expect(result!.status).toBe("available");
    expect(result!.total_reviews_today).toBe(0);
    expect(result!.pass_count).toBe(0);
    expect(result!.fail_count).toBe(0);
    expect(result!.last_checked).toBe("2026-04-01T10:00:00Z");
    expect(result!.plan).toBe("plus");
    expect(result!.estimated_remaining).toBe(30);
  });

  it("counts today's reviews from jsonl", async () => {
    const today = new Date().toISOString().slice(0, 10);
    mockExistsSync.mockReturnValue(true);

    mockReadFileSync.mockImplementation((p) => {
      if (String(p).includes("codex_status.yaml")) {
        return "status: available\nlast_checked: null\ncooldown_until: null\n";
      }
      // reviews file
      return [
        `{"ts":"${today}T10:00:00Z","task_id":"sub_001","result":"pass"}`,
        `{"ts":"${today}T11:00:00Z","task_id":"sub_002","result":"fail"}`,
        `{"ts":"2025-01-01T10:00:00Z","task_id":"sub_old","result":"pass"}`,
        "malformed line",
      ].join("\n");
    });

    const result = await fetchCodexStatus();
    expect(result).not.toBeNull();
    expect(result!.total_reviews_today).toBe(2);
    expect(result!.pass_count).toBe(1);
    expect(result!.fail_count).toBe(1);
    expect(result!.estimated_remaining).toBe(28);
  });

  it("returns 0 estimated_remaining when rate_limited", async () => {
    mockExistsSync.mockImplementation((p) => {
      if (String(p).includes("codex_status.yaml")) return true;
      return false;
    });
    mockReadFileSync.mockReturnValue(
      "status: rate_limited\ncooldown_until: '2026-04-01T12:00:00Z'\nlast_checked: '2026-04-01T11:00:00Z'\n"
    );

    const result = await fetchCodexStatus();
    expect(result).not.toBeNull();
    expect(result!.status).toBe("rate_limited");
    expect(result!.cooldown_until).toBe("2026-04-01T12:00:00Z");
    expect(result!.estimated_remaining).toBe(0);
  });

  it("defaults status to available when status field is missing", async () => {
    mockExistsSync.mockImplementation((p) => {
      if (String(p).includes("codex_status.yaml")) return true;
      return false;
    });
    mockReadFileSync.mockReturnValue("cooldown_until: null\n");

    const result = await fetchCodexStatus();
    expect(result).not.toBeNull();
    expect(result!.status).toBe("available");
  });
});
