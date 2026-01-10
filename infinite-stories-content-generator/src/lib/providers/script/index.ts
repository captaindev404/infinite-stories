import { Effect } from "effect"
import type { IScriptProvider, ParsedBrief, Script, ScriptError } from "../types"

/**
 * Mock script provider for development and testing
 */
export function createMockScriptProvider(): IScriptProvider {
  return {
    name: "mock",
    generate(
      brief: ParsedBrief,
      count: number
    ): Effect.Effect<Script[], ScriptError> {
      return Effect.succeed(
        Array.from({ length: count }, (_, i) => ({
          id: `script-${Date.now()}-${i}`,
          hook: `${brief.hook} - Variation ${i + 1}`,
          testimonialScript: brief.testimonialPoints.join(" "),
          callToAction: "Download InfiniteStories today!",
          metadata: {
            tokensUsed: 150,
            provider: "mock",
          },
        }))
      )
    },
  }
}

// Export types for convenience
export type { IScriptProvider, ParsedBrief, Script, ScriptError }
