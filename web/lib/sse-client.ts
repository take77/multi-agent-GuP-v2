"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";

const SSE_BASE_URL = "/api/agents/stream";
const RECONNECT_DELAY = 3000;

function getAuthToken(): string {
  if (typeof document === "undefined") return "";
  return (
    document.cookie
      .split("; ")
      .find((c) => c.startsWith("auth_token="))
      ?.split("=")[1] ?? ""
  );
}

export function useSSE() {
  const { setConnected, addMessage } = useAppStore();

  useEffect(() => {
    let eventSource: EventSource | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    function connect() {
      const token = getAuthToken();
      const url = token
        ? `${SSE_BASE_URL}?token=${encodeURIComponent(token)}`
        : SSE_BASE_URL;
      eventSource = new EventSource(url);

      eventSource.onopen = () => {
        setConnected(true);
      };

      eventSource.addEventListener("agent-output", (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.agentId && data.output) {
            // Add the captured output as an agent message
            const now = new Date();
            const time = `${now.getHours().toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")}`;
            addMessage(data.agentId, {
              role: "agent",
              text: data.output.slice(-2000), // Last 2000 chars to avoid overflow
              time,
            });
          }
        } catch {
          // ignore parse errors
        }
      });

      eventSource.addEventListener("agent-status", (e) => {
        try {
          JSON.parse(e.data);
          // Future: update agent status in store
        } catch {
          // ignore parse errors
        }
      });

      eventSource.addEventListener("heartbeat", () => {
        // keepalive - no action needed
      });

      eventSource.onerror = () => {
        setConnected(false);
        eventSource?.close();
        reconnectTimer = setTimeout(connect, RECONNECT_DELAY);
      };
    }

    connect();

    return () => {
      eventSource?.close();
      if (reconnectTimer) clearTimeout(reconnectTimer);
      setConnected(false);
    };
  }, [setConnected, addMessage]);
}
