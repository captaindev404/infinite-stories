import { NextRequest } from "next/server"
import { prisma } from "@/lib/db"
import { successToNextResponse, errorToNextResponse, AppErrors } from "@/lib/errors/handlers"
import { deleteVideo } from "@/lib/r2/upload"
import { Effect } from "effect"

type RouteContext = {
  params: Promise<{ id: string }>
}

// GET /api/videos/[id] - Get video details
export async function GET(_request: NextRequest, context: RouteContext) {
  const { id } = await context.params

  try {
    const video = await prisma.video.findUnique({
      where: { id },
      include: {
        generation: {
          select: {
            id: true,
            briefId: true,
            status: true,
          },
        },
      },
    })

    if (!video) {
      return errorToNextResponse(AppErrors.videoNotFound(id))
    }

    return successToNextResponse({
      id: video.id,
      generationId: video.generationId,
      videoUrl: video.videoUrl,
      generationParams: video.generationParams,
      avatarProvider: video.avatarProvider,
      scriptProvider: video.scriptProvider,
      status: video.status,
      qualityStatus: video.qualityStatus,
      qualityNote: video.qualityNote,
      totalCost: video.totalCost.toString(),
      createdAt: video.createdAt.toISOString(),
      generation: {
        id: video.generation.id,
        briefId: video.generation.briefId,
        status: video.generation.status,
      },
    })
  } catch (error) {
    console.error("Get video error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}

// PATCH /api/videos/[id] - Update video (quality status, notes)
export async function PATCH(request: NextRequest, context: RouteContext) {
  const { id } = await context.params

  try {
    const body = await request.json()
    const { qualityStatus, qualityNote } = body

    const video = await prisma.video.findUnique({
      where: { id },
    })

    if (!video) {
      return errorToNextResponse(AppErrors.videoNotFound(id))
    }

    // Validate qualityStatus if provided
    const validStatuses = ["PENDING", "PASSED", "FLAGGED"]
    if (qualityStatus && !validStatuses.includes(qualityStatus)) {
      return errorToNextResponse(
        AppErrors.validation({ qualityStatus: "Must be PENDING, PASSED, or FLAGGED" })
      )
    }

    const updated = await prisma.video.update({
      where: { id },
      data: {
        ...(qualityStatus && { qualityStatus }),
        // If marking as PASSED, clear the note unless explicitly provided
        qualityNote:
          qualityNote !== undefined
            ? qualityNote
            : qualityStatus === "PASSED"
              ? null
              : undefined,
      },
    })

    return successToNextResponse({
      id: updated.id,
      qualityStatus: updated.qualityStatus,
      qualityNote: updated.qualityNote,
    })
  } catch (error) {
    console.error("Update video error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}

// DELETE /api/videos/[id] - Delete video
export async function DELETE(_request: NextRequest, context: RouteContext) {
  const { id } = await context.params

  try {
    const video = await prisma.video.findUnique({
      where: { id },
    })

    if (!video) {
      return errorToNextResponse(AppErrors.videoNotFound(id))
    }

    // Delete from R2 if URL exists
    if (video.videoUrl) {
      try {
        // Extract key from URL
        const url = new URL(video.videoUrl)
        const key = url.pathname.slice(1) // Remove leading slash
        await Effect.runPromise(deleteVideo(key))
      } catch (err) {
        console.warn(`Failed to delete video from R2: ${err}`)
        // Continue with DB deletion even if R2 fails
      }
    }

    // Delete from database (CostLogs will have videoId set to null due to onDelete: SetNull)
    await prisma.video.delete({
      where: { id },
    })

    return successToNextResponse({ deleted: true })
  } catch (error) {
    console.error("Delete video error:", error)
    return errorToNextResponse(
      AppErrors.provider("database", error instanceof Error ? error.message : "Unknown error")
    )
  }
}
