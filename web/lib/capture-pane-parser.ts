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
const RE_READING_FILES = /^Reading\s+\d+\s+file/;
const RE_UPDATE_CALL = /^Update\((.+)\)\s*$/;
const RE_WRITE_CALL = /^Write\((.+)\)\s*$/;
const RE_EDIT_CALL = /^Edit\((.+)\)\s*$/;
const RE_GLOB_CALL = /^Glob\((.+)\)\s*$/;
const RE_GREP_CALL = /^Grep\((.+)\)\s*$/;
const RE_AGENT_CALL = /^Agent\((.+)\)\s*$/;
const RE_TODO_CALL = /^Todo(?:Write|Read)\((.+)\)\s*$/;
const RE_TOOL_SEARCH_CALL = /^ToolSearch\((.+)\)\s*$/;
const RE_COGITATE = /^✻\s+Cogitated\s+for\s+/;
const RE_SEPARATOR = /^[─]{4,}/;
const RE_STATUS_BAR = /^⏵⏵\s+/;
const RE_INBOX_NUDGE = /^inbox\d+$/;

// Session start / banner patterns → status (hidden)
const RE_BOX_BORDER = /^[╭╰├╮╯┤│╠╣╦╩╪]{1}/;
const RE_REMOTE_URL = /^https?:\/\//;
const RE_QUESTION_PROMPT = /^\?\s+/;
const RE_SESSION_LINE = /^(?:Human turn|claude-code|Claude Code|Session|Loading|Initializing)/i;
const RE_TOGGLE_LINE = /^(?:Bypass permissions|Auto-accept|Fast mode|Model:)\s/i;

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

    // ❯ command → user input
    const userMatch = trimmed.match(RE_USER_INPUT);
    if (userMatch) {
      segments.push({ kind: "user-input", text: userMatch[1] });
      i++;
      continue;
    }

    // ● text → assistant text (may span multiple lines)
    const assistantMatch = trimmed.match(RE_ASSISTANT_TEXT);
    if (assistantMatch) {
      const textLines = [assistantMatch[1]];
      i++;
      // Continuation: lines that don't start with a known marker
      while (i < lines.length) {
        const next = lines[i].trim();
        if (
          next === "" ||
          RE_USER_INPUT.test(next) ||
          RE_ASSISTANT_TEXT.test(next) ||
          RE_TOOL_RESULT.test(next) ||
          RE_BASH_CALL.test(next) ||
          RE_READ_CALL.test(next) ||
          RE_READING_FILES.test(next) ||
          RE_UPDATE_CALL.test(next) ||
          RE_WRITE_CALL.test(next) ||
          RE_EDIT_CALL.test(next) ||
          RE_GLOB_CALL.test(next) ||
          RE_GREP_CALL.test(next) ||
          RE_AGENT_CALL.test(next) ||
          RE_TODO_CALL.test(next) ||
          RE_TOOL_SEARCH_CALL.test(next) ||
          RE_COGITATE.test(next) ||
          RE_SEPARATOR.test(next) ||
          RE_STATUS_BAR.test(next) ||
          RE_INBOX_NUDGE.test(next)
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
        // Continuation: indented lines or lines starting with ⎿
        if (/^\s{2,}/.test(next) || /^⎿/.test(next.trim())) {
          const m = next.trim().match(RE_TOOL_RESULT);
          resultLines.push(m ? m[1] : next);
          i++;
        } else {
          break;
        }
      }
      // Attach to previous tool-call if exists
      if (segments.length > 0 && segments[segments.length - 1].kind === "tool-call") {
        segments.push({ kind: "tool-result", text: resultLines.join("\n") });
      } else {
        segments.push({ kind: "tool-result", text: resultLines.join("\n") });
      }
      continue;
    }

    // Bash(command) → tool call
    const bashMatch = trimmed.match(RE_BASH_CALL);
    if (bashMatch) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "bash",
        command: bashMatch[1],
      });
      i++;
      continue;
    }

    // Read(file) or Reading N files
    const readMatch = trimmed.match(RE_READ_CALL);
    if (readMatch) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "read",
        filePath: readMatch[1],
      });
      i++;
      continue;
    }
    if (RE_READING_FILES.test(trimmed)) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "read",
      });
      i++;
      continue;
    }

    // Update(file) / Write(file)
    const updateMatch = trimmed.match(RE_UPDATE_CALL);
    if (updateMatch) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "edit",
        filePath: updateMatch[1],
      });
      i++;
      continue;
    }
    const writeMatch = trimmed.match(RE_WRITE_CALL);
    if (writeMatch) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "edit",
        filePath: writeMatch[1],
      });
      i++;
      continue;
    }

    // Edit(file) — alternative to Update
    const editMatch = trimmed.match(RE_EDIT_CALL);
    if (editMatch) {
      segments.push({
        kind: "tool-call",
        text: trimmed,
        tool: "edit",
        filePath: editMatch[1],
      });
      i++;
      continue;
    }

    // Glob(pattern) / Grep(pattern)
    const globMatch = trimmed.match(RE_GLOB_CALL);
    if (globMatch) {
      segments.push({ kind: "tool-call", text: trimmed, tool: "read" });
      i++;
      continue;
    }
    const grepMatch = trimmed.match(RE_GREP_CALL);
    if (grepMatch) {
      segments.push({ kind: "tool-call", text: trimmed, tool: "read" });
      i++;
      continue;
    }

    // Agent(...) / TodoWrite(...) / TodoRead(...) / ToolSearch(...)
    if (
      RE_AGENT_CALL.test(trimmed) ||
      RE_TODO_CALL.test(trimmed) ||
      RE_TOOL_SEARCH_CALL.test(trimmed)
    ) {
      segments.push({ kind: "tool-call", text: trimmed, tool: "bash" });
      i++;
      continue;
    }

    // ✻ Cogitated → status
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
