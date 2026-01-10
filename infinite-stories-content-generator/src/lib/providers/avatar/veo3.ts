import { Effect, Schedule, Duration } from "effect"
import type { IAvatarProvider, Script, AvatarClip, AvatarError } from "../types"

// Veo3 API configuration constants
const VEO3_MODEL = "veo-3.1-generate-preview"
const VEO3_ASPECT_RATIO = "9:16" // TikTok vertical format
const VEO3_RESOLUTION = "1080p"
const VEO3_DURATION_SECONDS = 8
const VEO3_COST_PER_SECOND = 0.4 // $0.40 per second for Veo 3.1
const POLL_INTERVAL_MS = 10000 // Poll every 10 seconds
const MAX_RETRIES = 3
const RETRY_DELAYS = [1000, 2000, 4000, 8000] // Exponential backoff

/**
 * Validates that required environment variables are set
 * @throws Error if VEO3_API_KEY is not configured
 */
function validateEnvironment(): string {
  const apiKey = process.env.VEO3_API_KEY
  if (!apiKey) {
    throw new Error(
      "VEO3_API_KEY environment variable is required. " +
        "Get your API key from https://ai.google.dev/ and add it to your .env.local file."
    )
  }
  return apiKey
}

/**
 * Generates a prompt for Veo3 based on the script content
 */
function generatePrompt(script: Script): string {
  return `Generate a realistic UGC-style testimonial video of a person speaking directly to camera with enthusiastic energy.
They should deliver this script naturally: "${script.testimonialScript}"
The setting should be casual and authentic, like a home environment.
The person should be expressive and genuine, making eye contact with the camera.
Natural lighting and a clean background are preferred.`
}

/**
 * Downloads video from the given URI and returns it as a Buffer
 */
async function downloadVideo(uri: string): Promise<Buffer> {
  const response = await fetch(uri)
  if (!response.ok) {
    throw new Error(`Failed to download video: ${response.status} ${response.statusText}`)
  }
  const arrayBuffer = await response.arrayBuffer()
  return Buffer.from(arrayBuffer)
}

/**
 * Creates a Veo3 avatar provider instance
 * Uses Google's Veo 3 API for generating AI avatar testimonial videos
 */
export function createVeo3AvatarProvider(): IAvatarProvider {
  // Validate environment on provider creation
  const apiKey = validateEnvironment()

  return {
    name: "veo3",

    generate(script: Script): Effect.Effect<AvatarClip, AvatarError> {
      const prompt = generatePrompt(script)

      // Create the main generation effect with retry logic
      const generateWithRetry = Effect.tryPromise({
        try: async () => {
          // Dynamically import to avoid issues if package not installed
          const { GoogleGenAI } = await import("@google/genai")

          const client = new GoogleGenAI({ apiKey })

          // Start video generation (long-running operation)
          let operation = await client.models.generateVideos({
            model: VEO3_MODEL,
            prompt,
            config: {
              aspectRatio: VEO3_ASPECT_RATIO,
              resolution: VEO3_RESOLUTION,
              durationSeconds: String(VEO3_DURATION_SECONDS),
            },
          })

          // Poll until operation completes
          while (!operation.done) {
            await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS))
            operation = await client.operations.getVideosOperation({
              operation,
            })
          }

          // Extract video URI from response
          const videoUri = operation.response?.generatedVideos?.[0]?.video?.uri
          if (!videoUri) {
            throw new Error("No video generated in response")
          }

          // Download the video
          const videoBuffer = await downloadVideo(videoUri)

          // Create AvatarClip result
          const avatarClip: AvatarClip = {
            id: `veo3-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
            videoBuffer,
            durationSeconds: VEO3_DURATION_SECONDS,
            metadata: {
              provider: "veo3",
              avatarId: `veo3-${Date.now()}`,
              characterCount: script.testimonialScript.length,
            },
          }

          return avatarClip
        },
        catch: (error): AvatarError => ({
          _tag: "AvatarGenerationFailed",
          message: error instanceof Error ? error.message : String(error),
          provider: "veo3",
        }),
      })

      // Apply retry policy with exponential backoff
      const retrySchedule = Schedule.exponential(Duration.millis(1000), 2).pipe(
        Schedule.compose(Schedule.recurs(MAX_RETRIES))
      )

      return generateWithRetry.pipe(
        Effect.retry(retrySchedule),
        Effect.catchAll((error) =>
          Effect.fail({
            _tag: "AvatarGenerationFailed" as const,
            message: `Failed after ${MAX_RETRIES + 1} attempts: ${error.message}`,
            provider: "veo3",
          })
        )
      )
    },
  }
}

/**
 * Calculates the cost for a Veo3 video generation
 * @param durationSeconds - Duration of the generated video
 * @returns Cost in USD
 */
export function calculateVeo3Cost(durationSeconds: number): number {
  return durationSeconds * VEO3_COST_PER_SECOND
}

// Export constants for testing
export const VEO3_CONFIG = {
  model: VEO3_MODEL,
  aspectRatio: VEO3_ASPECT_RATIO,
  resolution: VEO3_RESOLUTION,
  durationSeconds: VEO3_DURATION_SECONDS,
  costPerSecond: VEO3_COST_PER_SECOND,
  maxRetries: MAX_RETRIES,
  retryDelays: RETRY_DELAYS,
}
