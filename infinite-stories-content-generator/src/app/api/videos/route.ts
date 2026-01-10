import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"

// GET /api/videos - List all videos with filters
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const limit = Math.min(parseInt(searchParams.get("limit") ?? "20"), 100)
    const offset = parseInt(searchParams.get("offset") ?? "0")
    const qualityStatus = searchParams.get("qualityStatus")
    const status = searchParams.get("status")
    const briefId = searchParams.get("briefId")
    const generationId = searchParams.get("generationId")

    // Build where clause
    const where: Record<string, unknown> = {}
    if (qualityStatus) where.qualityStatus = qualityStatus
    if (status) where.status = status
    if (generationId) where.generationId = generationId
    if (briefId) {
      where.generation = { briefId }
    }

    const [videos, total] = await Promise.all([
      prisma.video.findMany({
        where,
        orderBy: { createdAt: "desc" },
        take: limit,
        skip: offset,
        include: {
          generation: {
            select: {
              id: true,
              briefId: true,
            },
          },
        },
      }),
      prisma.video.count({ where }),
    ])

    return successToNextResponse({
      items: videos.map((v) => ({
        id: v.id,
        generationId: v.generationId,
        briefId: v.generation.briefId,
        videoUrl: v.videoUrl,
        status: v.status,
        qualityStatus: v.qualityStatus,
        qualityNote: v.qualityNote,
        avatarProvider: v.avatarProvider,
        scriptProvider: v.scriptProvider,
        totalCost: v.totalCost.toString(),
        createdAt: v.createdAt.toISOString(),
      })),
      total,
      limit,
      offset,
    })
  } catch (error) {
    console.error("List videos error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
