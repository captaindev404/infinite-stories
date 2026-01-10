import { NextRequest } from "next/server"
import { Effect } from "effect"
import { prisma } from "@/lib/db"
import {
  successToNextResponse,
  errorToNextResponse,
  AppErrors,
} from "@/lib/errors"
import { parseBrief } from "@/lib/services/brief-parser"

type RouteParams = {
  params: Promise<{ id: string }>
}

/**
 * POST /api/briefs/[id]/parse - Parse brief into structured JSON
 */
export async function POST(_request: NextRequest, { params }: RouteParams) {
  try {
    const { id } = await params

    // Find brief
    const brief = await prisma.brief.findUnique({
      where: { id },
    })

    if (!brief) {
      return errorToNextResponse(AppErrors.briefNotFound(id))
    }

    // Parse the brief using the parser service
    const parseResult = await Effect.runPromise(
      Effect.either(parseBrief(brief.rawInput))
    )

    if (parseResult._tag === "Left") {
      const error = parseResult.left
      const message = error._tag === "ScriptRateLimited"
        ? `Rate limited, retry after ${error.retryAfter}s`
        : error.message
      return errorToNextResponse(
        AppErrors.briefParseError(message, brief.rawInput)
      )
    }

    const parsedData = parseResult.right

    // Update brief with parsed data
    const updatedBrief = await prisma.brief.update({
      where: { id },
      data: {
        parsedData: parsedData as object,
        status: "PARSED",
      },
    })

    // Log cost for parsing operation (mock cost for now)
    // In real implementation, this would come from the AI provider
    await prisma.costLog.create({
      data: {
        serviceType: "script",
        provider: "mock",
        operation: "parse_brief",
        inputUnits: brief.rawInput.length,
        outputUnits: JSON.stringify(parsedData).length,
        unitType: "characters",
        cost: 0, // Mock - no cost
      },
    })

    return successToNextResponse(updatedBrief)
  } catch (error) {
    console.error("Error parsing brief:", error)
    return errorToNextResponse(
      AppErrors.providerError(
        "parser",
        error instanceof Error ? error.message : "Failed to parse brief"
      )
    )
  }
}
