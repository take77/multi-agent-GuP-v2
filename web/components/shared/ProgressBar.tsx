"use client";

export function ProgressBar({
  value,
  color = "#3b82f6",
}: {
  value: number;
  color?: string;
}) {
  return (
    <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
      <div
        className="h-full rounded-full transition-all"
        style={{ width: `${Math.min(100, Math.max(0, value))}%`, background: color }}
      />
    </div>
  );
}
