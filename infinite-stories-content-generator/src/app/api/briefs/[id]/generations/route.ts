import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"
import { startGenerationPipeline } from "@/lib/services/generation-pipeline"

type RouteContext = {
  params: Promise<{ id: string }>
}

// POST /api/briefs/[id]/generations - Create new generation
export async function POST(request: NextRequest, context: RouteContext) {
  const { id: briefId } = await context.params

  try {
    const body = await request.json()
    const { targetCount } = body

    // Validate targetCount
    if (typeof targetCount !== "number" || targetCount < 1 || targetCount > 10) {
      return errorToNextResponse(
        AppErrors.validation({ targetCount: "Must be between 1 and 10" })
      )
    }

    // Check brief exists and is parsed
    const brief = await prisma.brief.findUnique({
      where: { id: briefId },
    })

    if (!brief) {
      return errorToNextResponse(AppErrors.briefNotFound(briefId))
    }

    if (brief.status !== "PARSED") {
      return errorToNextResponse(
        AppErrors.validation({ brief: "Brief must be parsed before generating videos" })
      )
    }

    // Create generation record
    const generation = await prisma.generation.create({
      data: {
        briefId,
        targetCount,
        status: "PENDING",
        totalCost: 0,
      },
    })

    // Trigger pipeline asynchronously (fire and forget)
    startGenerationPipeline(generation.id).catch((err) => {
      console.error(`Generation pipeline failed for ${generation.id}:`, err)
    })

    return successToNextResponse({
      id: generation.id,
      briefId: generation.briefId,
      targetCount: generation.targetCount,
      status: generation.status,
      totalCost: generation.totalCost.toString(),
      createdAt: generation.createdAt.toISOString(),
    })
  } catch (error) {
    console.error("Create generation error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}

// GET /api/briefs/[id]/generations - List generations for a brief
export async function GET(_request: NextRequest, context: RouteContext) {
  const { id: briefId } = await context.params

  try {
    const brief = await prisma.brief.findUnique({
      where: { id: briefId },
    })

    if (!brief) {
      return errorToNextResponse(AppErrors.briefNotFound(briefId))
    }

    const generations = await prisma.generation.findMany({
      where: { briefId },
      orderBy: { createdAt: "desc" },
      include: {
        _count: {
          select: { videos: true },
        },
      },
    })

    return successToNextResponse({
      items: generations.map((gen) => ({
        id: gen.id,
        briefId: gen.briefId,
        targetCount: gen.targetCount,
        status: gen.status,
        totalCost: gen.totalCost.toString(),
        videoCount: gen._count.videos,
        createdAt: gen.createdAt.toISOString(),
      })),
      total: generations.length,
    })
  } catch (error) {
    console.error("List generations error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
