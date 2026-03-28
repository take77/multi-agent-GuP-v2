"use client";

import { useState, useRef, useCallback } from "react";
import { useAppStore } from "@/lib/store";
import { isWhitelistedCommand } from "@/lib/command-sanitizer";

const QUICK_ACTIONS = [
  { label: "/clear", command: "/clear" },
  { label: "Sonnet", command: "/model sonnet" },
  { label: "Opus", command: "/model opus" },
];

export function CommandInput() {
  const {
    selectedAgent,
    clusters,
    addMessage,
    sendCommand,
    addCommandHistory,
    commandHistory,
  } = useAppStore();
  const [input, setInput] = useState("");
  const [drag, setDrag] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<{
    rule?: string;
    message: string;
  } | null>(null);
  const [confirm, setConfirm] = useState<string | null>(null);
  const [historyIdx, setHistoryIdx] = useState(-1);
  const inputRef = useRef<HTMLInputElement>(null);

  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const history = commandHistory[selectedAgent] ?? [];

  const timeStr = () =>
    new Date().toLocaleTimeString("ja-JP", {
      hour: "2-digit",
      minute: "2-digit",
    });

  const doSend = useCallback(
    async (command: string) => {
      setSending(true);
      setError(null);

      addMessage(selectedAgent, {
        role: "user",
        text: command,
        time: timeStr(),
      });
      addCommandHistory(selectedAgent, command);

      const result = await sendCommand(selectedAgent, command);

      if (!result.success && result.error) {
        setError(result.error);
        addMessage(selectedAgent, {
          role: "agent",
          text: result.error.rule
            ? `[${result.error.rule}] ${result.error.message}`
            : `エラー: ${result.error.message}`,
          time: timeStr(),
        });
      }

      setSending(false);
    },
    [selectedAgent, addMessage, addCommandHistory, sendCommand]
  );

  const handleSend = useCallback(() => {
    const cmd = input.trim();
    if (!cmd) return;

    setInput("");
    setHistoryIdx(-1);

    // Whitelisted commands → send immediately
    if (isWhitelistedCommand(cmd)) {
      doSend(cmd);
      return;
    }

    // Non-whitelisted → show confirmation dialog
    setConfirm(cmd);
  }, [input, doSend]);

  const handleConfirm = useCallback(() => {
    if (!confirm) return;
    const cmd = confirm;
    setConfirm(null);
    doSend(cmd);
  }, [confirm, doSend]);

  const handleCancel = useCallback(() => {
    setConfirm(null);
  }, []);

  const handleQuickAction = useCallback(
    (command: string) => {
      doSend(command);
    },
    [doSend]
  );

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") {
      handleSend();
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (history.length === 0) return;
      const newIdx =
        historyIdx === -1 ? history.length - 1 : Math.max(0, historyIdx - 1);
      setHistoryIdx(newIdx);
      setInput(history[newIdx]);
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      if (historyIdx === -1) return;
      if (historyIdx >= history.length - 1) {
        setHistoryIdx(-1);
        setInput("");
      } else {
        const newIdx = historyIdx + 1;
        setHistoryIdx(newIdx);
        setInput(history[newIdx]);
      }
    } else if (e.key === "Escape") {
      if (confirm) {
        handleCancel();
      }
    }
  };

  return (
    <div
      className={`border-t border-slate-700/50 p-2 ${
        drag ? "bg-sky-900/20" : ""
      }`}
      onDragOver={(e) => {
        e.preventDefault();
        setDrag(true);
      }}
      onDragLeave={() => setDrag(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDrag(false);
      }}
    >
      {drag && (
        <div className="text-center text-sky-300 text-[12px] py-2 mb-2 border border-dashed border-sky-600 rounded-lg bg-sky-900/30">
          📎 ドロップでアップロード
        </div>
      )}

      {/* Confirmation Dialog */}
      {confirm && (
        <div className="mb-2 p-2.5 rounded-lg bg-amber-900/30 border border-amber-700/40">
          <p className="text-[11px] text-amber-300 mb-1.5">
            以下のコマンドを送信しますか？
          </p>
          <pre className="text-[11px] text-slate-200 bg-slate-800 rounded px-2 py-1 mb-2 overflow-x-auto">
            {confirm}
          </pre>
          <div className="flex gap-1.5 justify-end">
            <button
              onClick={handleCancel}
              className="px-2.5 py-1 rounded text-[11px] text-slate-400 hover:text-slate-200 hover:bg-slate-700"
            >
              キャンセル
            </button>
            <button
              onClick={handleConfirm}
              className="px-2.5 py-1 rounded text-[11px] bg-amber-600 hover:bg-amber-500 text-white"
            >
              実行
            </button>
          </div>
        </div>
      )}

      {/* Error Display */}
      {error && (
        <div className="mb-2 px-2.5 py-1.5 rounded-lg bg-red-900/30 border border-red-700/40 flex items-start gap-2">
          <span className="text-red-400 text-[11px] shrink-0">
            {error.rule ? `[${error.rule}]` : "Error"}
          </span>
          <span className="text-[11px] text-red-300">{error.message}</span>
          <button
            onClick={() => setError(null)}
            className="ml-auto text-red-500 hover:text-red-300 text-[11px] shrink-0"
          >
            ✕
          </button>
        </div>
      )}

      {/* Input Row */}
      <div className="flex gap-1.5">
        <button
          className="p-1.5 rounded-lg text-slate-500 hover:text-slate-300 hover:bg-slate-800 shrink-0"
          title="添付"
        >
          <svg
            width="16"
            height="16"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
            viewBox="0 0 24 24"
          >
            <path
              d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
        <input
          ref={inputRef}
          className="flex-1 min-w-0 bg-slate-800 border border-slate-700 rounded-lg px-2.5 py-1.5 text-[12px] text-slate-200 placeholder-slate-600 focus:outline-none focus:border-slate-500"
          placeholder={`${agent?.name ?? ""} にコマンド送信...`}
          value={input}
          onChange={(e) => {
            setInput(e.target.value);
            setHistoryIdx(-1);
          }}
          onKeyDown={handleKeyDown}
          disabled={sending}
        />
        <button
          onClick={handleSend}
          disabled={sending || !input.trim()}
          className={`px-3 py-1.5 rounded-lg text-[12px] font-medium shrink-0 ${
            input.trim() && !sending
              ? "bg-sky-600 hover:bg-sky-500 text-white"
              : "bg-slate-800 text-slate-600"
          }`}
        >
          {sending ? "..." : "送信"}
        </button>
      </div>

      {/* Quick Actions */}
      <div className="flex gap-1 mt-1.5">
        {QUICK_ACTIONS.map((qa) => (
          <button
            key={qa.command}
            onClick={() => handleQuickAction(qa.command)}
            disabled={sending}
            className="px-2 py-0.5 rounded text-[10px] text-slate-500 hover:text-slate-300 hover:bg-slate-800 border border-slate-700/50 disabled:opacity-50"
          >
            {qa.label}
          </button>
        ))}
      </div>
    </div>
  );
}
