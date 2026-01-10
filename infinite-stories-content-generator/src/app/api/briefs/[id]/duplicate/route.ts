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
 * POST /api/briefs/[id]/duplicate - Duplicate an existing brief
 */
export async function POST(_request: NextRequest, { params }: RouteParams) {
  try {
    const { id } = await params

    // Find original brief
    const original = await prisma.brief.findUnique({
      where: { id },
    })

    if (!original) {
      return errorToNextResponse(AppErrors.briefNotFound(id))
    }

    // Create duplicate with DRAFT status
    const duplicate = await prisma.brief.create({
      data: {
        rawInput: original.rawInput,
        status: "DRAFT",
        // parsedData is intentionally not copied - requires re-parsing
      },
    })

    return successToNextResponse(duplicate, 201)
  } catch (error) {
    console.error("Error duplicating brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "database",
        error instanceof Error ? error.message : "Failed to duplicate brief"
      )
    )
  }
}
