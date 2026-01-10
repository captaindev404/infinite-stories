/**
 * Application Error Types
 * All errors use discriminated unions with _tag for type safety
 */

// ============================================
// BRIEF ERRORS
// ============================================

export type BriefNotFound = {
  _tag: "BriefNotFound"
  briefId: string
}

export type BriefParseError = {
  _tag: "BriefParseError"
  message: string
  rawInput?: string
}

// ============================================
// GENERATION ERRORS
// ============================================

export type GenerationNotFound = {
  _tag: "GenerationNotFound"
  generationId: string
}

export type GenerationFailed = {
  _tag: "GenerationFailed"
  generationId: string
  stage: string
  message: string
}

// ============================================
// VIDEO ERRORS
// ============================================

export type VideoNotFound = {
  _tag: "VideoNotFound"
  videoId: string
}

export type VideoCompositionError = {
  _tag: "VideoCompositionError"
  message: string
  videoId?: string
}

// ============================================
// PROVIDER ERRORS
// ============================================

export type ProviderError = {
  _tag: "ProviderError"
  provider: string
  message: string
  code?: string
}

// ============================================
// STORAGE ERRORS
// ============================================

export type UploadError = {
  _tag: "UploadError"
  message: string
  key?: string
}

export type DownloadError = {
  _tag: "DownloadError"
  message: string
  url?: string
}

// ============================================
// RATE LIMITING
// ============================================

export type RateLimited = {
  _tag: "RateLimited"
  retryAfter: number
  provider?: string
}

// ============================================
// VALIDATION & AUTH
// ============================================

export type ValidationError = {
  _tag: "ValidationError"
  message: string
  fields: Record<string, string>
}

export type Unauthorized = {
  _tag: "Unauthorized"
  message: string
}

// ============================================
// UNION TYPE
// ============================================

/**
 * All possible application errors
 */
export type AppError =
  | BriefNotFound
  | BriefParseError
  | GenerationNotFound
  | GenerationFailed
  | VideoNotFound
  | VideoCompositionError
  | ProviderError
  | UploadError
  | DownloadError
  | RateLimited
  | ValidationError
  | Unauthorized

/**
 * API Response wrapper type
 */
export type ApiResponse<T> = {
  data: T | null
  error: AppError | null
  meta: { timestamp: string }
}
