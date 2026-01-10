import { Effect } from "effect"
import { prisma } from "@/lib/db"
import type { ParsedBrief, Script } from "@/lib/providers/types"
import { getScriptProvider, getAvatarProvider, getVideoProvider } from "@/lib/providers/factory"
import { fetchBRollClips } from "@/lib/services/broll-service"
import { uploadVideo } from "@/lib/r2/upload"
import { Decimal } from "@prisma/client/runtime/library"

type GenerationStatus =
  | "PENDING"
  | "QUEUED"
  | "SCRIPT_GEN"
  | "AVATAR_GEN"
  | "VIDEO_GEN"
  | "COMPOSITING"
  | "UPLOADING"
  | "COMPLETED"
  | "FAILED"

/**
 * Updates generation status in database
 */
async function updateGenerationStatus(generationId: string, status: GenerationStatus) {
  await prisma.generation.update({
    where: { id: generationId },
    data: { status },
  })
}

/**
 * Logs cost for an operation
 */
async function logCost(params: {
  videoId?: string
  serviceType: string
  provider: string
  operation: string
  inputUnits: number
  outputUnits: number
  unitType: string
  cost: number
}) {
  await prisma.costLog.create({
    data: {
      videoId: params.videoId,
      serviceType: params.serviceType,
      provider: params.provider,
      operation: params.operation,
      inputUnits: params.inputUnits,
      outputUnits: params.outputUnits,
      unitType: params.unitType,
      cost: params.cost,
    },
  })
}

/**
 * Creates a Video record for tracking
 */
async function createVideoRecord(
  generationId: string,
  script: Script,
  scriptProvider: string,
  avatarProvider: string
) {
  return await prisma.video.create({
    data: {
      generationId,
      status: "PENDING",
      qualityStatus: "PENDING",
      scriptProvider,
      avatarProvider,
      generationParams: {
        script: {
          hook: script.hook,
          testimonialScript: script.testimonialScript,
          callToAction: script.callToAction,
        },
      },
      totalCost: 0,
    },
  })
}

/**
 * Updates video status and optionally the URL
 */
async function updateVideoStatus(
  videoId: string,
  status: "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED",
  videoUrl?: string
) {
  await prisma.video.update({
    where: { id: videoId },
    data: {
      status,
      ...(videoUrl && { videoUrl }),
    },
  })
}

/**
 * Updates video total cost from sum of cost logs
 */
async function updateVideoTotalCost(videoId: string) {
  const costs = await prisma.costLog.aggregate({
    where: { videoId },
    _sum: { cost: true },
  })

  await prisma.video.update({
    where: { id: videoId },
    data: { totalCost: costs._sum.cost ?? 0 },
  })
}

/**
 * Updates generation total cost from sum of all video costs
 */
async function updateGenerationTotalCost(generationId: string) {
  const videos = await prisma.video.findMany({
    where: { generationId },
    select: { totalCost: true },
  })

  const total = videos.reduce(
    (sum, v) => sum.plus(v.totalCost),
    new Decimal(0)
  )

  await prisma.generation.update({
    where: { id: generationId },
    data: { totalCost: total },
  })
}

/**
 * Main generation pipeline - processes a generation asynchronously
 */
