/**
 * capture-pane-parser.ts
 *
 * Claude Code の capture-pane 出力を構造化ブロックに分割するパーサー。
 * トークナイザ → ブロックビルダー の2段階パイプライン。
 * 純粋関数として実装し、副作用を持たない。
 */

import type { ParsedBlock, ToolCall } from "@/types/parsed-blocks";

// Re-export types for UI consumption
export type { ParsedBlock, ToolCall } from "@/types/parsed-blocks";

// ── Legacy exports (backward compat until UI is updated by subtask_140_b) ──
export type SegmentKind =
  | "user-input"
  | "assistant-text"
  | "tool-call"
  | "tool-result"
  | "status"
  | "separator"
  | "status-bar"
  | "raw";

export interface ParsedSegment {
  kind: SegmentKind;
  text: string;
  tool?: string;
  command?: string;
  filePath?: string;
}

// ═══════════════════════════════════════════════════════════════
// Stage 1: Token definitions
// ═══════════════════════════════════════════════════════════════

type Token =
  | { type: "assistant-text"; text: string }
  | { type: "tool-call"; call: ToolCall }
  | { type: "tool-result"; text: string }
  | { type: "user-input"; text: string }
  | { type: "session-duration"; duration: string }
  | { type: "skip" }
  | { type: "raw"; text: string };

// ═══════════════════════════════════════════════════════════════
// Stage 1: Pattern matchers
// ═══════════════════════════════════════════════════════════════

// ── Skip patterns (completely filtered out) ──
const SKIP_PATTERNS = [
  /^[─━]{4,}/,                       // separator lines
  /^⏵⏵\s+/,                         // status bar
  /^▐▛/,                              // Claude Code ASCII banner
  /^\/remote-control/,                // session info
  /^[╭╰╮╯╠╣╦╩╪]/,                    // session banner frame (rounded corners)
  /^inbox\d+$/,                       // inbox nudge
  /^https?:\/\//,                     // remote URLs in session start
  /^\?\s+/,                           // question prompts
  /^(?:Human turn|claude-code|Claude Code|Session|Loading|Initializing)/i,
  /^(?:Bypass permissions|Auto-accept|Fast mode|Model:)\s/i,
  // "Worked for X" is now parsed as session-duration token (not skipped)
];

function isSkipLine(trimmed: string): boolean {
  return SKIP_PATTERNS.some((re) => re.test(trimmed));
}

// ── Tool call patterns ──

interface ToolPattern {
  re: RegExp;
  icon: string;
  label: string;
  extractDetail: (match: RegExpMatchArray) => string;
}

const TOOL_PATTERNS: ToolPattern[] = [
  { re: /^Bash\((.+)\)\s*$/, icon: "💻", label: "Bash", extractDetail: (m) => m[1] },
  { re: /^Read\((.+)\)\s*$/, icon: "📖", label: "Read", extractDetail: (m) => m[1] },
  { re: /^Update\((.+)\)\s*$/, icon: "📝", label: "Update", extractDetail: (m) => m[1] },
  { re: /^Write\((.+)\)\s*$/, icon: "📝", label: "Write", extractDetail: (m) => m[1] },
  { re: /^Edit\((.+)\)\s*$/, icon: "📝", label: "Edit", extractDetail: (m) => m[1] },
  { re: /^Glob\((.+)\)\s*$/, icon: "🔍", label: "Glob", extractDetail: (m) => m[1] },
  { re: /^Grep\((.+)\)\s*$/, icon: "🔍", label: "Grep", extractDetail: (m) => m[1] },
  { re: /^Agent\((.+)\)\s*$/, icon: "🤖", label: "Agent", extractDetail: (m) => m[1] },
  { re: /^ToolSearch\((.+)\)\s*$/, icon: "🔧", label: "ToolSearch", extractDetail: (m) => m[1] },
  { re: /^Todo(?:Write|Read)\((.+)\)\s*$/, icon: "📋", label: "Todo", extractDetail: (m) => m[1] },
];

