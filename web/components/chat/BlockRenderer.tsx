"use client";

import React, { useState, memo } from "react";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkBreaks from "remark-breaks";
import { Avatar } from "@/components/shared/Avatar";
import { getAgentDisplayName } from "@/lib/agent-names";
import { DiffFoldView } from "@/components/chat/DiffFoldView";
import type { ParsedBlock, ToolCall } from "@/types/parsed-blocks";
import { TruncatedToolResult } from "./TruncatedToolResult";

// ── 0. Bash Summary Helpers ──

interface BashSummary {
  icon: string;
  text: string;
  errorDetails?: string;
}

function parseBashSummary(detail: string, result: string): BashSummary | null {
  // npm install / yarn add / npm ci / pnpm install
  if (/\bnpm\s+(install|ci|i)\b|\byarn\s+(add|install)\b|\bpnpm\s+(install|add)\b/.test(detail)) {
    const addedMatch = result.match(/added (\d+) packages?/);
    const count = addedMatch ? addedMatch[1] : null;
    return {
      icon: "📦",
      text: count ? `${count} packages installed` : "packages installed",
    };
  }

  // npm run build / next build / yarn build / vite build / tsc
  if (/\bnpm\s+run\s+build\b|\byarn\s+build\b|\bnext\s+build\b|\bvite\s+build\b|\bnpx\s+next\s+build\b|\btsc\b/.test(detail)) {
    // Detect failure: "error" keyword present, but not in a passing test summary
    const hasBuildError =
      /\b(Error|error TS|FAILED|Build error)\b/.test(result) ||
      / failed\b/.test(result.toLowerCase());
    if (hasBuildError) {
      const errorLines = result
        .split("\n")
        .filter((l) => /error/i.test(l))
        .slice(0, 3)
        .join(" | ")
        .trim();
      return {
        icon: "🔨",
        text: "Build failed ✗",
        errorDetails: errorLines || undefined,
      };
    }
    return { icon: "🔨", text: "Build pass ✓" };
  }

  // vitest / jest
  if (/\bvitest\b|\bjest\b/.test(detail)) {
    const passMatch = result.match(/(\d+)\s+passed/);
    const failMatch = result.match(/(\d+)\s+failed/);
    const pass = passMatch ? passMatch[1] : "0";
    const fail = failMatch ? failMatch[1] : "0";
    return { icon: "🧪", text: `${pass} pass, ${fail} fail` };
  }

  // git commit
  if (/\bgit\s+commit\b/.test(detail)) {
    const hashMatch = result.match(/\[[^\]]*\s+([a-f0-9]{6,8})\]/);
    const hash = hashMatch ? hashMatch[1] : "";
    return { icon: "📝", text: hash ? `committed ${hash}` : "committed" };
  }

  // git push
  if (/\bgit\s+push\b/.test(detail)) {
    const branchMatch = detail.match(/git\s+push(?:\s+\S+)?\s+(\S+)/);
    const branch = branchMatch ? branchMatch[1] : "";
    return { icon: "📝", text: branch ? `pushed to ${branch}` : "pushed" };
  }

  return null;
}

// ── 1. AssistantBubble ──

const AssistantBubble = memo(function AssistantBubble({
  content,
  agentId,
  agentName,
}: {
  content: string;
  agentId: string;
  agentName: string;
}) {
  return (
    <div className="flex items-start gap-2 max-w-[90%]">
      <Avatar id={agentId} size="w-8 h-8 text-xs" />
      <div className="bg-slate-800 rounded-xl rounded-tl-sm px-3 py-2 min-w-0 flex-1">
        <span className="text-xs text-slate-500 font-medium">{agentName}</span>
        <div className="prose prose-invert prose-sm max-w-none text-[13px] leading-[1.5] text-slate-300 mt-0.5 break-words [&_p]:my-1 [&_ul]:my-1 [&_ol]:my-1 [&_li]:my-0.5 [&_code]:bg-slate-700/50 [&_code]:px-1 [&_code]:rounded [&_code]:text-[12px] [&_pre]:bg-slate-900/50 [&_pre]:p-2 [&_pre]:rounded [&_pre]:text-[12px] [&_pre]:overflow-x-auto [&_h1]:text-sm [&_h2]:text-sm [&_h3]:text-xs [&_a]:text-sky-400 [&_table]:block [&_table]:overflow-x-auto [&_table]:max-w-full [&_table]:border-collapse [&_table]:my-2 [&_table]:text-[12px] [&_th]:border [&_th]:border-slate-600 [&_th]:px-2 [&_th]:py-1 [&_th]:bg-slate-700/50 [&_th]:text-left [&_th]:font-semibold [&_th]:whitespace-nowrap [&_td]:border [&_td]:border-slate-600 [&_td]:px-2 [&_td]:py-0.5 [&_tr:nth-child(even)]:bg-slate-800/30 [&_hr]:max-w-full [&_hr]:border-slate-700">
          <Markdown remarkPlugins={[remarkGfm, remarkBreaks]}>{content}</Markdown>
        </div>
      </div>
    </div>
  );
});

