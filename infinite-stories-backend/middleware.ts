import { NextResponse, type NextRequest } from 'next/server';

/**
 * CORS origin allowlist built from environment variables and static origins.
 * ALLOWED_ORIGINS env var accepts comma-separated origins (e.g., "https://app.example.com,https://staging.example.com").
 * BETTER_AUTH_URL is also included if set.
 * NEXT_PUBLIC_APP_URL is also included if set.
 */
const ALLOWED_ORIGINS: string[] = (() => {
  const origins = new Set<string>();

  // Static origins from ALLOWED_ORIGINS env var (comma-separated)
  const envOrigins = process.env.ALLOWED_ORIGINS;
  if (envOrigins) {
    envOrigins.split(',').map(o => o.trim()).filter(Boolean).forEach(o => origins.add(o));
  }

  // Include Better Auth URL
  if (process.env.BETTER_AUTH_URL) {
    origins.add(process.env.BETTER_AUTH_URL.replace(/\/$/, ''));
  }

  // Include public app URL
  if (process.env.NEXT_PUBLIC_APP_URL) {
    origins.add(process.env.NEXT_PUBLIC_APP_URL.replace(/\/$/, ''));
  }

  return Array.from(origins);
})();

/**
 * Middleware for Next.js API routes
 *
 * Note: Authentication is handled in individual route handlers, not here.
 * This is because middleware runs in Edge Runtime which doesn't support
 * Prisma Client (required by Better Auth for session validation).
 *
 * See lib/auth/session.ts for authentication helpers.
 *
 * CORS policy:
 * - If Origin header is present AND in allowlist -> reflect origin + Vary: Origin
 * - If Origin header is present but NOT in allowlist -> no CORS headers (browser blocks)
 * - If NO Origin header (native iOS app, server-to-server) -> allow through, no CORS headers needed
 */
export async function middleware(request: NextRequest) {
  const response = NextResponse.next();
  const origin = request.headers.get('Origin');

  if (origin) {
    // Browser-based request with Origin header
    if (ALLOWED_ORIGINS.includes(origin)) {
      // Origin is in allowlist — reflect it
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
      response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      response.headers.set('Access-Control-Expose-Headers', 'set-auth-token');
      response.headers.set('Vary', 'Origin');
    }
    // If origin is NOT in allowlist, we intentionally do NOT set any CORS headers.
    // The browser will block the response on the client side.
  }
  // If there is NO Origin header (native iOS app, curl, server-to-server),
  // we allow the request through without any CORS headers.

  return response;
}

export const config = {
  matcher: [
    // Skip Next.js internals and all static files
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    // Always run for API routes
    '/(api|trpc)(.*)',
  ],
};
