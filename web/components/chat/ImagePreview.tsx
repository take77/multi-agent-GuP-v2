"use client";

interface ImageItem {
  file: File;
  preview: string;
}

interface ImagePreviewProps {
  images: ImageItem[];
  onRemove: (index: number) => void;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}

export default function ImagePreview({ images, onRemove }: ImagePreviewProps) {
  return (
    <div className="flex gap-2 flex-wrap max-h-[80px] overflow-y-auto">
      {images.map(({ file, preview }, index) => (
        <div key={index} className="relative shrink-0 group">
          {file.type.startsWith("image/") ? (
            <>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={preview}
                alt={file.name}
                className="h-[64px] w-auto rounded border border-slate-600 object-cover"
              />
              <div className="absolute bottom-0 left-0 right-0 bg-black/60 text-[9px] text-slate-300 px-0.5 py-px truncate rounded-b">
                {file.name} · {formatFileSize(file.size)}
              </div>
            </>
          ) : (
            <div className="h-[64px] w-[80px] rounded border border-slate-600 bg-slate-800 flex flex-col items-center justify-center gap-0.5 px-1">
              <span className="text-[20px] leading-none">📄</span>
              <div className="text-[9px] text-slate-300 truncate w-full text-center">{file.name}</div>
              <div className="text-[9px] text-slate-500">{formatFileSize(file.size)}</div>
            </div>
          )}
          <button
            onClick={() => onRemove(index)}
            className="absolute -top-1.5 -right-1.5 w-4 h-4 bg-slate-700 hover:bg-red-600 rounded-full text-[10px] text-slate-300 hover:text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            aria-label={`${file.name}を削除`}
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
