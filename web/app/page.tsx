"use client";

import { useAppStore } from "@/lib/store";
import { useSSE } from "@/lib/sse-client";
import { Sidebar } from "@/components/layout/Sidebar";
import { Header } from "@/components/layout/Header";
import ChatPage from "./chat/page";
import AgentsPage from "./agents/page";
import GitPage from "./git/page";
import ProgressPage from "./progress/page";

export default function Home() {
  const { view } = useAppStore();
  useSSE();

  return (
    <div
      className="h-screen flex bg-slate-950 text-white overflow-hidden"
      style={{ fontFamily: "system-ui, sans-serif" }}
    >
      <Sidebar />
      <main className="flex-1 flex flex-col overflow-hidden bg-slate-950 min-w-0">
        <Header />
        <div className="flex-1 overflow-hidden">
          {view === "chat" && <ChatPage />}
          {view === "agents" && <AgentsPage />}
          {view === "git" && <GitPage />}
          {view === "progress" && <ProgressPage />}
        </div>
      </main>
    </div>
  );
}