export async function startGenerationPipeline(generationId: string): Promise<void> {
  console.log(`[Pipeline] Starting generation ${generationId}`)

  try {
    // Load generation with brief
    const generation = await prisma.generation.findUnique({
      where: { id: generationId },
      include: { brief: true },
    })

    if (!generation) {
      throw new Error(`Generation ${generationId} not found`)
    }

    const parsedBrief = generation.brief.parsedData as ParsedBrief | null
    if (!parsedBrief) {
      throw new Error("Brief has no parsed data")
    }

    // Get providers
    const scriptProvider = getScriptProvider()
    const avatarProvider = getAvatarProvider()
    const videoProvider = getVideoProvider()

    // Stage 1: QUEUED
    await updateGenerationStatus(generationId, "QUEUED")
    console.log(`[Pipeline] ${generationId} - QUEUED`)

    // Stage 2: SCRIPT_GEN
    await updateGenerationStatus(generationId, "SCRIPT_GEN")
    console.log(`[Pipeline] ${generationId} - SCRIPT_GEN`)

    const scriptsResult = await Effect.runPromise(
      scriptProvider.generate(parsedBrief, generation.targetCount)
    )

    // Log script generation cost
    const totalTokens = scriptsResult.reduce((sum, s) => sum + s.metadata.tokensUsed, 0)
    await logCost({
      serviceType: "script",
      provider: scriptProvider.name,
      operation: "generate_scripts",
      inputUnits: JSON.stringify(parsedBrief).length,
      outputUnits: totalTokens,
      unitType: "tokens",
      cost: totalTokens * 0.00003, // Example pricing
    })

    console.log(`[Pipeline] ${generationId} - Generated ${scriptsResult.length} scripts`)

    // Stage 3: Fetch B-roll
    const brollClips = await fetchBRollClips(parsedBrief.brollTags)
    console.log(`[Pipeline] ${generationId} - Fetched ${brollClips.length} B-roll clips`)

    // Stage 4: AVATAR_GEN - Process each script
    await updateGenerationStatus(generationId, "AVATAR_GEN")
    console.log(`[Pipeline] ${generationId} - AVATAR_GEN`)

    const videoProcessingPromises = scriptsResult.map(async (script) => {
      // Create video record
      const video = await createVideoRecord(
        generationId,
        script,
        scriptProvider.name,
        avatarProvider.name
      )

      try {
        await updateVideoStatus(video.id, "PROCESSING")

        // Generate avatar
        const avatarResult = await Effect.runPromise(avatarProvider.generate(script))

        await logCost({
          videoId: video.id,
          serviceType: "avatar",
          provider: avatarProvider.name,
          operation: "generate_avatar",
          inputUnits: script.testimonialScript.length,
          outputUnits: avatarResult.durationSeconds,
          unitType: "seconds",
          cost: avatarResult.durationSeconds * 0.05, // Example pricing
        })

        // Compose video
        const composedResult = await Effect.runPromise(
          videoProvider.compose(avatarResult, brollClips)
        )

        await logCost({
          videoId: video.id,
          serviceType: "video",
          provider: videoProvider.name,
          operation: "compose_video",
          inputUnits: 1,
          outputUnits: composedResult.durationSeconds,
          unitType: "seconds",
          cost: 0.02, // Example pricing
        })

        // Upload to R2
        const uploadResult = await Effect.runPromise(
          uploadVideo(composedResult.videoBuffer, `generations/${generationId}/${video.id}.mp4`)
        )

        await logCost({
          videoId: video.id,
          serviceType: "storage",
          provider: "r2",
          operation: "upload_video",
          inputUnits: 0,
          outputUnits: composedResult.videoBuffer.length,
          unitType: "bytes",
          cost: composedResult.videoBuffer.length * 0.000000015, // Example pricing
        })

        // Update video as completed
        await updateVideoStatus(video.id, "COMPLETED", uploadResult)
        await updateVideoTotalCost(video.id)

        console.log(`[Pipeline] ${generationId} - Video ${video.id} completed`)
        return { success: true, videoId: video.id }
      } catch (error) {
        console.error(`[Pipeline] Video ${video.id} failed:`, error)
        await updateVideoStatus(video.id, "FAILED")

        // Update generation params with error
        await prisma.video.update({
          where: { id: video.id },
          data: {
            generationParams: {
              script: {
                hook: script.hook,
                testimonialScript: script.testimonialScript,
                callToAction: script.callToAction,
              },
              error: error instanceof Error ? error.message : "Unknown error",
            },
          },
        })

        return { success: false, videoId: video.id }
      }
    })

    // Process videos (could be parallel or sequential based on rate limits)
    await updateGenerationStatus(generationId, "VIDEO_GEN")
    console.log(`[Pipeline] ${generationId} - VIDEO_GEN`)

    await updateGenerationStatus(generationId, "COMPOSITING")
    console.log(`[Pipeline] ${generationId} - COMPOSITING`)

    await updateGenerationStatus(generationId, "UPLOADING")
    console.log(`[Pipeline] ${generationId} - UPLOADING`)

    const results = await Promise.all(videoProcessingPromises)

    // Update generation total cost
    await updateGenerationTotalCost(generationId)

    // Check results
    const successCount = results.filter((r) => r.success).length
    if (successCount === 0) {
      await updateGenerationStatus(generationId, "FAILED")
      console.log(`[Pipeline] ${generationId} - FAILED (no videos succeeded)`)
    } else {
      await updateGenerationStatus(generationId, "COMPLETED")
      console.log(`[Pipeline] ${generationId} - COMPLETED (${successCount}/${results.length} videos)`)
    }
  } catch (error) {
    console.error(`[Pipeline] Generation ${generationId} failed:`, error)
    await updateGenerationStatus(generationId, "FAILED")
    throw error
  }
}
