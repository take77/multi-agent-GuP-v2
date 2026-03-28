import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Next.js Middleware: Bearer auth on /api/* routes.
 *
 * Note: Next.js middleware runs in Edge Runtime — cannot import Node.js modules.
 * Auth logic is duplicated here (not imported from lib/auth.ts) because
 * lib/auth.ts uses process.env at call time (Node runtime), while middleware
 * uses the Edge-compatible env access pattern.
 */

export function middleware(request: NextRequest) {
  // Skip auth in dev mode
  if (process.env.AUTH_DISABLED === "true") {
    return NextResponse.next();
  }

  const token = process.env.WEB_UI_AUTH_TOKEN;
  if (!token) {
    return NextResponse.json(
      { error: "Server auth not configured" },
      { status: 500 }
    );
  }

  const authHeader = request.headers.get("authorization");
  if (!authHeader) {
    return NextResponse.json(
      { error: "Missing Authorization header" },
      { status: 401 }
    );
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return NextResponse.json(
      { error: "Invalid Authorization format" },
      { status: 401 }
    );
  }

  const provided = match[1];

  // Constant-time comparison
  if (provided.length !== token.length) {
    return NextResponse.json({ error: "Invalid token" }, { status: 401 });
  }

  let result = 0;
  for (let i = 0; i < provided.length; i++) {
    result |= provided.charCodeAt(i) ^ token.charCodeAt(i);
  }

  if (result !== 0) {
    return NextResponse.json({ error: "Invalid token" }, { status: 401 });
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/api/:path*"],
};
