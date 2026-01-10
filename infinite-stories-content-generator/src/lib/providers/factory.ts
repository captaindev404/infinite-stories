import type {
  IScriptProvider,
  IAvatarProvider,
  IVideoProvider,
  ProviderType,
} from "./types"
import { createMockScriptProvider } from "./script"
import { createMockAvatarProvider, createVeo3AvatarProvider } from "./avatar"
import { createMockVideoProvider } from "./video"

/**
 * Factory function to create provider instances based on configuration
 * Uses environment variables or passed config to determine which provider to use
 */
export function createProvider<T extends ProviderType>(
  type: T,
  providerName?: string
): T extends "script"
  ? IScriptProvider
  : T extends "avatar"
    ? IAvatarProvider
    : IVideoProvider {
  const name = providerName ?? getDefaultProvider(type)

  switch (type) {
    case "script":
      return createScriptProvider(name) as ReturnType<typeof createProvider<T>>
    case "avatar":
      return createAvatarProvider(name) as ReturnType<typeof createProvider<T>>
    case "video":
      return createVideoProvider(name) as ReturnType<typeof createProvider<T>>
    default:
      throw new Error(`Unknown provider type: ${type}`)
  }
}

function getDefaultProvider(type: ProviderType): string {
  switch (type) {
    case "script":
      return process.env.SCRIPT_PROVIDER ?? "mock"
    case "avatar":
      return process.env.AVATAR_PROVIDER ?? "mock"
    case "video":
      return process.env.VIDEO_PROVIDER ?? "mock"
  }
}

function createScriptProvider(name: string): IScriptProvider {
  switch (name) {
    case "mock":
      return createMockScriptProvider()
    // Add real providers here:
    // case "openai":
    //   return createOpenAIScriptProvider()
    default:
      console.warn(`Unknown script provider: ${name}, using mock`)
      return createMockScriptProvider()
  }
}

function createAvatarProvider(name: string): IAvatarProvider {
  switch (name) {
    case "mock":
      return createMockAvatarProvider()
    case "veo3":
      return createVeo3AvatarProvider()
    default:
      console.warn(`Unknown avatar provider: ${name}, using mock`)
      return createMockAvatarProvider()
  }
}

function createVideoProvider(name: string): IVideoProvider {
  switch (name) {
    case "mock":
      return createMockVideoProvider()
    // Add real providers here:
    // case "ffmpeg":
    //   return createFFmpegVideoProvider()
    default:
      console.warn(`Unknown video provider: ${name}, using mock`)
      return createMockVideoProvider()
  }
}

// Convenience functions for getting providers
export function getScriptProvider(): IScriptProvider {
  return createProvider("script")
}

export function getAvatarProvider(): IAvatarProvider {
  return createProvider("avatar")
}

export function getVideoProvider(): IVideoProvider {
  return createProvider("video")
}