// Multi-line tool call prefix (no closing paren)
const RE_TOOL_PREFIX = /^(Bash|Read|Update|Write|Edit|Glob|Grep|Agent|ToolSearch|TodoWrite|TodoRead)\((.*)$/;

// New-format tool indicators
const RE_NEW_TOOL_BASH = /^▶\s+\$\s+(.*)$/;
const RE_NEW_TOOL_EDIT = /^▶\s+🖊\s+Edit\s+(.*)$/;

// Read N file(s) patterns
const RE_READ_FILES = /^Read(?:ing)?\s+(\d+)\s+file/;

// Cogitate/think time
const RE_COGITATE = /^✻\s+(?:Cogitated|Churned|Crunched)\s+for\s+(.+)$/;

// Session duration ("Worked for X")
const RE_WORKED_FOR = /^✻\s+Worked\s+for\s+(.+)$/;

// Core markers
const RE_USER_INPUT = /^❯\s+(.*)$/;
const RE_ASSISTANT_TEXT = /^●\s(.*)$/;
const RE_TOOL_RESULT = /^⎿\s?(.*)$/;

// Diff line pattern: "108 - read: false" or "108 + read: true"
const RE_DIFF_LINE = /^\d+\s+[-+]\s/;

/**
 * Try to parse a trimmed line as a ToolCall.
 */
function tryParseToolCall(trimmed: string): ToolCall | null {
  for (const tp of TOOL_PATTERNS) {
    const m = trimmed.match(tp.re);
    if (m) {
      return { icon: tp.icon, label: tp.label, detail: tp.extractDetail(m) };
    }
  }

  // Multi-line tool call (open paren, no close)
  const prefixMatch = trimmed.match(RE_TOOL_PREFIX);
  if (prefixMatch) {
    const name = prefixMatch[1];
    const iconMap: Record<string, string> = {
      Bash: "💻", Read: "📖", Update: "📝", Write: "📝", Edit: "📝",
      Glob: "🔍", Grep: "🔍", Agent: "🤖", ToolSearch: "🔧",
      TodoWrite: "📋", TodoRead: "📋",
    };
    return { icon: iconMap[name] || "🔧", label: name, detail: prefixMatch[2] };
  }

  // New-format: ▶ $ command
  const newBashMatch = trimmed.match(RE_NEW_TOOL_BASH);
  if (newBashMatch) {
    return { icon: "💻", label: "Bash", detail: newBashMatch[1] };
  }

  // New-format: ▶ 🖊 Edit file
  const newEditMatch = trimmed.match(RE_NEW_TOOL_EDIT);
  if (newEditMatch) {
    return { icon: "📝", label: "Edit", detail: newEditMatch[1] };
  }

  // Read N file(s)
  const readFilesMatch = trimmed.match(RE_READ_FILES);
  if (readFilesMatch) {
    return { icon: "📖", label: "Read", detail: `${readFilesMatch[1]} file(s)` };
  }

  // Cogitate/think
  const cogMatch = trimmed.match(RE_COGITATE);
  if (cogMatch) {
    return { icon: "⏱", label: "Cogitated", detail: cogMatch[1] };
  }

  return null;
}

/**
 * Check if a trimmed line is a known marker (breaks assistant-text / user-input continuation).
 */
function isMarkerLine(trimmed: string): boolean {
  return (
    RE_USER_INPUT.test(trimmed) ||
    RE_ASSISTANT_TEXT.test(trimmed) ||
    RE_TOOL_RESULT.test(trimmed) ||
    isSkipLine(trimmed) ||
    RE_COGITATE.test(trimmed) ||
    RE_WORKED_FOR.test(trimmed) ||
    tryParseToolCall(trimmed) !== null
  );
}

// ═══════════════════════════════════════════════════════════════
// Stage 1: Tokenizer
// ═══════════════════════════════════════════════════════════════

function tokenize(raw: string): Token[] {
  const lines = raw.split("\n");
  const tokens: Token[] = [];
  let i = 0;

  // Strip trailing prompt + status bar
  while (lines.length > 0) {
    const last = lines[lines.length - 1].trim();
    if (last === "") { lines.pop(); continue; }
    if (/[❯$%>]\s*$/.test(last) || /^\s*[\w.~\/-]*[❯$%>]\s*$/.test(last)) {
      lines.pop(); break;
    }
    if (/^⏵⏵/.test(last)) { lines.pop(); continue; }
    break;
  }

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip empty lines (handled in block builder for paragraph detection)
    if (trimmed === "") { i++; continue; }

    // Skip patterns
    if (isSkipLine(trimmed)) { i++; continue; }

    // ✻ Worked for X → session-duration token
    const workedMatch = trimmed.match(RE_WORKED_FOR);
    if (workedMatch) {
      tokens.push({ type: "session-duration", duration: workedMatch[1] });
      i++;
      continue;
    }

    // ❯ user input (multi-line)
    const userMatch = trimmed.match(RE_USER_INPUT);
    if (userMatch) {
      const capturedText = userMatch[1].trim();

      // ❯ inbox1 等の inbox_watcher nudge はスキップ
      if (/^inbox\d+$/.test(capturedText)) {
        i++;
        continue;
      }

      const inputLines = [userMatch[1]];
      i++;
      // 空行があっても次の●/❯/ツールマーカーまでを1ブロックとして収集
      while (i < lines.length) {
        const next = lines[i].trim();
        if (isMarkerLine(next)) break;
        inputLines.push(lines[i]);
        i++;
      }
      // 末尾の空行を除去
      while (inputLines.length > 0 && inputLines[inputLines.length - 1].trim() === "") {
        inputLines.pop();
      }
      tokens.push({ type: "user-input", text: inputLines.join("\n") });
      continue;
    }

    // ● assistant text or ● tool call
    const assistantMatch = trimmed.match(RE_ASSISTANT_TEXT);
    if (assistantMatch) {
      const content = assistantMatch[1];

      // Check if ● is followed by a tool call
      const toolCall = tryParseToolCall(content);
      if (toolCall) {
        // Collect indented continuation for multi-line calls
        i++;
        const contLines = [content];
        while (i < lines.length) {
          const next = lines[i];
          const nextTrimmed = next.trim();
          if (/^\s{4,}/.test(next) && !RE_TOOL_RESULT.test(nextTrimmed) && !isSkipLine(nextTrimmed) && !RE_USER_INPUT.test(nextTrimmed) && !RE_ASSISTANT_TEXT.test(nextTrimmed)) {
            contLines.push(nextTrimmed);
            i++;
          } else {
            break;
          }
        }
        if (contLines.length > 1) {
          toolCall.detail = contLines.join(" ").replace(/^(?:Bash|Read|Update|Write|Edit|Glob|Grep|Agent|ToolSearch|TodoWrite|TodoRead)\(/, "").replace(/\)\s*$/, "");
        }
        tokens.push({ type: "tool-call", call: toolCall });
        continue;
      }

      // Regular assistant text — collect continuation
      const textLines = [content];
      i++;
      while (i < lines.length) {
        const next = lines[i].trim();
        if (isMarkerLine(next)) break;

        // Empty line: peek ahead
        if (next === "") {
          let peek = i + 1;
          while (peek < lines.length && lines[peek].trim() === "") peek++;
          if (peek >= lines.length) break;
          if (isMarkerLine(lines[peek].trim())) break;
          textLines.push("");
          i++;
          continue;
        }

        textLines.push(lines[i]);
        i++;
      }
      tokens.push({ type: "assistant-text", text: textLines.join("\n") });
      continue;
    }

    // ⎿ tool result
    const resultMatch = trimmed.match(RE_TOOL_RESULT);
    if (resultMatch) {
      const resultLines = [resultMatch[1]];
      i++;
      while (i < lines.length) {
        const next = lines[i];
        const nextTrimmed = next.trim();

        // 1. Indented content (2+ spaces) — continue collecting
        //    This handles nested Agent output where ● appears indented.
        //    Must be checked BEFORE core markers to avoid breaking on nested ●.
        if (/^\s{2,}/.test(next)) {
          // Don't swallow indented tool calls (e.g. "  Update(file.yaml)")
          if (tryParseToolCall(nextTrimmed) !== null) break;
          // ⎿ continuation within indented block
          const m = nextTrimmed.match(RE_TOOL_RESULT);
          resultLines.push(m ? m[1] : next);
          i++;
          continue;
        }

        // 2. ⎿ continuation at start of line
        if (/^⎿/.test(nextTrimmed) && resultLines.length > 0) {
          const m = nextTrimmed.match(RE_TOOL_RESULT);
          resultLines.push(m ? m[1] : next);
          i++;
          continue;
        }

        // 3. Core markers (non-indented) always end collection
        if (RE_USER_INPUT.test(nextTrimmed) || RE_ASSISTANT_TEXT.test(nextTrimmed)) break;

        // 4. Empty line + next is core marker → end
        if (nextTrimmed === "") {
          let peek = i + 1;
          while (peek < lines.length && lines[peek].trim() === "") peek++;
          if (peek >= lines.length) break;
          const peekTrimmed = lines[peek].trim();
          if (RE_USER_INPUT.test(peekTrimmed) || RE_ASSISTANT_TEXT.test(peekTrimmed) || tryParseToolCall(peekTrimmed) !== null) break;
          resultLines.push("");
          i++;
          continue;
        }

        // 5. Diff pattern lines (e.g. "108 - read: false") — continue collecting
        if (RE_DIFF_LINE.test(nextTrimmed)) {
          resultLines.push(next);
          i++;
          continue;
        }

        // 6. Standalone tool call at start of line — end
        if (tryParseToolCall(nextTrimmed) !== null) break;

        // 7. Other unindented lines — end
        break;
      }
      tokens.push({ type: "tool-result", text: resultLines.join("\n") });
      continue;
    }

    // Standalone tool call (without ● prefix)
    const standaloneToolCall = tryParseToolCall(trimmed);
    if (standaloneToolCall) {
      // Multi-line continuation
      i++;
      const contLines = [trimmed];
      while (i < lines.length) {
        const next = lines[i];
        const nextTrimmed = next.trim();
        if (/^\s{4,}/.test(next) && !RE_TOOL_RESULT.test(nextTrimmed) && !isSkipLine(nextTrimmed)) {
          contLines.push(nextTrimmed);
          i++;
        } else {
          break;
        }
      }
      if (contLines.length > 1) {
        standaloneToolCall.detail = contLines.join(" ").replace(/^(?:Bash|Read|Update|Write|Edit|Glob|Grep|Agent|ToolSearch|TodoWrite|TodoRead)\(/, "").replace(/\)\s*$/, "");
      }
      tokens.push({ type: "tool-call", call: standaloneToolCall });
      continue;
    }

    // Fallback → raw
    tokens.push({ type: "raw", text: line });
    i++;
  }

  return tokens;
}

