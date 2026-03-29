/**
 * Bearer token authentication for Web UI API routes.
 *
 * Token source: WEB_UI_AUTH_TOKEN env var
 * Dev bypass:   AUTH_DISABLED=true disables auth entirely
 */

export interface AuthResult {
  authenticated: boolean;
  error?: string;
}

export function verifyAuth(request: Request): AuthResult {
  // Dev mode bypass
  if (process.env.AUTH_DISABLED === "true") {
    return { authenticated: true };
  }

  const token = process.env.WEB_UI_AUTH_TOKEN;
  if (!token) {
    // No token configured = auth not set up, reject all
    return {
      authenticated: false,
      error: "Server auth not configured (WEB_UI_AUTH_TOKEN not set)",
    };
  }

  const authHeader = request.headers.get("authorization");
  if (!authHeader) {
    return { authenticated: false, error: "Missing Authorization header" };
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return { authenticated: false, error: "Invalid Authorization format (expected: Bearer <token>)" };
  }

  const provided = match[1];

  // Constant-time comparison to prevent timing attacks
  if (!timingSafeEqual(provided, token)) {
    return { authenticated: false, error: "Invalid token" };
  }

  return { authenticated: true };
}

/**
 * Constant-time string comparison.
 * Prevents timing-based token guessing.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) {
    // Still do a full comparison to avoid length-based timing leak
    let result = a.length ^ b.length;
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      result |=
        (a.charCodeAt(i % a.length) || 0) ^
        (b.charCodeAt(i % b.length) || 0);
    }
    return result === 0; // always false since lengths differ
  }

  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
