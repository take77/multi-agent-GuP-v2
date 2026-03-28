"use client";

// Stub — will be replaced by dedicated member's implementation
export default function ImagePreview({
  src,
  fileName,
  onRemove,
}: {
  src: string;
  fileName: string;
  onRemove: () => void;
}) {
  return (
    <div className="flex items-center gap-2 p-1.5 rounded-lg bg-slate-800 border border-slate-700">
      <img src={src} alt={fileName} className="h-10 w-10 object-cover rounded" />
      <span className="text-[11px] text-slate-400 truncate">{fileName}</span>
      <button
        onClick={onRemove}
        className="ml-auto text-slate-500 hover:text-slate-300 text-[11px] shrink-0"
      >
        ✕
      </button>
    </div>
  );
}
