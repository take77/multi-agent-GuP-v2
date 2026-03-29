"use client";

import { useState, useCallback, useRef } from "react";
import { useAppStore } from "@/lib/store";
import { useSSE } from "@/lib/sse-client";
import { useMessagesSSE } from "@/lib/use-messages-sse";
import { Sidebar } from "@/components/layout/Sidebar";
import { Header } from "@/components/layout/Header";
import ChatPage from "./chat/page";
import MessagesPage from "./messages/page";
import AgentsPage from "./agents/page";
import GitPage from "./git/page";
import ProgressPage from "./progress/page";

const SIDEBAR_MIN = 140;
const SIDEBAR_MAX = 280;
const SIDEBAR_DEFAULT = 180;

export default function Home() {
  const { view } = useAppStore();
  useSSE();
  useMessagesSSE();

  const [sidebarWidth, setSidebarWidth] = useState(SIDEBAR_DEFAULT);
  const dragging = useRef(false);
  const startX = useRef(0);
  const startWidth = useRef(0);

  const onHandleMouseDown = useCallback(
    (e: React.MouseEvent) => {
      dragging.current = true;
      startX.current = e.clientX;
      startWidth.current = sidebarWidth;
      e.preventDefault();
    },
    [sidebarWidth]
  );

  const onMouseMove = useCallback((e: React.MouseEvent) => {
    if (!dragging.current) return;
    const delta = e.clientX - startX.current;
    const next = Math.min(
      SIDEBAR_MAX,
      Math.max(SIDEBAR_MIN, startWidth.current + delta)
    );
    setSidebarWidth(next);
  }, []);

  const onMouseUp = useCallback(() => {
    dragging.current = false;
  }, []);

  return (
    <div
      className="h-screen flex bg-slate-950 text-white overflow-hidden"
      style={{ fontFamily: "system-ui, sans-serif" }}
      onMouseMove={onMouseMove}
      onMouseUp={onMouseUp}
      onMouseLeave={onMouseUp}
    >
      {/* Left nav sidebar with dynamic width */}
      <div style={{ width: sidebarWidth }} className="shrink-0 overflow-hidden">
        <Sidebar />
      </div>

      {/* Resize handle */}
      <div
        className="w-1 bg-slate-700/30 hover:bg-slate-500/70 active:bg-sky-500/60 cursor-col-resize shrink-0 transition-colors"
        onMouseDown={onHandleMouseDown}
      />

      <main className="flex-1 flex flex-col overflow-hidden bg-slate-950 min-w-0">
        <Header />
        <div className="flex-1 overflow-hidden">
          {view === "chat" && <ChatPage />}
          {view === "messages" && <MessagesPage />}
          {view === "agents" && <AgentsPage />}
          {view === "git" && <GitPage />}
          {view === "progress" && <ProgressPage />}
        </div>
      </main>
    </div>
  );
}
