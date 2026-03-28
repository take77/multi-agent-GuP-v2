"use client";

import { useState } from "react";
import { useAppStore } from "@/lib/store";

export function CommandInput() {
  const { selectedAgent, clusters, addMessage } = useAppStore();
  const [input, setInput] = useState("");
  const [drag, setDrag] = useState(false);

  const agent = clusters
    .flatMap((c) => c.agents)
    .find((a) => a.id === selectedAgent);

  const handleSend = () => {
    if (!input.trim()) return;
    addMessage(selectedAgent, {
      role: "user",
      text: input,
      time: new Date().toLocaleTimeString("ja-JP", {
        hour: "2-digit",
        minute: "2-digit",
      }),
    });
    setInput("");
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
          \ud83d\udcce ドロップでアップロード
        </div>
      )}
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
          className="flex-1 min-w-0 bg-slate-800 border border-slate-700 rounded-lg px-2.5 py-1.5 text-[12px] text-slate-200 placeholder-slate-600 focus:outline-none focus:border-slate-500"
          placeholder={`${agent?.name ?? ""} にコマンド送信...`}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") handleSend();
          }}
        />
        <button
          onClick={handleSend}
          className={`px-3 py-1.5 rounded-lg text-[12px] font-medium shrink-0 ${
            input
              ? "bg-sky-600 hover:bg-sky-500 text-white"
              : "bg-slate-800 text-slate-600"
          }`}
        >
          送信
        </button>
      </div>
    </div>
  );
}