// ═══════════════════════════════════════════════════════════════
// Stage 2: Block builder
// ═══════════════════════════════════════════════════════════════

function buildBlocks(tokens: Token[]): ParsedBlock[] {
  const blocks: ParsedBlock[] = [];

  let i = 0;
  while (i < tokens.length) {
    const tok = tokens[i];

    switch (tok.type) {
      case "assistant-text": {
        // Merge consecutive assistant-text tokens
        const texts = [tok.text];
        i++;
        while (i < tokens.length && tokens[i].type === "assistant-text") {
          texts.push((tokens[i] as { type: "assistant-text"; text: string }).text);
          i++;
        }
        blocks.push({ type: "assistant-text", content: texts.join("\n\n") });
        break;
      }

      case "tool-call": {
        // Merge consecutive tool-call + tool-result tokens into one tool-execution block
        const tools: ToolCall[] = [];
        while (i < tokens.length) {
          const cur = tokens[i];
          if (cur.type === "tool-call") {
            const call = { ...cur.call };
            i++;
            // Attach following tool-result to this call
            if (i < tokens.length && tokens[i].type === "tool-result") {
              call.result = (tokens[i] as { type: "tool-result"; text: string }).text;
              i++;
            }
            tools.push(call);
          } else {
            break;
          }
        }
        blocks.push({ type: "tool-execution", tools, agentName: "" });
        break;
      }

      case "tool-result": {
        // Orphaned tool result (no preceding tool-call) → raw
        blocks.push({ type: "raw", content: `⎿ ${tok.text}` });
        i++;
        break;
      }

      case "user-input": {
        blocks.push({ type: "user-input", content: tok.text });
        i++;
        break;
      }

      case "session-duration": {
        blocks.push({ type: "session-duration", duration: tok.duration });
        i++;
        break;
      }

      case "raw": {
        // Merge consecutive raw tokens
        const rawLines = [tok.text];
        i++;
        while (i < tokens.length && tokens[i].type === "raw") {
          rawLines.push((tokens[i] as { type: "raw"; text: string }).text);
          i++;
        }
        blocks.push({ type: "raw", content: rawLines.join("\n") });
        break;
      }

      case "skip":
        i++;
        break;
    }
  }

  return blocks;
}

