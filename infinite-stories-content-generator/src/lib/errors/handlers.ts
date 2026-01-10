import { NextResponse } from "next/server"
import type { AppError, ApiResponse } from "./types"

/**
 * Map error types to HTTP status codes
 */
function getStatusCode(error: AppError): number {
  switch (error._tag) {
    // 400 Bad Request
    case "BriefParseError":
    case "ValidationError":
    case "VideoCompositionError":
      return 400

    // 401 Unauthorized
    case "Unauthorized":
      return 401

    // 404 Not Found
    case "BriefNotFound":
    case "GenerationNotFound":
    case "VideoNotFound":
      return 404

    // 429 Too Many Requests
    case "RateLimited":
      return 429

    // 500 Internal Server Error
    case "GenerationFailed":
    case "ProviderError":
    case "UploadError":
    case "DownloadError":
      return 500

    default:
      return 500
  }
}

/**
 * Convert AppError to API response format
 */
export function errorToResponse<T = null>(error: AppError): ApiResponse<T> {
  return {
    data: null,
    error,
    meta: { timestamp: new Date().toISOString() },
  }
}

/**
 * Convert AppError to NextResponse with proper status code
 */
export function errorToNextResponse(error: AppError): NextResponse {
  const status = getStatusCode(error)
  const response = errorToResponse(error)

  const nextResponse = NextResponse.json(response, { status })

  // Add Retry-After header for rate limiting
  if (error._tag === "RateLimited") {
    nextResponse.headers.set("Retry-After", String(error.retryAfter))
  }

  return nextResponse
}

/**
 * Create success response in API wrapper format
 */
export function successResponse<T>(data: T): ApiResponse<T> {
  return {
    data,
    error: null,
    meta: { timestamp: new Date().toISOString() },
  }
}

/**
 * Convert success data to NextResponse
 */
export function successToNextResponse<T>(data: T, status = 200): NextResponse {
  return NextResponse.json(successResponse(data), { status })
}

/**
 * Helper to create specific errors
 */
export const AppErrors = {
  briefNotFound: (briefId: string): AppError => ({
    _tag: "BriefNotFound",
    briefId,
  }),

  briefParseError: (message: string, rawInput?: string): AppError => ({
    _tag: "BriefParseError",
    message,
    rawInput,
  }),

  generationNotFound: (generationId: string): AppError => ({
    _tag: "GenerationNotFound",
    generationId,
  }),

  generationFailed: (
    generationId: string,
    stage: string,
    message: string
  ): AppError => ({
    _tag: "GenerationFailed",
    generationId,
    stage,
    message,
  }),

  videoNotFound: (videoId: string): AppError => ({
    _tag: "VideoNotFound",
    videoId,
  }),

  videoCompositionError: (message: string, videoId?: string): AppError => ({
    _tag: "VideoCompositionError",
    message,
    videoId,
  }),

  providerError: (provider: string, message: string, code?: string): AppError => ({
    _tag: "ProviderError",
    provider,
    message,
    code,
  }),

  uploadError: (message: string, key?: string): AppError => ({
    _tag: "UploadError",
    message,
    key,
  }),

  downloadError: (message: string, url?: string): AppError => ({
    _tag: "DownloadError",
    message,
    url,
  }),

  rateLimited: (retryAfter: number, provider?: string): AppError => ({
    _tag: "RateLimited",
    retryAfter,
    provider,
  }),

  validationError: (message: string, fields: Record<string, string>): AppError => ({
    _tag: "ValidationError",
    message,
    fields,
  }),

  // Short-hand for field validation errors
  validation: (fields: Record<string, string>): AppError => ({
    _tag: "ValidationError",
    message: "Validation failed",
    fields,
  }),

  unauthorized: (message = "Unauthorized"): AppError => ({
    _tag: "Unauthorized",
    message,
  }),

  // Alias for backwards compatibility
  provider: (provider: string, message: string, code?: string): AppError => ({
    _tag: "ProviderError",
    provider,
    message,
    code,
  }),
}
