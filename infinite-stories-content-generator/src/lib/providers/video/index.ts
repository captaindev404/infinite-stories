import { Effect } from "effect"
import type {
  IVideoProvider,
  AvatarClip,
  BRollClip,
  ComposedVideo,
  VideoError,
} from "../types"

/**
 * Mock video provider for development and testing
 */
export function createMockVideoProvider(): IVideoProvider {
  return {
    name: "mock",
    compose(
      avatar: AvatarClip,
      _broll: BRollClip[]
    ): Effect.Effect<ComposedVideo, VideoError> {
      return Effect.succeed({
        id: `video-${Date.now()}`,
        videoBuffer: Buffer.from("mock-composed-video"),
        durationSeconds: avatar.durationSeconds + 5,
        format: "mp4",
        resolution: {
          width: 1080,
          height: 1920, // 9:16 TikTok format
        },
      })
    },
  }
}

// Export types for convenience
export type { IVideoProvider, AvatarClip, BRollClip, ComposedVideo, VideoError }
