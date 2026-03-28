"use client";

// Stub — will be replaced by dedicated member's implementation
export default function StopButton({ agentId }: { agentId: string }) {
  return (
    <button
      className="px-3 py-1.5 rounded-lg text-[12px] font-medium shrink-0 bg-red-600 hover:bg-red-500 text-white"
      title={`Stop ${agentId}`}
    >
      Stop
    </button>
  );
}
