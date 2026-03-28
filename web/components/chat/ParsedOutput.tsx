"use client";

import { useState } from "react";
import Markdown from "react-markdown";
import type { ParsedSegment } from "@/lib/capture-pane-parser";

/** Tool icon by tool type */
function toolIcon(tool?: string): string {
  switch (tool) {
    case "bash":
      return "$ ";
    case "read":
      return "📄 ";
    case "edit":
      return "✏️ ";
    default:
      return "🔧 ";
  }
}

/** Tool label for the collapsible header */
function toolLabel(seg: ParsedSegment): string {
  if (seg.tool === "bash" && seg.command) {
    return seg.command.length > 60
      ? seg.command.slice(0, 60) + "…"
      : seg.command;
  }
  if (seg.filePath) {
    const name = seg.filePath.split("/").pop() ?? seg.filePath;
    return `${seg.tool === "read" ? "Read" : "Edit"} ${name}`;
  }
  return seg.text;
}

/** Collapsible tool call block */
function ToolCallBlock({
  segment,
  result,
}: {
  segment: ParsedSegment;
  result?: ParsedSegment;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="my-1">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1 text-[11px] text-slate-400 hover:text-slate-200 transition-colors font-mono cursor-pointer w-full text-left"
      >
        <span className="text-[10px] select-none">{open ? "▼" : "▶"}</span>
        <span className="opacity-70">{toolIcon(segment.tool)}</span>
        <span className="truncate">{toolLabel(segment)}</span>
      </button>
      {open && result && (
        <pre className="mt-1 ml-4 text-[10px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[30vh] overflow-y-auto border-l border-slate-700 pl-2">
          {result.text}
        </pre>
      )}
    </div>
  );
}

/**
 * ParsedOutput — capture-pane の構造化出力をレンダリングする。
 * ParsedSegment[] を受け取り、種別ごとに適切な表示を行う。
 */
export function ParsedOutput({ segments }: { segments: ParsedSegment[] }) {
  if (segments.length === 0) return null;

  const elements: React.ReactNode[] = [];
  let i = 0;

  while (i < segments.length) {
    const seg = segments[i];

    switch (seg.kind) {
      case "user-input":
        // Right bubble (same style as send-keys commands)
        elements.push(
          <div key={i} className="flex justify-end my-1">
            <div className="max-w-[75%] bg-sky-600 rounded-xl rounded-tr-sm px-3 py-1.5">
              <span className="text-[11px] text-white font-mono">
                $ {seg.text}
              </span>
            </div>
          </div>
        );
        break;

      case "assistant-text":
        // Left-aligned markdown rendered text
        elements.push(
          <div
            key={i}
            className="prose prose-invert prose-sm max-w-none text-[12px] leading-[1.5] text-slate-300 [&_p]:my-1 [&_ul]:my-1 [&_ol]:my-1 [&_li]:my-0.5 [&_code]:bg-slate-700/50 [&_code]:px-1 [&_code]:rounded [&_code]:text-[11px] [&_pre]:bg-slate-900/50 [&_pre]:p-2 [&_pre]:rounded [&_pre]:text-[11px] [&_h1]:text-sm [&_h2]:text-sm [&_h3]:text-xs [&_a]:text-sky-400"
          >
            <Markdown>{seg.text}</Markdown>
          </div>
        );
        break;

      case "tool-call": {
        // Look ahead for tool-result
        const nextSeg =
          i + 1 < segments.length ? segments[i + 1] : undefined;
        const result =
          nextSeg?.kind === "tool-result" ? nextSeg : undefined;
        elements.push(
          <ToolCallBlock key={i} segment={seg} result={result} />
        );
        if (result) i++; // skip the consumed tool-result
        break;
      }

      case "tool-result":
        // Standalone tool result (not paired with a tool-call)
        elements.push(
          <pre
            key={i}
            className="text-[10px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words ml-4 border-l border-slate-700 pl-2 max-h-[20vh] overflow-y-auto"
          >
            {seg.text}
          </pre>
        );
        break;

      case "status":
        // Small gray text
        elements.push(
          <div
            key={i}
            className="text-[10px] text-slate-600 italic my-0.5"
          >
            {seg.text}
          </div>
        );
        break;

      case "separator":
      case "status-bar":
        // Hidden — do not render
        break;

      case "raw":
        // Monospace fallback
        elements.push(
          <pre
            key={i}
            className="text-[11px] leading-[1.4] text-slate-400 font-mono whitespace-pre-wrap break-words"
          >
            {seg.text}
          </pre>
        );
        break;
    }

    i++;
  }

  return <>{elements}</>;
}
