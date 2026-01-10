import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"

type RouteContext = {
  params: Promise<{ id: string }>
}

// GET /api/generations/[id] - Get generation details with videos
export async function GET(_request: NextRequest, context: RouteContext) {
  const { id } = await context.params

  try {
    const generation = await prisma.generation.findUnique({
      where: { id },
      include: {
        brief: {
          select: {
            id: true,
            rawInput: true,
            status: true,
          },
        },
        parentGeneration: {
          select: {
            id: true,
            createdAt: true,
          },
        },
        videos: {
          orderBy: { createdAt: "asc" },
          select: {
            id: true,
            videoUrl: true,
            status: true,
            qualityStatus: true,
            totalCost: true,
            createdAt: true,
          },
        },
        _count: {
          select: {
            videos: true,
            childGenerations: true,
          },
        },
      },
    })

    if (!generation) {
      return errorToNextResponse(AppErrors.generationNotFound(id))
    }

    const completedVideos = generation.videos.filter((v) => v.status === "COMPLETED").length
    const failedVideos = generation.videos.filter((v) => v.status === "FAILED").length

    return successToNextResponse({
      id: generation.id,
      briefId: generation.briefId,
      brief: generation.brief,
      parentGenerationId: generation.parentGenerationId,
      parentGeneration: generation.parentGeneration
        ? {
            id: generation.parentGeneration.id,
            createdAt: generation.parentGeneration.createdAt.toISOString(),
          }
        : null,
      targetCount: generation.targetCount,
      status: generation.status,
      totalCost: generation.totalCost.toString(),
      createdAt: generation.createdAt.toISOString(),
      videos: generation.videos.map((v) => ({
        id: v.id,
        videoUrl: v.videoUrl,
        status: v.status,
        qualityStatus: v.qualityStatus,
        totalCost: v.totalCost.toString(),
        createdAt: v.createdAt.toISOString(),
      })),
      progress: {
        total: generation.targetCount,
        completed: completedVideos,
        failed: failedVideos,
        pending: generation.targetCount - completedVideos - failedVideos,
      },
      childGenerationsCount: generation._count.childGenerations,
    })
  } catch (error) {
    console.error("Get generation error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
