"use client";

import React, { useState } from "react";

const TRUNCATE_THRESHOLD = 20;
const HEAD_LINES = 5;
const TAIL_LINES = 5;

/**
 * TruncatedToolResult
 *
 * Read ツール結果など長いテキストを truncate 表示するコンポーネント。
 * - 20行超の場合: 先頭5行 + 「... N行省略 ...」 + 末尾5行
 * - 「全文表示」ボタンで展開可能
 * - 展開後: max-height 400px + overflow-y auto でスクロール制御
 */
export function TruncatedToolResult({ content }: { content: string }) {
  const [expanded, setExpanded] = useState(false);

  const lines = content.split("\n");
  const shouldTruncate = lines.length > TRUNCATE_THRESHOLD;

  if (!shouldTruncate || expanded) {
    return (
      <div className="relative">
        <pre
          className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words border-l border-slate-700 pl-2"
          style={
            expanded && shouldTruncate
              ? { maxHeight: "400px", overflowY: "auto" }
              : undefined
          }
        >
          {content}
        </pre>
        {expanded && shouldTruncate && (
          <button
            onClick={() => setExpanded(false)}
            className="mt-0.5 ml-6 text-[10px] text-slate-600 hover:text-slate-400 transition-colors cursor-pointer"
          >
            ▲ 折りたたむ
          </button>
        )}
      </div>
    );
  }

  const omittedCount = lines.length - HEAD_LINES - TAIL_LINES;
  const headText = lines.slice(0, HEAD_LINES).join("\n");
  const tailText = lines.slice(lines.length - TAIL_LINES).join("\n");

  return (
    <div>
      <pre className="mt-0.5 ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words border-l border-slate-700 pl-2">
        {headText}
      </pre>
      <div className="ml-6 my-0.5 flex items-center gap-2">
        <span className="text-[10px] text-slate-600 font-mono pl-2">
          ... {omittedCount}行省略 ...
        </span>
        <button
          onClick={() => setExpanded(true)}
          className="text-[10px] text-sky-600 hover:text-sky-400 transition-colors cursor-pointer border border-sky-700/50 hover:border-sky-500/50 rounded px-1.5 py-0.5"
        >
          全文表示
        </button>
      </div>
      <pre className="ml-6 text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words border-l border-slate-700 pl-2">
        {tailText}
      </pre>
    </div>
  );
}
