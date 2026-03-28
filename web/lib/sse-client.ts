"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";
import type { Cluster } from "@/types/agent";

const SSE_BASE_URL = "/api/agents/stream";
const SSE_AGENTS_URL = "/api/sse/agents";
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
  const setConnected = useAppStore((s) => s.setConnected);
  const setLatestOutput = useAppStore((s) => s.setLatestOutput);
  const setClusters = useAppStore((s) => s.setClusters);

  // Terminal output SSE
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
            // Replace latest output (not append) — capture-pane is a full snapshot
            setLatestOutput(data.agentId, data.output);
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
  }, [setConnected, setLatestOutput]);

  // Agent status SSE — provides cluster/agent data to all views
  useEffect(() => {
    let eventSource: EventSource | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    function connect() {
      eventSource = new EventSource(SSE_AGENTS_URL);

      eventSource.addEventListener("agent-status", (e) => {
        try {
          const data = JSON.parse(e.data) as { clusters: Cluster[] };
          if (data.clusters) {
            setClusters(data.clusters);
          }
        } catch {
          // ignore parse errors
        }
      });

      eventSource.onerror = () => {
        eventSource?.close();
        reconnectTimer = setTimeout(connect, RECONNECT_DELAY);
      };
    }

    connect();

    return () => {
      eventSource?.close();
      if (reconnectTimer) clearTimeout(reconnectTimer);
    };
  }, [setClusters]);
}
