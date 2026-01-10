import { Effect } from "effect"
import { PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3"
import { r2Client, r2Config, isR2Configured } from "./client"

// ============================================
// ERROR TYPES
// ============================================

export type UploadError =
  | { _tag: "UploadFailed"; message: string; key: string }
  | { _tag: "R2NotConfigured"; message: string }
  | { _tag: "UploadTimeout"; key: string }

export type DeleteError =
  | { _tag: "DeleteFailed"; message: string; key: string }
  | { _tag: "R2NotConfigured"; message: string }

// ============================================
// UPLOAD FUNCTIONS
// ============================================

/**
 * Upload a video buffer to R2 storage
 * Returns the public URL on success
 */
export function uploadVideo(
  buffer: Buffer,
  key: string
): Effect.Effect<string, UploadError> {
  return Effect.tryPromise({
    try: async () => {
      // Check configuration
      if (!isR2Configured()) {
        throw { _tag: "R2NotConfigured" as const, message: "R2 environment variables not configured" }
      }

      const command = new PutObjectCommand({
        Bucket: r2Config.bucketName,
        Key: key,
        Body: buffer,
        ContentType: "video/mp4",
      })

      await r2Client.send(command)

      // Return the public URL
      return getVideoUrl(key)
    },
    catch: (error) => {
      // Check if it's already our error type
      if (error && typeof error === "object" && "_tag" in error) {
        return error as UploadError
      }

      // Wrap unknown errors
      return {
        _tag: "UploadFailed" as const,
        message: error instanceof Error ? error.message : "Unknown upload error",
        key,
      }
    },
  })
}

/**
 * Upload any buffer with custom content type
 */
export function uploadBuffer(
  buffer: Buffer,
  key: string,
  contentType: string
): Effect.Effect<string, UploadError> {
  return Effect.tryPromise({
    try: async () => {
      if (!isR2Configured()) {
        throw { _tag: "R2NotConfigured" as const, message: "R2 environment variables not configured" }
      }

      const command = new PutObjectCommand({
        Bucket: r2Config.bucketName,
        Key: key,
        Body: buffer,
        ContentType: contentType,
      })

      await r2Client.send(command)
      return getVideoUrl(key)
    },
    catch: (error) => {
      if (error && typeof error === "object" && "_tag" in error) {
        return error as UploadError
      }
      return {
        _tag: "UploadFailed" as const,
        message: error instanceof Error ? error.message : "Unknown upload error",
        key,
      }
    },
  })
}

// ============================================
// URL HELPERS
// ============================================

/**
 * Get the public URL for a stored object
 * Uses R2's public bucket URL format
 */
export function getVideoUrl(key: string): string {
  // Public R2 bucket URL format
  // Note: This requires the bucket to have public access enabled
  return `https://${r2Config.bucketName}.${r2Config.accountId}.r2.dev/${key}`
}

/**
 * Generate a unique key for video storage
 */
export function generateVideoKey(generationId: string, videoId: string): string {
  return `generations/${generationId}/${videoId}.mp4`
}

// ============================================
// DELETE FUNCTIONS
// ============================================

/**
 * Delete a video from R2 storage
 */
export function deleteVideo(key: string): Effect.Effect<void, DeleteError> {
  return Effect.tryPromise({
    try: async () => {
      if (!isR2Configured()) {
        throw { _tag: "R2NotConfigured" as const, message: "R2 environment variables not configured" }
      }

      const command = new DeleteObjectCommand({
        Bucket: r2Config.bucketName,
        Key: key,
      })

      await r2Client.send(command)
    },
    catch: (error) => {
      if (error && typeof error === "object" && "_tag" in error) {
        return error as DeleteError
      }
      return {
        _tag: "DeleteFailed" as const,
        message: error instanceof Error ? error.message : "Unknown delete error",
        key,
      }
    },
  })
}
