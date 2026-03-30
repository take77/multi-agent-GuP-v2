import { NextResponse } from "next/server";
import { writeFile, mkdir } from "fs/promises";
import { join, resolve } from "path";

const ALLOWED_EXTENSIONS = new Set([
  "png", "jpg", "jpeg", "gif", "webp",
  "md", "txt", "pdf", "yaml", "yml", "json", "csv", "log",
]);
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

const PROJECT_ROOT = resolve(process.cwd(), "..");
const UPLOADS_DIR = resolve(PROJECT_ROOT, "uploads");

function sanitizeFilename(name: string): string {
  // Remove path separators and null bytes, keep only safe characters
  return name
    .replace(/[/\\:*?"<>|]/g, "_")
    .replace(/\0/g, "")
    .replace(/^\.+/, "_")
    .slice(0, 255);
}

export async function POST(req: Request) {
  try {
    const formData = await req.formData();
    const file = formData.get("file");

    if (!file || !(file instanceof File)) {
      return NextResponse.json(
        { error: "No file provided" },
        { status: 400 }
      );
    }

    // File size check
    if (file.size > MAX_FILE_SIZE) {
      return NextResponse.json(
        { error: `File too large. Maximum size is 10MB` },
        { status: 400 }
      );
    }

    // Extension validation
    const originalName = file.name;
    const dotIndex = originalName.lastIndexOf(".");
    if (dotIndex === -1) {
      return NextResponse.json(
        { error: "File has no extension" },
        { status: 400 }
      );
    }
    const ext = originalName.slice(dotIndex + 1).toLowerCase();

    if (!ALLOWED_EXTENSIONS.has(ext)) {
      return NextResponse.json(
        { error: `Unsupported file type: ${ext}. Allowed: png, jpg, gif, webp, md, txt, pdf, yaml, yml, json, csv, log` },
        { status: 400 }
      );
    }

    // Sanitized filename
    const sanitizedName = sanitizeFilename(originalName);

    // Ensure uploads directory exists
    await mkdir(UPLOADS_DIR, { recursive: true });

    // Build save path — {timestamp}_{sanitizedOriginalName}
    const timestamp = Date.now();
    const saveFilename = `${timestamp}_${sanitizedName}`;
    const savePath = resolve(UPLOADS_DIR, saveFilename);

    // Security: verify the resolved path is inside UPLOADS_DIR
    if (!savePath.startsWith(UPLOADS_DIR + "/") && savePath !== UPLOADS_DIR) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // Write file
    const bytes = await file.arrayBuffer();
    await writeFile(savePath, Buffer.from(bytes));

    return NextResponse.json({
      success: true,
      path: savePath,
      filename: sanitizedName,
    });
  } catch {
    return NextResponse.json(
      { error: "Failed to upload file" },
      { status: 500 }
    );
  }
}
