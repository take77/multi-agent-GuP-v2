import { NextResponse } from "next/server";
import { readFile } from "fs/promises";
import { extname, resolve } from "path";

const PROJECT_ROOT = resolve(process.cwd(), "..");
const UPLOADS_DIR = resolve(PROJECT_ROOT, "uploads");

const MIME_MAP: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".md": "text/plain",
  ".txt": "text/plain",
  ".pdf": "application/pdf",
  ".yaml": "text/yaml",
  ".yml": "text/yaml",
  ".json": "application/json",
  ".csv": "text/csv",
  ".log": "text/plain",
};

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const path = searchParams.get("path");

  if (!path) {
    return NextResponse.json({ error: "path is required" }, { status: 400 });
  }

  // Security: reject path traversal
  if (path.includes("..")) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  // Security: resolve and verify path is inside UPLOADS_DIR
  const resolvedPath = resolve(path);
  if (!resolvedPath.startsWith(UPLOADS_DIR + "/") && resolvedPath !== UPLOADS_DIR) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }

  const ext = extname(resolvedPath).toLowerCase();
  const mimeType = MIME_MAP[ext];
  if (!mimeType) {
    return NextResponse.json({ error: "Unsupported file type" }, { status: 400 });
  }

  try {
    const data = await readFile(resolvedPath);
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
