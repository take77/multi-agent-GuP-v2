"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { useAppStore } from "@/lib/store";
import StopButton from "./StopButton";
import ImagePreview from "./ImagePreview";

const QUICK_ACTIONS = [
  { label: "/clear", command: "/clear" },
  { label: "Sonnet", command: "/model sonnet" },
  { label: "Opus", command: "/model opus" },
];

const ACCEPTED_IMAGE_TYPES = ["image/png", "image/jpeg", "image/gif", "image/webp"];
const MAX_TEXTAREA_ROWS = 6;

export function CommandInput() {
  const {
    selectedAgent,
    clusters,
    addMessage,
    sendCommand,
    sendEscapeCommand,
    addCommandHistory,
    commandHistory,
    draftMessages,
    setDraftMessage,
  } = useAppStore();
  const [input, setInput] = useState("");
  const [drag, setDrag] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<{
    rule?: string;
    message: string;
  } | null>(null);
  const [historyIdx, setHistoryIdx] = useState(-1);
  const [pendingImages, setPendingImages] = useState<File[]>([]);
  const [pendingPreviews, setPendingPreviews] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const history = commandHistory[selectedAgent] ?? [];

  const timeStr = () =>
    new Date().toLocaleTimeString("ja-JP", {
      hour: "2-digit",
      minute: "2-digit",
    });

  // Auto-resize textarea
  const adjustHeight = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    const lineHeight = 18; // approx line height at text-[12px]
    const maxHeight = lineHeight * MAX_TEXTAREA_ROWS + 12; // + padding
    el.style.height = `${Math.min(el.scrollHeight, maxHeight)}px`;
  }, []);

  useEffect(() => {
    adjustHeight();
  }, [input, adjustHeight]);

  // Restore draft when selected agent changes
  useEffect(() => {
    setInput(draftMessages[selectedAgent] ?? "");
    setHistoryIdx(-1);
  }, [selectedAgent, draftMessages]);

  // Generate preview URLs for pending images, revoke on cleanup
  useEffect(() => {
    const urls = pendingImages.map((f) => URL.createObjectURL(f));
    setPendingPreviews(urls);
    return () => urls.forEach((url) => URL.revokeObjectURL(url));
  }, [pendingImages]);

  const uploadImage = useCallback(async (file: File): Promise<string | null> => {
    const token =
      typeof window !== "undefined"
        ? document.cookie
            .split("; ")
            .find((c) => c.startsWith("auth_token="))
            ?.split("=")[1] ?? ""
        : "";

    const formData = new FormData();
    formData.append("file", file);

    const res = await fetch("/api/agents/upload", {
      method: "POST",
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: formData,
    });

    if (!res.ok) return null;
    const data = await res.json();
    return data.path ?? null;
  }, []);

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

  const handleSend = useCallback(async () => {
    const cmd = input.trim();

    // Image upload flow
    if (pendingImages.length > 0) {
      setUploading(true);
      const paths: string[] = [];
      for (const file of pendingImages) {
        const uploadedPath = await uploadImage(file);
        if (!uploadedPath) {
          setUploading(false);
          setError({ message: "画像のアップロードに失敗しました" });
          return;
        }
        paths.push(uploadedPath);
      }
      setUploading(false);
      setPendingImages([]);
      // Send all image paths as command (with optional text)
      const imageCmd = cmd ? `${cmd}\n${paths.join("\n")}` : paths.join("\n");
      setInput("");
      setDraftMessage(selectedAgent, "");
      setHistoryIdx(-1);
      doSend(imageCmd);
      return;
    }

    if (!cmd) return;

    setInput("");
    setDraftMessage(selectedAgent, "");
    setHistoryIdx(-1);

    // All commands sent directly — D001-D012 blocking is handled server-side
    doSend(cmd);
  }, [input, pendingImages, doSend, uploadImage]);

  const handleQuickAction = useCallback(
    (command: string) => {
      doSend(command);
    },
    [doSend]
  );

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      handleSend();
    } else if (e.key === "ArrowUp" && !input) {
      e.preventDefault();
      if (history.length === 0) return;
      const newIdx =
        historyIdx === -1 ? history.length - 1 : Math.max(0, historyIdx - 1);
      setHistoryIdx(newIdx);
      setInput(history[newIdx]);
    } else if (e.key === "ArrowDown" && !input) {
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
    }
  };

  // Clipboard paste handler
  const handlePaste = useCallback((e: React.ClipboardEvent) => {
    const items = e.clipboardData.items;
    const imageFiles: File[] = [];
    for (let i = 0; i < items.length; i++) {
      if (ACCEPTED_IMAGE_TYPES.includes(items[i].type)) {
        const file = items[i].getAsFile();
        if (file) imageFiles.push(file);
      }
    }
    if (imageFiles.length > 0) {
      e.preventDefault();
      setPendingImages((prev) => [...prev, ...imageFiles]);
    }
  }, []);

  // Drag & drop handler
  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setDrag(false);
    const files = Array.from(e.dataTransfer.files).filter((f) =>
      ACCEPTED_IMAGE_TYPES.includes(f.type)
    );
    if (files.length > 0) {
      setPendingImages((prev) => [...prev, ...files]);
    }
  }, []);

  // File input handler
  const handleFileSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []).filter((f) =>
      ACCEPTED_IMAGE_TYPES.includes(f.type)
    );
    if (files.length > 0) {
      setPendingImages((prev) => [...prev, ...files]);
    }
    // Reset input so same file can be selected again
    e.target.value = "";
  }, []);

  const isProcessing = sending || uploading;

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
      onDrop={handleDrop}
    >
      {drag && (
        <div className="text-center text-sky-300 text-[12px] py-2 mb-2 border border-dashed border-sky-600 rounded-lg bg-sky-900/30">
          画像をドロップでアップロード
        </div>
      )}

      {/* Image Preview */}
      {pendingImages.length > 0 && (
        <div className="mb-2">
          <ImagePreview
            images={pendingImages.map((file, i) => ({ file, preview: pendingPreviews[i] ?? "" }))}
            onRemove={(i) => setPendingImages((prev) => prev.filter((_, idx) => idx !== i))}
          />
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
      <div className="flex gap-1.5 items-end">
        <button
          className="p-1.5 rounded-lg text-slate-500 hover:text-slate-300 hover:bg-slate-800 shrink-0"
          title="画像を添付"
          onClick={() => fileInputRef.current?.click()}
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
          ref={fileInputRef}
          type="file"
          accept="image/png,image/jpeg,image/gif,image/webp"
          multiple
          className="hidden"
          onChange={handleFileSelect}
        />
        <textarea
          ref={textareaRef}
          rows={1}
          className="flex-1 min-w-0 bg-slate-800 border border-slate-700 rounded-lg px-2.5 py-1.5 text-[12px] text-slate-200 placeholder-slate-600 focus:outline-none focus:border-slate-500 resize-none overflow-y-auto leading-[18px]"
          placeholder={`${agent?.name ?? ""} にコマンド送信...`}
          value={input}
          onChange={(e) => {
            setInput(e.target.value);
            setDraftMessage(selectedAgent, e.target.value);
            setHistoryIdx(-1);
          }}
          onKeyDown={handleKeyDown}
          onPaste={handlePaste}
          disabled={isProcessing}
        />
        <button
          onClick={() => sendEscapeCommand(selectedAgent)}
          title="割り込み (Escape)"
          className="px-2 py-1.5 rounded-lg text-[12px] font-medium shrink-0 bg-red-700/70 hover:bg-red-600 text-red-200"
        >
          ⏹
        </button>
        {isProcessing ? (
          <StopButton agentId={selectedAgent} />
        ) : (
          <button
            onClick={handleSend}
            disabled={!input.trim() && pendingImages.length === 0}
            title="送信 (Ctrl+Enter)"
            className={`px-3 py-1.5 rounded-lg text-[12px] font-medium shrink-0 ${
              (input.trim() || pendingImages.length > 0)
                ? "bg-sky-600 hover:bg-sky-500 text-white"
                : "bg-slate-800 text-slate-600"
            }`}
          >
            送信
          </button>
        )}
      </div>

      {/* Quick Actions */}
      <div className="flex gap-1 mt-1.5">
        {QUICK_ACTIONS.map((qa) => (
          <button
            key={qa.command}
            onClick={() => handleQuickAction(qa.command)}
            disabled={isProcessing}
            className="px-2 py-0.5 rounded text-[10px] text-slate-500 hover:text-slate-300 hover:bg-slate-800 border border-slate-700/50 disabled:opacity-50"
          >
            {qa.label}
          </button>
        ))}
      </div>
    </div>
  );
}
