import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { verifyAuth } from "../auth";

function makeRequest(headers: Record<string, string> = {}): Request {
  return new Request("http://localhost:3000/api/test", {
    headers,
  });
}

describe("verifyAuth", () => {
  const originalEnv = { ...process.env };

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  describe("when AUTH_DISABLED=true", () => {
    beforeEach(() => {
      process.env.AUTH_DISABLED = "true";
    });

    it("allows any request", () => {
      const r = verifyAuth(makeRequest());
      expect(r.authenticated).toBe(true);
    });
  });

  describe("when WEB_UI_AUTH_TOKEN is not set", () => {
    beforeEach(() => {
      delete process.env.AUTH_DISABLED;
      delete process.env.WEB_UI_AUTH_TOKEN;
    });

    it("rejects with config error", () => {
      const r = verifyAuth(makeRequest());
      expect(r.authenticated).toBe(false);
      expect(r.error).toContain("not configured");
    });
  });

  describe("with token configured", () => {
    beforeEach(() => {
      delete process.env.AUTH_DISABLED;
      process.env.WEB_UI_AUTH_TOKEN = "test-secret-token-123";
    });

    it("rejects missing auth header", () => {
      const r = verifyAuth(makeRequest());
      expect(r.authenticated).toBe(false);
      expect(r.error).toContain("Missing");
    });

    it("rejects invalid format", () => {
      const r = verifyAuth(makeRequest({ authorization: "Basic abc123" }));
      expect(r.authenticated).toBe(false);
      expect(r.error).toContain("Invalid Authorization format");
    });

    it("rejects wrong token", () => {
      const r = verifyAuth(
        makeRequest({ authorization: "Bearer wrong-token" })
      );
      expect(r.authenticated).toBe(false);
      expect(r.error).toContain("Invalid token");
    });

    it("accepts correct token", () => {
      const r = verifyAuth(
        makeRequest({ authorization: "Bearer test-secret-token-123" })
      );
      expect(r.authenticated).toBe(true);
    });

    it("accepts case-insensitive Bearer prefix", () => {
      const r = verifyAuth(
        makeRequest({ authorization: "bearer test-secret-token-123" })
      );
      expect(r.authenticated).toBe(true);
    });
  });
});
