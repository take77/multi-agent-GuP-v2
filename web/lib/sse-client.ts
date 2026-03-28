"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";

const SSE_URL = "/api/agents/stream";
const RECONNECT_DELAY = 3000;

export function useSSE() {
  const { setConnected } = useAppStore();

  useEffect(() => {
    let eventSource: EventSource | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    function connect() {
      eventSource = new EventSource(SSE_URL);

      eventSource.onopen = () => {
        setConnected(true);
      };

      eventSource.addEventListener("agent-output", (e) => {
        try {
          const data = JSON.parse(e.data);
          // Future: update store with agent output
          console.log("[SSE] agent-output:", data);
        } catch {
          // ignore parse errors
        }
      });

      eventSource.addEventListener("agent-status", (e) => {
        try {
          const data = JSON.parse(e.data);
          console.log("[SSE] agent-status:", data);
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
  }, [setConnected]);
}
