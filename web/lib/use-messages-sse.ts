"use client";

import { useEffect } from "react";
import { useAppStore } from "./store";
import type { InboxMessage } from "@/types/message";

const SSE_URL = "/api/sse/messages";
const RECONNECT_DELAY = 3000;

/**
 * 案B: フォールバックfetch
 * SSEエンドポイントへfetchし、最初の "initial" イベントのデータを取得して返す。
 * SSE接続数上限（HTTP/1.1: 6本/ドメイン）に達している場合でも
 * 通常のfetch（別コネクション）で初期データを取得できる。
 */
async function fetchInitialMessages(): Promise<InboxMessage[]> {
  try {
    const res = await fetch(SSE_URL);
    if (!res.ok || !res.body) return [];

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      // SSEのイベントブロックは "\n\n" で区切られる
      const blocks = buffer.split("\n\n");
      for (const block of blocks) {
        const lines = block.split("\n");
        let eventType = "";
        let data = "";
        for (const line of lines) {
          if (line.startsWith("event: ")) eventType = line.slice(7).trim();
          if (line.startsWith("data: ")) data = line.slice(6).trim();
        }
        if (eventType === "initial" && data) {
          // initialイベント取得後は接続を閉じる
          reader.cancel().catch(() => {});
          return JSON.parse(data) as InboxMessage[];
        }
      }
    }
  } catch (err) {
    console.error("[useMessagesSSE] fallback fetch failed:", err);
  }
  return [];
}

export function useMessagesSSE() {
  const { setInboxMessages, addInboxMessage } = useAppStore();

  useEffect(() => {
    let eventSource: EventSource | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

    // 案B: 初回マウント時にfetchで初期データを先取得（SSE接続前に表示）
    fetchInitialMessages().then((msgs) => {
      if (msgs.length > 0) {
        console.log(
          `[useMessagesSSE] fallback fetch: loaded ${msgs.length} messages`
        );
        setInboxMessages(msgs);
      }
    });

    function connect() {
      eventSource = new EventSource(SSE_URL);

      // 案A: 接続成功ログ
      eventSource.onopen = () => {
        console.log("[useMessagesSSE] SSE connected");
      };

      eventSource.addEventListener("initial", (e) => {
        try {
          const msgs = JSON.parse(e.data) as InboxMessage[];
          setInboxMessages(msgs);
        } catch (err) {
          // 案A: パースエラーを可視化
          console.error(
            "[useMessagesSSE] failed to parse 'initial' event:",
            err,
            e.data
          );
        }
      });

      eventSource.addEventListener("new-messages", (e) => {
        try {
          const msgs = JSON.parse(e.data) as InboxMessage[];
          for (const msg of msgs) {
            addInboxMessage(msg);
          }
        } catch (err) {
          // 案A: パースエラーを可視化
          console.error(
            "[useMessagesSSE] failed to parse 'new-messages' event:",
            err,
            e.data
          );
        }
      });

      eventSource.addEventListener("heartbeat", () => {
        // keepalive
      });

      eventSource.onerror = (ev) => {
        // 案A: 接続失敗を可視化
        console.warn(
          "[useMessagesSSE] SSE error, reconnecting in",
          RECONNECT_DELAY,
          "ms",
          ev
        );
        eventSource?.close();

        // 案B: SSE失敗時にフォールバックfetchで最新データを補完
        fetchInitialMessages().then((msgs) => {
          if (msgs.length > 0) {
            console.log(
              `[useMessagesSSE] onerror fallback: loaded ${msgs.length} messages`
            );
            setInboxMessages(msgs);
          }
        });

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
