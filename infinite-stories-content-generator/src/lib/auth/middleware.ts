import { NextRequest, NextResponse } from "next/server"

/**
 * Validate Bearer token from Authorization header
 * Returns true if token matches ADMIN_TOKEN env var
 */
export function validateToken(request: NextRequest): boolean {
  const authHeader = request.headers.get("Authorization")

  if (!authHeader) {
    return false
  }

  // Check for Bearer token format
  if (!authHeader.startsWith("Bearer ")) {
    return false
  }

  const token = authHeader.slice(7) // Remove "Bearer " prefix
  const adminToken = process.env.ADMIN_TOKEN

  if (!adminToken) {
    console.warn("ADMIN_TOKEN not configured - auth disabled")
    return true // Allow requests if no token configured (dev mode)
  }

  return token === adminToken
}

/**
 * Create unauthorized response
 */
export function unauthorizedResponse(): NextResponse {
  return NextResponse.json(
    {
      data: null,
      error: {
        _tag: "Unauthorized",
        message: "Invalid or missing authorization token",
      },
      meta: { timestamp: new Date().toISOString() },
    },
    { status: 401 }
  )
}

/**
 * Paths that should skip authentication
 */
export const PUBLIC_PATHS = [
  "/api/health",
  "/api/healthcheck",
]

/**
 * Check if path should skip auth
 */
export function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((path) => pathname.startsWith(path))
}
