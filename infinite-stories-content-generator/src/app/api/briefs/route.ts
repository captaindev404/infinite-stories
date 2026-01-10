import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import {
  successToNextResponse,
  errorToNextResponse,
  AppErrors,
} from "@/lib/errors"

/**
 * POST /api/briefs - Create a new brief
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { rawInput } = body

    // Validate required field
    if (!rawInput || typeof rawInput !== "string" || rawInput.trim() === "") {
      return errorToNextResponse(
        AppErrors.validationError("rawInput is required", {
          rawInput: "Must be a non-empty string",
        })
      )
    }

    // Create brief with DRAFT status
    const brief = await prisma.brief.create({
      data: {
        rawInput: rawInput.trim(),
        status: "DRAFT",
      },
    })

    return successToNextResponse(brief, 201)
  } catch (error) {
    console.error("Error creating brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to create brief"
      )
    )
  }
}

/**
 * GET /api/briefs - List all briefs
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const limit = Math.min(parseInt(searchParams.get("limit") ?? "20"), 100)
    const offset = parseInt(searchParams.get("offset") ?? "0")

    const [briefs, total] = await Promise.all([
      prisma.brief.findMany({
        orderBy: { createdAt: "desc" },
        take: limit,
        skip: offset,
        select: {
          id: true,
          rawInput: true,
          status: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      prisma.brief.count(),
    ])

    // Truncate rawInput for list view
    const briefsWithTruncatedInput = briefs.map((brief) => ({
      ...brief,
      rawInput:
        brief.rawInput.length > 100
          ? brief.rawInput.slice(0, 100) + "..."
          : brief.rawInput,
    }))

    return successToNextResponse({
      items: briefsWithTruncatedInput,
      total,
      limit,
      offset,
    })
  } catch (error) {
    console.error("Error listing briefs:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to list briefs"
      )
    )
  }
}
