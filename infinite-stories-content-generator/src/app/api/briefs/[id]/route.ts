import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import {
  successToNextResponse,
  errorToNextResponse,
  AppErrors,
} from "@/lib/errors"

type RouteParams = {
  params: Promise<{ id: string }>
}

/**
 * GET /api/briefs/[id] - Get a single brief
 */
export async function GET(_request: NextRequest, { params }: RouteParams) {
  try {
    const { id } = await params

    const brief = await prisma.brief.findUnique({
      where: { id },
      include: {
        generations: {
          orderBy: { createdAt: "desc" },
          take: 5,
          select: {
            id: true,
            status: true,
            targetCount: true,
            totalCost: true,
            createdAt: true,
          },
        },
      },
    })

    if (!brief) {
      return errorToNextResponse(AppErrors.briefNotFound(id))
    }

    return successToNextResponse(brief)
  } catch (error) {
    console.error("Error fetching brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to fetch brief"
      )
    )
  }
}

/**
 * PATCH /api/briefs/[id] - Update a brief
 */
export async function PATCH(request: NextRequest, { params }: RouteParams) {
  try {
    const { id } = await params
    const body = await request.json()
    const { rawInput } = body

    // Check if brief exists
    const existing = await prisma.brief.findUnique({ where: { id } })
    if (!existing) {
      return errorToNextResponse(AppErrors.briefNotFound(id))
    }

    // Validate rawInput if provided
    if (rawInput !== undefined) {
      if (typeof rawInput !== "string" || rawInput.trim() === "") {
        return errorToNextResponse(
          AppErrors.validationError("Invalid rawInput", {
            rawInput: "Must be a non-empty string",
          })
        )
      }
    }

    // Update brief - reset to DRAFT if rawInput changed
    const brief = await prisma.brief.update({
      where: { id },
      data: {
        ...(rawInput && {
          rawInput: rawInput.trim(),
          parsedData: null, // Clear parsed data on edit
          status: "DRAFT", // Reset to draft
        }),
      },
    })

    return successToNextResponse(brief)
  } catch (error) {
    console.error("Error updating brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to update brief"
      )
    )
  }
}

/**
 * DELETE /api/briefs/[id] - Delete a brief
 */
export async function DELETE(_request: NextRequest, { params }: RouteParams) {
  try {
    const { id } = await params

    // Check if brief exists
    const existing = await prisma.brief.findUnique({ where: { id } })
    if (!existing) {
      return errorToNextResponse(AppErrors.briefNotFound(id))
    }

    await prisma.brief.delete({ where: { id } })

    return successToNextResponse({ deleted: true, id })
  } catch (error) {
    console.error("Error deleting brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to delete brief"
      )
    )
  }
}
