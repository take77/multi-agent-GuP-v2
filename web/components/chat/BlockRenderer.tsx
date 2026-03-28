"use client";

import React, { useState, memo } from "react";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import remarkBreaks from "remark-breaks";
import { Avatar } from "@/components/shared/Avatar";
import type { ParsedBlock, ToolCall } from "@/types/parsed-blocks";

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
      <Avatar id={agentId} size="w-6 h-6 text-[9px]" />
      <div className="bg-slate-800 rounded-xl rounded-tl-sm px-3 py-2 min-w-0 flex-1">
        <span className="text-[10px] text-slate-500 font-medium">{agentName}</span>
        <div className="prose prose-invert prose-sm max-w-none text-[13px] leading-[1.5] text-slate-300 mt-0.5 break-words [&_p]:my-1 [&_ul]:my-1 [&_ol]:my-1 [&_li]:my-0.5 [&_code]:bg-slate-700/50 [&_code]:px-1 [&_code]:rounded [&_code]:text-[12px] [&_pre]:bg-slate-900/50 [&_pre]:p-2 [&_pre]:rounded [&_pre]:text-[12px] [&_pre]:overflow-x-auto [&_h1]:text-sm [&_h2]:text-sm [&_h3]:text-xs [&_a]:text-sky-400 [&_table]:block [&_table]:overflow-x-auto [&_table]:max-w-full [&_table]:border-collapse [&_table]:my-2 [&_table]:text-[12px] [&_th]:border [&_th]:border-slate-600 [&_th]:px-2 [&_th]:py-1 [&_th]:bg-slate-700/50 [&_th]:text-left [&_th]:font-semibold [&_th]:whitespace-nowrap [&_td]:border [&_td]:border-slate-600 [&_td]:px-2 [&_td]:py-0.5 [&_tr:nth-child(even)]:bg-slate-800/30 [&_hr]:max-w-full [&_hr]:border-slate-700">
          <Markdown remarkPlugins={[remarkGfm, remarkBreaks]}>{content}</Markdown>
        </div>
      </div>
    </div>
  );
});

// ── 2. ToolWorkflowBlock ──

function ToolDetail({ tool }: { tool: ToolCall }) {
  const [showResult, setShowResult] = useState(false);

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
        <pre className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[20vh] overflow-y-auto border-l border-slate-700 pl-2">
          {tool.result}
        </pre>
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

const UserInputBubble = memo(function UserInputBubble({
  content,
}: {
  content: string;
}) {
  // Remove leading ❯ if present
  const text = content.replace(/^❯\s*/, "");
  const isSlashCommand = text.startsWith("/");

  return (
    <div className="flex justify-end my-1">
      <div
        className={`max-w-[75%] rounded-xl rounded-tr-sm px-3 py-1.5 ${
          isSlashCommand
            ? "bg-violet-700/80 border border-violet-500/40"
            : "bg-sky-600"
        }`}
      >
        <span className="text-[13px] text-white font-mono">
          {isSlashCommand ? "🔧 " : "❯ "}
          {text}
        </span>
      </div>
    </div>
  );
});

// ── 4. RawFallback ──

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
          case "raw":
            return <RawFallback key={i} content={block.content} />;
        }
      })}
    </>
  );
});
