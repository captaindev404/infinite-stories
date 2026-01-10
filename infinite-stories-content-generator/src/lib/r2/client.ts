import { S3Client } from "@aws-sdk/client-s3"

/**
 * R2 Configuration from environment variables
 */
export const r2Config = {
  accountId: process.env.R2_ACCOUNT_ID ?? "",
  accessKeyId: process.env.R2_ACCESS_KEY_ID ?? "",
  secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? "",
  bucketName: process.env.R2_BUCKET_NAME ?? "",
}

/**
 * Cloudflare R2 client using AWS S3 SDK
 * R2 is S3-compatible, so we use the standard SDK with R2 endpoint
 */
export const r2Client = new S3Client({
  region: "auto",
  endpoint: `https://${r2Config.accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: r2Config.accessKeyId,
    secretAccessKey: r2Config.secretAccessKey,
  },
})

/**
 * Check if R2 is configured (has required env vars)
 */
export function isR2Configured(): boolean {
  return Boolean(
    r2Config.accountId &&
      r2Config.accessKeyId &&
      r2Config.secretAccessKey &&
      r2Config.bucketName
  )
}
