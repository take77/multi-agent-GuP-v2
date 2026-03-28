"use client";

interface StopButtonProps {
  onStop: () => void;
  visible: boolean;
}

export function StopButton({ onStop, visible }: StopButtonProps) {
  if (!visible) return null;

  return (
    <button
      onClick={onStop}
      title="処理を停止"
      className="flex items-center justify-center w-7 h-7 rounded-full bg-red-600 hover:bg-red-500 shrink-0 animate-fade-in transition-colors"
      aria-label="停止"
    >
      <span className="block w-3 h-3 bg-white rounded-sm" />
    </button>
  );
}
