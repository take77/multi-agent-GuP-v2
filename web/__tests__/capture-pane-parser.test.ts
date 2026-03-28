import { describe, it, expect } from "vitest";
import { parseCapturePane, parseCapturePaneOutput } from "../lib/capture-pane-parser";

describe("parseCapturePane", () => {
  it("extracts assistant text from ● lines", () => {
    const input = `● 了解〜。これは杏の返答だよ。
  干し芋もぐもぐ。`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("assistant-text");
    expect((blocks[0] as { type: "assistant-text"; content: string }).content).toContain("了解〜");
    expect((blocks[0] as { type: "assistant-text"; content: string }).content).toContain("干し芋");
  });

  it("detects ● Bash() as tool-execution, not assistant-text", () => {
    const input = `● Bash(bash scripts/inbox_write.sh maho "test message" report_received mika)
  ⎿  [2026-03-28T22:00:00] [inbox_write] SUCCESS: mika → maho`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("tool-execution");
    const toolBlock = blocks[0] as { type: "tool-execution"; tools: Array<{ label: string; result?: string }> };
    expect(toolBlock.tools).toHaveLength(1);
    expect(toolBlock.tools[0].label).toBe("Bash");
    expect(toolBlock.tools[0].result).toContain("SUCCESS");
  });

  it("detects ● Update() as tool-execution", () => {
    const input = `● Update(queue/tasks/mika.yaml)
  ⎿  Added 3 lines, removed 1 line
      5  +  status: in_progress`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("tool-execution");
    const toolBlock = blocks[0] as { type: "tool-execution"; tools: Array<{ label: string; detail: string }> };
    expect(toolBlock.tools[0].label).toBe("Update");
    expect(toolBlock.tools[0].detail).toContain("mika.yaml");
  });

  it("extracts user input from ❯ lines (multi-line)", () => {
    const input = `❯ これは司令官の入力です
追加の行もあるよ

● 了解〜。`;
    const blocks = parseCapturePane(input);
    expect(blocks.length).toBeGreaterThanOrEqual(2);
    expect(blocks[0].type).toBe("user-input");
    const userBlock = blocks[0] as { type: "user-input"; content: string };
    expect(userBlock.content).toContain("これは司令官の入力です");
    expect(userBlock.content).toContain("追加の行もあるよ");
    expect(blocks[1].type).toBe("assistant-text");
  });

  it("skips separator, status-bar, and session banner lines", () => {
    const input = `────────────────────────────────
⏵⏵ bypass permissions on (shift+tab to cycle)
╭──────────────────────╮
● これだけが見える。`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("assistant-text");
    expect((blocks[0] as { type: "assistant-text"; content: string }).content).toContain("これだけが見える");
  });

  it("merges consecutive tool calls into one tool-execution block", () => {
    const input = `● Read(web/lib/store.ts)
  ⎿  Contents of store.ts...
● Read(web/types/agent.ts)
  ⎿  Contents of agent.ts...`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("tool-execution");
    const toolBlock = blocks[0] as { type: "tool-execution"; tools: Array<{ label: string }> };
    expect(toolBlock.tools).toHaveLength(2);
    expect(toolBlock.tools[0].label).toBe("Read");
    expect(toolBlock.tools[1].label).toBe("Read");
  });

  it("handles cogitate/churned as tool in tool-execution block", () => {
    const input = `✻ Cogitated for 2m 30s`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("tool-execution");
    const toolBlock = blocks[0] as { type: "tool-execution"; tools: Array<{ label: string; icon: string }> };
    expect(toolBlock.tools[0].label).toBe("Cogitated");
    expect(toolBlock.tools[0].icon).toBe("⏱");
  });

  it("handles assistant text with tables (preserves table content)", () => {
    const input = `● cmd_138 完了！

  ┌──────────┬──────┐
  │ タスク   │ 結果 │
  ├──────────┼──────┤
  │ A: 修正  │ ✅   │
  └──────────┴──────┘

  確認してね。`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("assistant-text");
    const textBlock = blocks[0] as { type: "assistant-text"; content: string };
    expect(textBlock.content).toContain("cmd_138 完了");
    expect(textBlock.content).toContain("タスク");
    expect(textBlock.content).toContain("確認してね");
  });

  it("falls back to raw for orphaned lines", () => {
    const input = `      5522 some orphaned diff content
      5523 more orphaned stuff`;
    const blocks = parseCapturePane(input);
    expect(blocks).toHaveLength(1);
    expect(blocks[0].type).toBe("raw");
  });
});

describe("parseCapturePaneOutput (legacy API)", () => {
  it("returns ParsedSegment[] with correct kinds", () => {
    const input = `● テスト応答
● Bash(echo hello)
  ⎿  hello`;
    const segments = parseCapturePaneOutput(input);
    const kinds = segments.map((s) => s.kind);
    expect(kinds).toContain("assistant-text");
    expect(kinds).toContain("tool-call");
    expect(kinds).toContain("tool-result");
  });
});
