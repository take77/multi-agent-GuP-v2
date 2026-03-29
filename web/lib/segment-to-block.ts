/**
 * segment-to-block.ts
 *
 * ParsedSegment[] → ParsedBlock[] 変換アダプター。
 * ミカのパーサー（subtask_140_a）が完成するまでの一時的なブリッジ。
 * パーサーが ParsedBlock[] を直接出力するようになったらこのファイルは削除可能。
 */

import type { ParsedSegment } from "@/lib/capture-pane-parser";
import type { ParsedBlock, ToolCall } from "@/types/parsed-blocks";

/** ツール種別からアイコンを決定 */
function toolIcon(tool?: string): string {
  switch (tool) {
    case "bash":
      return "💻";
    case "read":
      return "📖";
    case "edit":
      return "📝";
    default:
      return "🔧";
  }
}

/** ツール種別からラベルを決定 */
function toolLabelFromSegment(seg: ParsedSegment): string {
  switch (seg.tool) {
    case "bash":
      return "Bash";
    case "read":
      return "Read";
    case "edit":
      if (seg.text.startsWith("Write") || seg.text.startsWith("● Write")) return "Write";
      if (seg.text.startsWith("Update") || seg.text.startsWith("● Update")) return "Update";
      return "Edit";
    default:
      return seg.tool ?? "Tool";
  }
}

/** ツールの詳細（コマンドやファイルパス）を取得 */
function toolDetail(seg: ParsedSegment): string {
  if (seg.command) {
    return seg.command.length > 120 ? seg.command.slice(0, 120) + "..." : seg.command;
  }
  if (seg.filePath) {
    return seg.filePath;
  }
  return seg.text;
}

/**
 * ParsedSegment[] を ParsedBlock[] に変換する。
 * 連続するツールコール+結果をまとめて tool-execution ブロックにグルーピングする。
 */
export function segmentsToBlocks(
  segments: ParsedSegment[],
  agentName: string
): ParsedBlock[] {
  const blocks: ParsedBlock[] = [];
  let i = 0;

  while (i < segments.length) {
    const seg = segments[i];

    switch (seg.kind) {
      case "user-input":
        blocks.push({ type: "user-input", content: seg.text });
        i++;
        break;

      case "assistant-text":
        blocks.push({ type: "assistant-text", content: seg.text });
        i++;
        break;

      case "tool-call": {
        // Collect consecutive tool-call / tool-result pairs into one tool-execution block
        const tools: ToolCall[] = [];
        while (i < segments.length && (segments[i].kind === "tool-call" || segments[i].kind === "tool-result" || segments[i].kind === "status")) {
          const current = segments[i];

          if (current.kind === "status") {
            // "Cogitated for X seconds" → treat as a special tool
            tools.push({
              icon: "⏱",
              label: "Cogitated",
              detail: current.text,
            });
            i++;
            continue;
          }

          if (current.kind === "tool-call") {
            const tool: ToolCall = {
              icon: toolIcon(current.tool),
              label: toolLabelFromSegment(current),
              detail: toolDetail(current),
            };

            // Check if next segment is a tool-result (paired)
            if (i + 1 < segments.length && segments[i + 1].kind === "tool-result") {
              tool.result = segments[i + 1].text;
              i += 2;
            } else {
              i++;
            }

            tools.push(tool);
            continue;
          }

          // Standalone tool-result (not paired)
          if (current.kind === "tool-result") {
            // Attach to last tool if possible
            if (tools.length > 0 && !tools[tools.length - 1].result) {
              tools[tools.length - 1].result = current.text;
            }
            i++;
            continue;
          }

          break;
        }

        if (tools.length > 0) {
          blocks.push({ type: "tool-execution", tools, agentName });
        }
        break;
      }

      case "tool-result":
        // Standalone tool result without a preceding tool-call → raw
        blocks.push({ type: "raw", content: seg.text });
        i++;
        break;

      case "status":
        // Status outside tool context (e.g. "Cogitated") → tool-execution with single entry
        blocks.push({
          type: "tool-execution",
          tools: [{ icon: "⏱", label: "Cogitated", detail: seg.text }],
          agentName,
        });
        i++;
        break;

      case "separator":
      case "status-bar":
        // Skip — don't render
        i++;
        break;

      case "raw":
      default:
        blocks.push({ type: "raw", content: seg.text });
        i++;
        break;
    }
  }

  return blocks;
}
