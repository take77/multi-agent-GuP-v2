"use client";

import React, { useState, memo } from "react";

// ── Types ──

interface DiffFile {
  header: string; // e.g. "a/src/foo.ts b/src/foo.ts"
  filePath: string; // e.g. "src/foo.ts"
  added: number;
  removed: number;
  chunks: string[]; // raw diff lines for this file
}

// ── Parser ──

function parseDiff(raw: string): DiffFile[] {
  const lines = raw.split("\n");
  const files: DiffFile[] = [];
  let current: DiffFile | null = null;

  for (const line of lines) {
    if (line.startsWith("diff --git ")) {
      if (current) files.push(current);
      const header = line.slice("diff --git ".length);
      // Extract file path: "a/src/foo.ts b/src/foo.ts" → "src/foo.ts"
      const match = header.match(/^a\/(.+?) b\/.+$/);
      const filePath = match ? match[1] : header;
      current = { header, filePath, added: 0, removed: 0, chunks: [line] };
    } else if (current) {
      current.chunks.push(line);
      if (line.startsWith("+") && !line.startsWith("+++")) {
        current.added++;
      } else if (line.startsWith("-") && !line.startsWith("---")) {
        current.removed++;
      }
    }
  }
  if (current) files.push(current);
  return files;
}

// ── DiffLine ──

const DiffLine = memo(function DiffLine({ line }: { line: string }) {
  if (line.startsWith("+") && !line.startsWith("+++")) {
    return (
      <div className="bg-emerald-950/60 text-emerald-300 px-1">
        {line}
      </div>
    );
  }
  if (line.startsWith("-") && !line.startsWith("---")) {
    return (
      <div className="bg-red-950/60 text-red-300 px-1">
        {line}
      </div>
    );
  }
  if (line.startsWith("@@")) {
    return (
      <div className="text-sky-400/80 px-1 text-[10px]">
        {line}
      </div>
    );
  }
  if (line.startsWith("diff --git") || line.startsWith("index ") || line.startsWith("---") || line.startsWith("+++")) {
    return (
      <div className="text-slate-600 px-1 text-[10px]">
        {line}
      </div>
    );
  }
  return (
    <div className="text-slate-400 px-1">
      {line}
    </div>
  );
});

// ── FileDiffBlock ──

const FileDiffBlock = memo(function FileDiffBlock({ file }: { file: DiffFile }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="border border-slate-700/50 rounded overflow-hidden">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full px-2 py-1 flex items-center gap-2 text-[12px] bg-slate-800/60 hover:bg-slate-700/60 transition-colors cursor-pointer"
      >
        <span className="text-[9px] text-slate-500 select-none">{expanded ? "▼" : "▶"}</span>
        <span className="text-slate-400 font-mono truncate flex-1 text-left">{file.filePath}</span>
        <span className="text-emerald-400 shrink-0 text-[11px]">+{file.added}</span>
        <span className="text-red-400 shrink-0 text-[11px] ml-0.5">-{file.removed}</span>
      </button>
      {expanded && (
        <pre className="text-[11px] leading-[1.35] font-mono whitespace-pre-wrap break-words max-h-[40vh] overflow-y-auto">
          {file.chunks.map((line, i) => (
            <DiffLine key={i} line={line} />
          ))}
        </pre>
      )}
    </div>
  );
});

// ── DiffFoldView ──

export const DiffFoldView = memo(function DiffFoldView({ raw }: { raw: string }) {
  const files = parseDiff(raw);

  if (files.length === 0) {
    return (
      <pre className="text-[11px] leading-[1.3] text-slate-500 font-mono whitespace-pre-wrap break-words max-h-[20vh] overflow-y-auto border-l border-slate-700 pl-2">
        {raw}
      </pre>
    );
  }

  const totalAdded = files.reduce((s, f) => s + f.added, 0);
  const totalRemoved = files.reduce((s, f) => s + f.removed, 0);

  return (
    <div className="ml-6 mt-0.5 space-y-0.5">
      <div className="text-[11px] text-slate-500 font-mono mb-1">
        {files.length}ファイル変更
        <span className="text-emerald-400 ml-1">+{totalAdded}</span>
        <span className="text-red-400 ml-0.5">-{totalRemoved}</span>
      </div>
      {files.map((file, i) => (
        <FileDiffBlock key={i} file={file} />
      ))}
    </div>
  );
});
