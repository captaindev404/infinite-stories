import { Effect } from "effect"

// ============================================
// DATA TYPES
// ============================================

/**
 * Parsed structure from natural language brief
 */
export type ParsedBrief = {
  hook: string
  persona: {
    type: string
    age: string
    demographic: string
    tone: string
  }
  emotion: string
  brollTags: string[]
  testimonialPoints: string[]
}

/**
 * Generated script for video
 */
export type Script = {
  id: string
  hook: string
  testimonialScript: string
  callToAction: string
  metadata: {
    tokensUsed: number
    provider: string
  }
}

/**
 * Generated avatar video clip
 */
export type AvatarClip = {
  id: string
  videoBuffer: Buffer
  durationSeconds: number
  metadata: {
    provider: string
    avatarId: string
    characterCount: number
  }
}

/**
 * B-roll clip from InfiniteStories
 */
export type BRollClip = {
  id: string
  url: string
  type: "image" | "video"
  tag: string
  durationSeconds?: number
}

/**
 * Composed final video
 */
export type ComposedVideo = {
  id: string
  videoBuffer: Buffer
  durationSeconds: number
  format: "mp4"
  resolution: {
    width: number
    height: number
  }
}

// ============================================
// ERROR TYPES (discriminated unions with _tag)
// ============================================

export type ScriptError =
  | { _tag: "ScriptGenerationFailed"; message: string; provider: string }
  | { _tag: "ScriptParseError"; message: string }
  | { _tag: "ScriptRateLimited"; retryAfter: number; provider: string }

export type AvatarError =
  | { _tag: "AvatarGenerationFailed"; message: string; provider: string }
  | { _tag: "AvatarInvalidScript"; message: string }
  | { _tag: "AvatarRateLimited"; retryAfter: number; provider: string }

export type VideoError =
  | { _tag: "VideoCompositionFailed"; message: string }
  | { _tag: "VideoInvalidInput"; message: string }
  | { _tag: "VideoEncodingFailed"; message: string }

// ============================================
// PROVIDER INTERFACES
// ============================================

/**
 * Script generation provider interface
 * Generates multiple scripts from a parsed brief
 */
export type IScriptProvider = {
  readonly name: string
  generate(
    brief: ParsedBrief,
    count: number
  ): Effect.Effect<Script[], ScriptError>
}

/**
 * Avatar generation provider interface
 * Creates AI avatar video from script
 */
export type IAvatarProvider = {
  readonly name: string
  generate(script: Script): Effect.Effect<AvatarClip, AvatarError>
}

/**
 * Video composition provider interface
 * Composes avatar with B-roll into final video
 */
export type IVideoProvider = {
  readonly name: string
  compose(
    avatar: AvatarClip,
    broll: BRollClip[]
  ): Effect.Effect<ComposedVideo, VideoError>
}

// ============================================
// PROVIDER CONFIG
// ============================================

export type ProviderType = "script" | "avatar" | "video"

export type ProviderConfig = {
  script: {
    provider: string
    apiKey?: string
  }
  avatar: {
    provider: string
    apiKey?: string
  }
  video: {
    provider: string
  }
}
