"use client";

interface ImageFile {
  file: File;
  preview: string;
}

interface ImagePreviewProps {
  images: ImageFile[];
  onRemove: (index: number) => void;
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
}

export function ImagePreview({ images, onRemove }: ImagePreviewProps) {
  if (images.length === 0) return null;

  return (
    <div className="flex gap-2 flex-wrap mb-2 max-h-[80px] overflow-y-auto">
      {images.map((img, index) => (
        <div key={index} className="relative shrink-0 group">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={img.preview}
            alt={img.file.name}
            className="h-[64px] w-auto rounded border border-slate-600 object-cover"
          />
          <div className="absolute bottom-0 left-0 right-0 bg-black/60 text-[9px] text-slate-300 px-0.5 py-px truncate rounded-b">
            {formatFileSize(img.file.size)}
          </div>
          <button
            onClick={() => onRemove(index)}
            className="absolute -top-1.5 -right-1.5 w-4 h-4 bg-slate-700 hover:bg-red-600 rounded-full text-[10px] text-slate-300 hover:text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
            aria-label={`${img.file.name}を削除`}
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
