import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"
import { startGenerationPipeline } from "@/lib/services/generation-pipeline"

type RouteContext = {
  params: Promise<{ id: string }>
}

// POST /api/videos/[id]/iterate - Create iterations based on a winning video
export async function POST(request: NextRequest, context: RouteContext) {
  const { id: videoId } = await context.params

  try {
    const body = await request.json()
    const { targetCount, variationParams } = body

    // Validate targetCount
    if (typeof targetCount !== "number" || targetCount < 1 || targetCount > 10) {
      return errorToNextResponse(
        AppErrors.validation({ targetCount: "Must be between 1 and 10" })
      )
    }

    // Get the source video
    const video = await prisma.video.findUnique({
      where: { id: videoId },
      include: {
        generation: {
          include: {
            brief: true,
          },
        },
      },
    })

    if (!video) {
      return errorToNextResponse(AppErrors.videoNotFound(videoId))
    }

    // Check video is approved
    if (video.qualityStatus !== "PASSED") {
      return errorToNextResponse(
        AppErrors.validation({ video: "Only approved videos can be used for iteration" })
      )
    }

    // Check brief is parsed
    if (video.generation.brief.status !== "PARSED") {
      return errorToNextResponse(
        AppErrors.validation({ brief: "Brief must be parsed" })
      )
    }

    // Create new generation with parent reference
    const generation = await prisma.generation.create({
      data: {
        briefId: video.generation.briefId,
        parentGenerationId: video.generationId,
        targetCount,
        status: "PENDING",
        totalCost: 0,
      },
    })

    // Store variation params in generation metadata (we'll handle this via a separate update)
    // For now, the pipeline will use the original brief params

    // Trigger pipeline asynchronously
    startGenerationPipeline(generation.id).catch((err) => {
      console.error(`Iteration pipeline failed for ${generation.id}:`, err)
    })

    return successToNextResponse({
      id: generation.id,
      briefId: generation.briefId,
      parentGenerationId: generation.parentGenerationId,
      sourceVideoId: videoId,
      targetCount: generation.targetCount,
      status: generation.status,
      variationParams,
      createdAt: generation.createdAt.toISOString(),
    })
  } catch (error) {
    console.error("Create iteration error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
