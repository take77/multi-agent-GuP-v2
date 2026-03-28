"use client";

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

export default function Home() {
  const { view } = useAppStore();
  useSSE();
  useMessagesSSE();

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
          {view === "messages" && <MessagesPage />}
          {view === "agents" && <AgentsPage />}
          {view === "git" && <GitPage />}
          {view === "progress" && <ProgressPage />}
        </div>
      </main>
    </div>
  );
}
