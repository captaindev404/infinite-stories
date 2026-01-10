import { NextRequest, NextResponse } from "next/server"
import { validateToken, unauthorizedResponse, isPublicPath } from "@/lib/auth"

/**
 * Next.js Middleware
 * Applies to all /api/* routes except public paths
 */
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Only apply to API routes
  if (!pathname.startsWith("/api")) {
    return NextResponse.next()
  }

  // Skip auth for public paths
  if (isPublicPath(pathname)) {
    return NextResponse.next()
  }

  // Validate token
  if (!validateToken(request)) {
    return unauthorizedResponse()
  }

  return NextResponse.next()
}

/**
 * Middleware matcher - only run on API routes
 */
export const config = {
  matcher: "/api/:path*",
}
