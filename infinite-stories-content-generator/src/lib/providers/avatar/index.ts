import { Effect } from "effect"
import type { IAvatarProvider, Script, AvatarClip, AvatarError } from "../types"

/**
 * Mock avatar provider for development and testing
 */
export function createMockAvatarProvider(): IAvatarProvider {
  return {
    name: "mock",
    generate(script: Script): Effect.Effect<AvatarClip, AvatarError> {
      return Effect.succeed({
        id: `avatar-${Date.now()}`,
        videoBuffer: Buffer.from("mock-video-data"),
        durationSeconds: 30,
        metadata: {
          provider: "mock",
          avatarId: "mock-avatar-001",
          characterCount: script.testimonialScript.length,
        },
      })
    },
  }
}

// Export Veo3 provider
export { createVeo3AvatarProvider, calculateVeo3Cost, VEO3_CONFIG } from "./veo3"

// Export types for convenience
export type { IAvatarProvider, Script, AvatarClip, AvatarError }
