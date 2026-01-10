import { NextResponse } from "next/server"

/**
 * Health check endpoint - no auth required
 */
export function GET() {
  return NextResponse.json({
    data: {
      status: "ok",
      timestamp: new Date().toISOString(),
    },
    error: null,
    meta: { timestamp: new Date().toISOString() },
  })
}
