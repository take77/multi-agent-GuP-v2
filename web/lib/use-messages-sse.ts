"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";
import type { InboxMessage } from "@/types/message";

const SSE_URL = "/api/sse/messages";
const RECONNECT_DELAY = 3000;

export function useMessagesSSE() {
  const { setInboxMessages, addInboxMessage } = useAppStore();

  useEffect(() => {
    let eventSource: EventSource | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    function connect() {
      eventSource = new EventSource(SSE_URL);

      eventSource.addEventListener("initial", (e) => {
        try {
          const msgs = JSON.parse(e.data) as InboxMessage[];
          setInboxMessages(msgs);
        } catch {
          // ignore
        }
      });

      eventSource.addEventListener("new-messages", (e) => {
        try {
          const msgs = JSON.parse(e.data) as InboxMessage[];
          for (const msg of msgs) {
            addInboxMessage(msg);
          }
        } catch {
          // ignore
        }
      });

      eventSource.addEventListener("heartbeat", () => {
        // keepalive
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
  }, [setInboxMessages, addInboxMessage]);
}