// ═══════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════

/**
 * capture-pane 出力を構造化ブロックの配列にパースする。
 * 新しい ParsedBlock[] 型を返す。
 */
export function parseCapturePane(raw: string): ParsedBlock[] {
  const tokens = tokenize(raw);
  return buildBlocks(tokens);
}

/**
 * Legacy API — 旧 ParsedSegment[] を返す。
 * subtask_140_b で UI が更新されるまでの互換レイヤー。
 */
export function parseCapturePaneOutput(raw: string): ParsedSegment[] {
  const blocks = parseCapturePane(raw);
  const segments: ParsedSegment[] = [];

  for (const block of blocks) {
    switch (block.type) {
      case "assistant-text":
        segments.push({ kind: "assistant-text", text: block.content });
        break;

      case "tool-execution":
        for (const tool of block.tools) {
          const toolType = tool.label === "Bash" ? "bash"
            : ["Read", "Glob", "Grep"].includes(tool.label) ? "read"
            : ["Update", "Write", "Edit"].includes(tool.label) ? "edit"
            : "bash";
          segments.push({
            kind: "tool-call",
            text: `${tool.label}(${tool.detail})`,
            tool: toolType,
            command: tool.label === "Bash" ? tool.detail : undefined,
            filePath: ["Read", "Update", "Write", "Edit"].includes(tool.label) ? tool.detail : undefined,
          });
          if (tool.result) {
            segments.push({ kind: "tool-result", text: tool.result });
          }
        }
        break;

      case "user-input":
        segments.push({ kind: "user-input", text: block.content });
        break;

      case "raw":
        segments.push({ kind: "raw", text: block.content });
        break;
    }
  }

  return segments;
}

// Export tokenize for testing
export { tokenize as _tokenize, buildBlocks as _buildBlocks };
