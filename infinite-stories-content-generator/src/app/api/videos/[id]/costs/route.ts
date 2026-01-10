import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"

type RouteContext = {
  params: Promise<{ id: string }>
}

// GET /api/videos/[id]/costs - Get cost breakdown for a video
export async function GET(_request: NextRequest, context: RouteContext) {
  const { id: videoId } = await context.params

  try {
    const video = await prisma.video.findUnique({
      where: { id: videoId },
      select: { id: true, totalCost: true },
    })

    if (!video) {
      return errorToNextResponse(AppErrors.videoNotFound(videoId))
    }

    const costLogs = await prisma.costLog.findMany({
      where: { videoId },
      orderBy: { createdAt: "asc" },
    })

    // Group by service type
    const byServiceType: Record<string, number> = {
      script: 0,
      avatar: 0,
      video: 0,
      storage: 0,
    }

    const breakdown = costLogs.map((log) => {
      const cost = log.cost.toNumber()
      if (log.serviceType in byServiceType) {
        byServiceType[log.serviceType] += cost
      }

      return {
        id: log.id,
        serviceType: log.serviceType,
        provider: log.provider,
        operation: log.operation,
        inputUnits: log.inputUnits,
        outputUnits: log.outputUnits,
        unitType: log.unitType,
        cost: log.cost.toString(),
        createdAt: log.createdAt.toISOString(),
      }
    })

    return successToNextResponse({
      videoId,
      totalCost: video.totalCost.toString(),
      byServiceType: {
        script: byServiceType.script.toFixed(6),
        avatar: byServiceType.avatar.toFixed(6),
        video: byServiceType.video.toFixed(6),
        storage: byServiceType.storage.toFixed(6),
      },
      breakdown,
    })
  } catch (error) {
    console.error("Get video costs error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
