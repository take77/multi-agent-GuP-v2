"use client";

interface StopButtonProps {
  agentId: string;
}

export default function StopButton({ agentId }: StopButtonProps) {
  const handleStop = async () => {
    try {
      const token =
        typeof window !== "undefined"
          ? document.cookie
              .split("; ")
              .find((c) => c.startsWith("auth_token="))
              ?.split("=")[1] ?? ""
          : "";

      await fetch("/api/agents/command", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({ agentId, command: "\x03" }),
      });
    } catch {
      // Stop attempt failed silently
    }
  };

  return (
    <button
      onClick={handleStop}
      title={`${agentId} を停止`}
      className="flex items-center justify-center w-7 h-7 rounded-full bg-red-600 hover:bg-red-500 shrink-0 animate-fade-in transition-colors"
      aria-label="停止"
    >
      <span className="block w-3 h-3 bg-white rounded-sm" />
    </button>
  );
}
