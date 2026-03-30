"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";
import type { StructuredEvent } from "@/types/structured-event";

export function useStructuredSse() {
  const addStructuredEvent = useAppStore((s) => s.addStructuredEvent);

  useEffect(() => {
    let es: EventSource | null = null;
    let retryTimer: ReturnType<typeof setTimeout> | null = null;
    let active = true;

    function connect() {
      if (!active) return;

      es = new EventSource("/api/sse/structured");

      es.addEventListener("structured-event", (e: MessageEvent) => {
        try {
          const event = JSON.parse(e.data) as StructuredEvent;
          addStructuredEvent(event.agent_id, event);
        } catch {
          // Skip malformed SSE data
        }
      });

      es.addEventListener("error", () => {
        es?.close();
        es = null;
        if (active) {
          retryTimer = setTimeout(connect, 5000);
        }
      });
    }

    connect();

    return () => {
      active = false;
      if (retryTimer) clearTimeout(retryTimer);
      es?.close();
    };
  }, [addStructuredEvent]);
}
