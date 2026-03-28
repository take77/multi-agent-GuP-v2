import { NextResponse } from "next/server";

export async function GET() {
  // Phase 1: stub response
  // Phase 2: read queue/tasks/*.yaml with chokidar watcher
  return NextResponse.json({
    tasks: [],
    message: "Phase 1 stub - YAML watcher in Phase 2",
  });
}
