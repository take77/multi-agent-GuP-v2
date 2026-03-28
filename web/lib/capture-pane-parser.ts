/**
 * capture-pane-parser.ts
 *
 * Claude Code の capture-pane 出力を構造化セグメントに分割するパーサー。
 * 純粋関数として実装し、副作用を持たない。
 */

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

// ── Pattern matchers ──

const RE_USER_INPUT = /^❯\s+(.*)$/;
const RE_ASSISTANT_TEXT = /^●\s(.*)$/;
const RE_TOOL_RESULT = /^⎿\s(.*)$/;
const RE_BASH_CALL = /^Bash\((.+)\)\s*$/;
const RE_READ_CALL = /^Read\((.+)\)\s*$/;
const RE_READING_FILES = /^Reading?\s+\d+\s+file/;
const RE_READ_COLLAPSED = /^Read\s+\d+\s+file.*\(ctrl\+o/i;
const RE_UPDATE_CALL = /^Update\((.+)\)\s*$/;
const RE_WRITE_CALL = /^Write\((.+)\)\s*$/;
const RE_EDIT_CALL = /^Edit\((.+)\)\s*$/;
const RE_GLOB_CALL = /^Glob\((.+)\)\s*$/;
const RE_GREP_CALL = /^Grep\((.+)\)\s*$/;
const RE_AGENT_CALL = /^Agent\((.+)\)\s*$/;
const RE_TODO_CALL = /^Todo(?:Write|Read)\((.+)\)\s*$/;
const RE_TOOL_SEARCH_CALL = /^ToolSearch\((.+)\)\s*$/;
const RE_COGITATE = /^✻\s+(?:Cogitated|Churned)\s+for\s+/;
const RE_SEPARATOR = /^[─]{4,}/;
const RE_STATUS_BAR = /^⏵⏵\s+/;
const RE_INBOX_NUDGE = /^inbox\d+$/;

// Session start / banner patterns → status (hidden)
// Only match rounded-corner chars used by Claude Code's session banner (╭╮╰╯)
// Table chars (┌├│└┐┤┘┬┴┼) are NOT hidden — they appear in data tables
const RE_BOX_BORDER = /^[╭╰╮╯╠╣╦╩╪]{1}/;
const RE_REMOTE_URL = /^https?:\/\//;
const RE_QUESTION_PROMPT = /^\?\s+/;
const RE_SESSION_LINE = /^(?:Human turn|claude-code|Claude Code|Session|Loading|Initializing)/i;
const RE_TOGGLE_LINE = /^(?:Bypass permissions|Auto-accept|Fast mode|Model:)\s/i;

/**
 * Check if a trimmed line is a known marker that should break continuation.
 */
function isMarkerLine(trimmed: string): boolean {
  return (
    RE_USER_INPUT.test(trimmed) ||
    RE_ASSISTANT_TEXT.test(trimmed) ||
    RE_SEPARATOR.test(trimmed) ||
    RE_STATUS_BAR.test(trimmed) ||
    RE_INBOX_NUDGE.test(trimmed) ||
    RE_COGITATE.test(trimmed)
  );
}

/**
 * Try to parse a line as a tool call. Returns a ParsedSegment or null.
 */
function tryParseToolCall(trimmed: string): ParsedSegment | null {
  const bashMatch = trimmed.match(RE_BASH_CALL);
  if (bashMatch) {
    return { kind: "tool-call", text: trimmed, tool: "bash", command: bashMatch[1] };
  }

  const readMatch = trimmed.match(RE_READ_CALL);
  if (readMatch) {
    return { kind: "tool-call", text: trimmed, tool: "read", filePath: readMatch[1] };
  }

  if (RE_READING_FILES.test(trimmed) || RE_READ_COLLAPSED.test(trimmed)) {
    return { kind: "tool-call", text: trimmed, tool: "read" };
  }

  const updateMatch = trimmed.match(RE_UPDATE_CALL);
  if (updateMatch) {
    return { kind: "tool-call", text: trimmed, tool: "edit", filePath: updateMatch[1] };
  }

  const writeMatch = trimmed.match(RE_WRITE_CALL);
  if (writeMatch) {
    return { kind: "tool-call", text: trimmed, tool: "edit", filePath: writeMatch[1] };
  }

  const editMatch = trimmed.match(RE_EDIT_CALL);
  if (editMatch) {
    return { kind: "tool-call", text: trimmed, tool: "edit", filePath: editMatch[1] };
  }

  const globMatch = trimmed.match(RE_GLOB_CALL);
  if (globMatch) {
    return { kind: "tool-call", text: trimmed, tool: "read" };
  }

  const grepMatch = trimmed.match(RE_GREP_CALL);
  if (grepMatch) {
    return { kind: "tool-call", text: trimmed, tool: "read" };
  }

  if (RE_AGENT_CALL.test(trimmed) || RE_TODO_CALL.test(trimmed) || RE_TOOL_SEARCH_CALL.test(trimmed)) {
    return { kind: "tool-call", text: trimmed, tool: "bash" };
  }

  // Multi-line tool calls: tool name + open paren without closing paren on same line
  // e.g., "Bash(bash scripts/inbox_write.sh miho "very long command..."
  const multiLineMatch = trimmed.match(/^(Bash|Read|Update|Write|Edit|Glob|Grep|Agent|ToolSearch|TodoWrite|TodoRead)\((.*)$/);
  if (multiLineMatch) {
    const toolName = multiLineMatch[1].toLowerCase();
    const toolMap: Record<string, string> = {
      bash: "bash", read: "read", update: "edit", write: "edit",
      edit: "edit", glob: "read", grep: "read", agent: "bash",
      toolsearch: "bash", todowrite: "bash", todoread: "bash",
    };
    return {
      kind: "tool-call",
      text: trimmed,
      tool: toolMap[toolName] || "bash",
      command: toolName === "bash" ? multiLineMatch[2] : undefined,
      filePath: ["update", "write", "edit", "read"].includes(toolName) ? multiLineMatch[2].replace(/\)\s*$/, "") : undefined,
    };
  }

  return null;
}

/**
 * capture-pane 出力を構造化セグメントの配列にパースする。
 */
export function parseCapturePaneOutput(raw: string): ParsedSegment[] {
  const lines = raw.split("\n");
  const segments: ParsedSegment[] = [];
  let i = 0;

  // Strip trailing prompt line (❯ or similar)
  while (lines.length > 0) {
    const last = lines[lines.length - 1].trim();
    if (last === "") {
      lines.pop();
      continue;
    }
    if (/[❯$%>]\s*$/.test(last) || /^\s*[\w.~\/-]*[❯$%>]\s*$/.test(last)) {
      lines.pop();
      break;
    }
    break;
  }

  while (i < lines.length) {
    const line = lines[i];
    const trimmed = line.trim();

    // Skip empty lines
    if (trimmed === "") {
      i++;
      continue;
    }

    // Skip inbox nudge patterns
    if (RE_INBOX_NUDGE.test(trimmed)) {
      i++;
      continue;
    }

    // ❯ command → user input (may span multiple lines)
    const userMatch = trimmed.match(RE_USER_INPUT);
    if (userMatch) {
      const inputLines = [userMatch[1]];
      i++;
      // Continuation: lines that don't start with a known marker
      while (i < lines.length) {
        const next = lines[i].trim();
        if (next === "" || isMarkerLine(next) || tryParseToolCall(next)) {
          break;
        }
        // Check if it's a tool result (⎿) — that means agent started responding
        if (RE_TOOL_RESULT.test(next)) break;
        inputLines.push(lines[i].trim());
        i++;
      }
      segments.push({ kind: "user-input", text: inputLines.join("\n") });
      continue;
    }

    // ● text → assistant text OR tool call prefixed with ●
    const assistantMatch = trimmed.match(RE_ASSISTANT_TEXT);
    if (assistantMatch) {
      const content = assistantMatch[1];

      // Check if ● is followed by a tool call pattern (e.g., "● Bash(...)")
      const toolSeg = tryParseToolCall(content);
      if (toolSeg) {
        // Collect indented continuation lines for multi-line tool calls
        const callLines = [content];
        i++;
        while (i < lines.length) {
          const next = lines[i];
          const nextTrimmed = next.trim();
          if (/^\s{4,}/.test(next) && !RE_TOOL_RESULT.test(nextTrimmed) && !isMarkerLine(nextTrimmed)) {
            callLines.push(nextTrimmed);
            i++;
          } else {
            break;
          }
        }
        if (callLines.length > 1) {
          toolSeg.text = callLines.join(" ");
          if (toolSeg.command) {
            toolSeg.command = callLines.join(" ").replace(/^Bash\(/, "").replace(/\)\s*$/, "");
          }
        }
        segments.push(toolSeg);
        continue;
      }

      // Regular assistant text — collect continuation lines (including across empty lines)
      const textLines = [content];
      i++;
      while (i < lines.length) {
        const next = lines[i].trim();

        // Marker lines always break continuation
        if (isMarkerLine(next)) break;

        // Tool call patterns break continuation
        if (tryParseToolCall(next)) break;

        // ⎿ tool result breaks continuation
        if (RE_TOOL_RESULT.test(next)) break;

        // Empty line: peek ahead to decide if this is a paragraph break within
        // the same assistant message, or the end of the assistant block
        if (next === "") {
          // Look ahead for the next non-empty line
          let peek = i + 1;
          while (peek < lines.length && lines[peek].trim() === "") peek++;
          if (peek >= lines.length) break;
          const peekTrimmed = lines[peek].trim();
          // If next non-empty is a marker or tool call → end here
          if (isMarkerLine(peekTrimmed) || tryParseToolCall(peekTrimmed) || RE_TOOL_RESULT.test(peekTrimmed)) {
            break;
          }
          // Otherwise, include the empty line as paragraph separator
          textLines.push("");
          i++;
          continue;
        }

        // Box border / session lines: these break if at the start of a new section
        if (
          RE_BOX_BORDER.test(next) ||
          RE_SESSION_LINE.test(next) ||
          RE_TOGGLE_LINE.test(next)
        ) {
          break;
        }

        textLines.push(lines[i]);
        i++;
      }
      segments.push({ kind: "assistant-text", text: textLines.join("\n") });
      continue;
    }

    // ⎿ text → tool result (may have indented continuation)
    const toolResultMatch = trimmed.match(RE_TOOL_RESULT);
    if (toolResultMatch) {
      const resultLines = [toolResultMatch[1]];
      i++;
      while (i < lines.length) {
        const next = lines[i];
        const nextTrimmed = next.trim();
        // Continuation: indented lines or lines starting with ⎿
        if (/^\s{2,}/.test(next) || /^⎿/.test(nextTrimmed)) {
          const m = nextTrimmed.match(RE_TOOL_RESULT);
          resultLines.push(m ? m[1] : next);
          i++;
        } else {
          break;
        }
      }
      segments.push({ kind: "tool-result", text: resultLines.join("\n") });
      continue;
    }

    // Standalone tool calls (without ● prefix — less common but possible)
    const toolCallSeg = tryParseToolCall(trimmed);
    if (toolCallSeg) {
      // Collect indented continuation lines (multi-line tool calls)
      const callLines = [trimmed];
      i++;
      while (i < lines.length) {
        const next = lines[i];
        const nextTrimmed = next.trim();
        // Indented continuation of the tool call (not ⎿ result, not a new marker)
        if (/^\s{4,}/.test(next) && !RE_TOOL_RESULT.test(nextTrimmed) && !isMarkerLine(nextTrimmed)) {
          callLines.push(nextTrimmed);
          i++;
        } else {
          break;
        }
      }
      if (callLines.length > 1) {
        toolCallSeg.text = callLines.join(" ");
        if (toolCallSeg.command) {
          toolCallSeg.command = callLines.join(" ").replace(/^Bash\(/, "").replace(/\)\s*$/, "");
        }
      }
      segments.push(toolCallSeg);
      continue;
    }

    // ✻ Cogitated/Churned → status
    if (RE_COGITATE.test(trimmed)) {
      segments.push({ kind: "status", text: trimmed });
      i++;
      continue;
    }

    // ──── separator
    if (RE_SEPARATOR.test(trimmed)) {
      segments.push({ kind: "separator", text: trimmed });
      i++;
      continue;
    }

    // ⏵⏵ status bar
    if (RE_STATUS_BAR.test(trimmed)) {
      segments.push({ kind: "status-bar", text: trimmed });
      i++;
      continue;
    }

    // Session start / banner lines → status-bar (hidden)
    // Note: │ (table cell) is NOT matched here — only session frame characters
    if (
      RE_BOX_BORDER.test(trimmed) ||
      RE_REMOTE_URL.test(trimmed) ||
      RE_QUESTION_PROMPT.test(trimmed) ||
      RE_SESSION_LINE.test(trimmed) ||
      RE_TOGGLE_LINE.test(trimmed)
    ) {
      segments.push({ kind: "status-bar", text: trimmed });
      i++;
      continue;
    }

    // Fallback → raw
    segments.push({ kind: "raw", text: line });
    i++;
  }

  return segments;
}
