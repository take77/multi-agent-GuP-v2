import { NextResponse } from "next/server";
import { readFile } from "fs/promises";
import { extname } from "path";

const ALLOWED_PREFIX = "/tmp/gup-upload-";
const MIME_MAP: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
};

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const path = searchParams.get("path");

  if (!path) {
    return NextResponse.json({ error: "path is required" }, { status: 400 });
  }

  // Security: reject path traversal and only allow /tmp/gup-upload- prefix
  if (path.includes("..") || !path.startsWith(ALLOWED_PREFIX)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const ext = extname(path).toLowerCase();
  const mimeType = MIME_MAP[ext];
  if (!mimeType) {
    return NextResponse.json({ error: "Unsupported file type" }, { status: 400 });
  }

  try {
    const data = await readFile(path);
    return new Response(data, {
      headers: {
        "Content-Type": mimeType,
        "Cache-Control": "private, max-age=3600",
      },
    });
  } catch {
    return NextResponse.json({ error: "File not found" }, { status: 404 });
  }
}