// ── 2. ToolWorkflowBlock ──

function AgentNestedOutput({ result }: { result: string }) {
  const [expanded, setExpanded] = useState(false);

  const lines = result.split("\n");
  const nestedEntries: Array<{ type: "text" | "marker"; content: string }> = [];
  for (const line of lines) {
    const trimmed = line.trim();
    const markerMatch = trimmed.match(/^●\s(.*)$/);
    if (markerMatch) {
      nestedEntries.push({ type: "marker", content: markerMatch[1] });
    } else if (trimmed) {
      nestedEntries.push({ type: "text", content: trimmed });
    }
  }

  const stepCount = nestedEntries.filter(e => e.type === "marker").length;

  return (
    <div className="mt-1 ml-3 border-l-2 border-sky-700/40 pl-2">
      <button
        onClick={() => setExpanded(!expanded)}
        className="flex items-center gap-1 text-[11px] text-slate-500 hover:text-slate-300 transition-colors cursor-pointer"
      >
        <span className="select-none">{expanded ? "▼" : "▶"}</span>
        <span>サブエージェント出力{stepCount > 0 ? ` (${stepCount} ステップ)` : ""}</span>
      </button>
      {expanded && (
        <div className="mt-1 space-y-0.5">
          {nestedEntries.map((entry, idx) => (
            <div key={idx} className="text-[11px] font-mono">
              {entry.type === "marker" ? (
                <div className="flex items-start gap-1 text-slate-400">
                  <span className="text-sky-500 select-none shrink-0">●</span>
                  <span className="break-words">{entry.content}</span>
                </div>
              ) : (
                <div className="text-slate-600 ml-3 break-words">{entry.content}</div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ToolDetail({ tool }: { tool: ToolCall }) {
  const [showResult, setShowResult] = useState(false);
  const [showYamlDetail, setShowYamlDetail] = useState(false);
  const [showBashDetail, setShowBashDetail] = useState(false);

  // inbox_write card: Bash with inbox_write.sh in detail
  const isInboxWrite =
    tool.label === "Bash" && tool.detail.includes("inbox_write.sh");
  if (isInboxWrite) {
    // Extract sender → target from result: "[...] [inbox_write] SUCCESS: miho → darjeeling"
    const match = tool.result?.match(
      /\[inbox_write\]\s+SUCCESS:\s+(\w+)\s+[→\-]+\s+(\w+)/
    );
    const sender = match ? match[1] : null;
    const target = match ? match[2] : null;
    const failed = tool.result?.includes("FAIL") || (!match && !!tool.result);

    return (
      <div className="ml-3">
        <div className="flex items-center gap-1.5 text-[12px] font-mono">
          <span className="text-slate-600 select-none">├</span>
          <div
            className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-lg border ${
              failed
                ? "bg-red-950/30 border-red-700/40"
                : "bg-slate-800/80 border-slate-700/50"
            }`}
          >
            <span>📨</span>
            {sender && target ? (
              <>
                <span className="text-slate-300">
                  {getAgentDisplayName(sender)}
                </span>
                <span className="text-slate-500 text-[11px]">→</span>
                <span className="text-sky-400">
                  {getAgentDisplayName(target)}
                </span>
              </>
            ) : (
              <span className={failed ? "text-red-400" : "text-slate-400"}>
                {failed ? "送信失敗" : "inbox_write"}
              </span>
            )}
          </div>
        </div>
      </div>
    );
  }

  // Agent nested output: show structured collapsible view
  if (tool.label === "Agent" && tool.result && /●\s/.test(tool.result)) {
    return (
      <div className="ml-3">
        <div className="flex items-center gap-1.5 text-[12px] text-slate-400 font-mono">
          <span className="text-slate-600 select-none">├</span>
          <span>🤖</span>
          <span className="text-slate-300">Agent({tool.detail})</span>
        </div>
        <AgentNestedOutput result={tool.result} />
      </div>
    );
  }

  // YAML write/edit: Write/Edit/Update on .yaml/.yml files → summary display
  const yamlFileMatch =
    ["Write", "Edit", "Update"].includes(tool.label)
      ? tool.detail.match(/([^/\s,()]+\.ya?ml)/i)
      : null;
  const yamlFileName = yamlFileMatch ? yamlFileMatch[1] : null;

  if (yamlFileName) {
    return (
      <div className="ml-3">
        <div className="flex items-center gap-1.5 text-[12px] text-slate-400 font-mono">
          <span className="text-slate-600 select-none">├</span>
          <span>📝</span>
          <span className="text-slate-300">{yamlFileName} を更新</span>
          <button
            onClick={() => setShowYamlDetail(!showYamlDetail)}
            className="text-[10px] text-slate-600 hover:text-slate-400 transition-colors cursor-pointer ml-auto shrink-0"
          >
            {showYamlDetail ? "▼" : "▶"}
          </button>
        </div>
        {showYamlDetail && (
          <pre className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[20vh] overflow-y-auto border-l border-slate-700 pl-2">
            {tool.detail}
            {tool.result && `\n---\n${tool.result}`}
          </pre>
        )}
      </div>
    );
  }

  // Bash command summary: detect type and show structured summary
  if (tool.label === "Bash" && tool.result) {
    const bashSummary = parseBashSummary(tool.detail, tool.result);
    if (bashSummary) {
      return (
        <div className="ml-3">
          <div className="flex items-center gap-1.5 text-[12px] text-slate-400 font-mono">
            <span className="text-slate-600 select-none">├</span>
            <span>{bashSummary.icon}</span>
            <span className="text-slate-300">{bashSummary.text}</span>
            {bashSummary.errorDetails && (
              <span className="text-red-400 truncate max-w-[240px] text-[11px]">
                {bashSummary.errorDetails}
              </span>
            )}
            <button
              onClick={() => setShowBashDetail(!showBashDetail)}
              className="text-[10px] text-slate-600 hover:text-slate-400 transition-colors cursor-pointer ml-auto shrink-0"
            >
              {showBashDetail ? "▼" : "▶"}
            </button>
          </div>
          {showBashDetail && (
            <pre className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[20vh] overflow-y-auto border-l border-slate-700 pl-2">
              {tool.detail}
              {`\n---\n${tool.result}`}
            </pre>
          )}
        </div>
      );
    }
  }

  return (
    <div className="ml-3">
      <div className="flex items-center gap-1.5 text-[12px] text-slate-400 font-mono">
        <span className="text-slate-600 select-none">├</span>
        <span>{tool.icon}</span>
        <span className="text-slate-300">{tool.label}</span>
        <span className="text-slate-500 truncate max-w-[300px]">{tool.detail}</span>
        {tool.result && (
          <button
            onClick={() => setShowResult(!showResult)}
            className="text-[10px] text-slate-600 hover:text-slate-400 transition-colors cursor-pointer ml-auto shrink-0"
          >
            {showResult ? "▼" : "▶"}
          </button>
        )}
      </div>
      {showResult && tool.result && (
        tool.result.includes("diff --git ") ? (
          <DiffFoldView raw={tool.result} />
        ) : tool.label === "Read" ? (
          <TruncatedToolResult content={tool.result} />
        ) : (
          <pre className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[20vh] overflow-y-auto border-l border-slate-700 pl-2">
            {tool.result}
          </pre>
        )
      )}
    </div>
  );
}

const ToolWorkflowBlock = memo(function ToolWorkflowBlock({
  tools,
  agentName,
}: {
  tools: ToolCall[];
  agentName: string;
}) {
  const [expanded, setExpanded] = useState(false);

  const headerLabel =
    tools.length === 1
      ? `${tools[0].icon} ${agentName} が ${tools[0].label} を実行`
      : `🔧 ${agentName} が ${tools.length}件のツールを実行`;

  return (
    <div className="my-1 mx-2 border border-dashed border-slate-700/60 rounded-lg bg-slate-800/50 overflow-hidden">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full px-3 py-1.5 flex items-center gap-2 text-[12px] text-slate-400 hover:text-slate-300 transition-colors cursor-pointer"
      >
        <span className="text-[10px] select-none">{expanded ? "▼" : "▶"}</span>
        <span className="font-mono">{headerLabel}</span>
      </button>
      {expanded && (
        <div className="px-2 pb-2 space-y-0.5">
          {tools.map((tool, idx) => (
            <ToolDetail key={idx} tool={tool} />
          ))}
        </div>
      )}
    </div>
  );
});

// ── 3. UserInputBubble ──

const GUP_IMAGE_RE = /(\/tmp\/gup-upload-[^\s\n]+\.(?:png|jpe?g|gif|webp))/gi;

/** Split text into text/image-path segments */
function splitImagePaths(text: string): Array<{ type: "text" | "image"; value: string }> {
  const parts: Array<{ type: "text" | "image"; value: string }> = [];
  let last = 0;
  let match: RegExpExecArray | null;
  const re = new RegExp(GUP_IMAGE_RE.source, "gi");
  while ((match = re.exec(text)) !== null) {
    if (match.index > last) {
      parts.push({ type: "text", value: text.slice(last, match.index) });
    }
    parts.push({ type: "image", value: match[1] });
    last = re.lastIndex;
  }
  if (last < text.length) {
    parts.push({ type: "text", value: text.slice(last) });
  }
  return parts;
}

const UserInputBubble = memo(function UserInputBubble({
  content,
}: {
  content: string;
}) {
  // Remove leading ❯ if present
  const text = content.replace(/^❯\s*/, "");
  const isSlashCommand = text.startsWith("/");
  const segments = splitImagePaths(text);
  const hasImages = segments.some((s) => s.type === "image");

  return (
    <div className="flex justify-end my-1">
      <div
        className={`max-w-[75%] rounded-xl rounded-tr-sm px-3 py-1.5 ${
          isSlashCommand
            ? "bg-violet-700/80 border border-violet-500/40"
            : "bg-sky-600"
        }`}
      >
        {hasImages ? (
          <div className="flex flex-col gap-1.5">
            {segments.map((seg, i) =>
              seg.type === "image" ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  key={i}
                  src={`/api/image?path=${encodeURIComponent(seg.value)}`}
                  alt={seg.value.split("/").pop()}
                  className="max-w-[200px] max-h-[150px] rounded object-contain border border-white/20"
                />
              ) : seg.value.trim() ? (
                <span key={i} className="text-[13px] text-white font-mono">
                  {isSlashCommand ? "🔧 " : "❯ "}
                  {seg.value.trim()}
                </span>
              ) : null
            )}
          </div>
        ) : (
          <span className="text-[13px] text-white font-mono">
            {isSlashCommand ? "🔧 " : "❯ "}
            {text}
          </span>
        )}
      </div>
    </div>
  );
});

// ── 4. SessionDurationBadge ──

const SessionDurationBadge = memo(function SessionDurationBadge({
  duration,
}: {
  duration: string;
}) {
  return (
    <div className="flex justify-center my-1">
      <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-slate-700/50 text-[11px] text-slate-400 font-mono">
        <span>⏱</span>
        <span>{duration}</span>
      </span>
    </div>
  );
});

// ── 5. RawFallback ──

const RawFallback = memo(function RawFallback({
  content,
}: {
  content: string;
}) {
  return (
    <pre className="text-[12px] leading-[1.4] text-slate-500 font-mono whitespace-pre-wrap break-words bg-slate-800/30 rounded px-2 py-1 my-0.5 max-w-full overflow-x-auto">
      {content}
    </pre>
  );
});

// ── Main Renderer ──

export const BlockRenderer = memo(function BlockRenderer({
  blocks,
  agentId,
  agentName,
}: {
  blocks: ParsedBlock[];
  agentId: string;
  agentName: string;
}) {
  if (blocks.length === 0) return null;

  return (
    <>
      {blocks.map((block, i) => {
        switch (block.type) {
          case "assistant-text":
            return (
              <AssistantBubble
                key={i}
                content={block.content}
                agentId={agentId}
                agentName={agentName}
              />
            );
          case "tool-execution":
            return (
              <ToolWorkflowBlock
                key={i}
                tools={block.tools}
                agentName={block.agentName}
              />
            );
          case "user-input":
            return <UserInputBubble key={i} content={block.content} />;
          case "session-duration":
            return <SessionDurationBadge key={i} duration={block.duration} />;
          case "raw":
            return <RawFallback key={i} content={block.content} />;
        }
      })}
    </>
  );
});
