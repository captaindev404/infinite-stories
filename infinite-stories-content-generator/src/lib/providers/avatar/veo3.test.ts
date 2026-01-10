import { describe, it, expect, vi, beforeEach, afterEach } from "vitest"
import { Effect, Exit } from "effect"
import type { Script } from "../types"

// Store mock functions for later access
const mockGenerateVideos = vi.fn()
const mockGetVideosOperation = vi.fn()

// Mock the @google/genai module with class syntax
vi.mock("@google/genai", () => ({
  GoogleGenAI: class MockGoogleGenAI {
    models = {
      generateVideos: mockGenerateVideos,
    }
    operations = {
      getVideosOperation: mockGetVideosOperation,
    }
    files = {
      download: vi.fn(),
    }
    constructor(_config: { apiKey?: string }) {
      // Mock constructor
    }
  },
}))

// Mock fetch for video download
const mockFetch = vi.fn()
global.fetch = mockFetch

describe("Veo3AvatarProvider", () => {
  const mockScript: Script = {
    id: "test-script-1",
    hook: "Are you tired of boring bedtime stories?",
    testimonialScript:
      "My kids absolutely love the personalized stories. Every night is an adventure!",
    callToAction: "Try InfiniteStories today!",
    metadata: {
      tokensUsed: 150,
      provider: "openai",
    },
  }

  beforeEach(() => {
    vi.clearAllMocks()
    // Set up environment variable
    process.env.VEO3_API_KEY = "test-api-key"
  })

  afterEach(() => {
    delete process.env.VEO3_API_KEY
  })

  describe("createVeo3AvatarProvider", () => {
    it("should create a provider with name 'veo3'", async () => {
      const { createVeo3AvatarProvider } = await import("./veo3")
      const provider = createVeo3AvatarProvider()
      expect(provider.name).toBe("veo3")
    })

    it("should throw error if VEO3_API_KEY is not set", async () => {
      delete process.env.VEO3_API_KEY
      // Clear module cache to re-evaluate with missing env var
      vi.resetModules()
      const { createVeo3AvatarProvider } = await import("./veo3")
      expect(() => createVeo3AvatarProvider()).toThrow(
        "VEO3_API_KEY environment variable is required"
      )
    })
  })

  describe("generate", () => {
    it("should return AvatarClip with valid video buffer on success", async () => {
      vi.resetModules()
      const { createVeo3AvatarProvider } = await import("./veo3")

      // Mock successful video generation (completed immediately)
      mockGenerateVideos.mockResolvedValue({
        name: "operation-123",
        done: true,
        response: {
          generatedVideos: [
            {
              video: {
                uri: "https://storage.googleapis.com/test-video.mp4",
              },
            },
          ],
        },
      })

      // Mock video download
      mockFetch.mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(1024)),
      })

      const provider = createVeo3AvatarProvider()
      const result = await Effect.runPromiseExit(provider.generate(mockScript))

      expect(Exit.isSuccess(result)).toBe(true)
      if (Exit.isSuccess(result)) {
        expect(result.value.videoBuffer).toBeInstanceOf(Buffer)
        expect(result.value.durationSeconds).toBe(8) // Default Veo3 duration
        expect(result.value.metadata.provider).toBe("veo3")
        expect(result.value.metadata.characterCount).toBe(
          mockScript.testimonialScript.length
        )
      }
    })

    it("should include correct metadata in AvatarClip", async () => {
      vi.resetModules()
      const { createVeo3AvatarProvider } = await import("./veo3")

      mockGenerateVideos.mockResolvedValue({
        name: "operation-123",
        done: true,
        response: {
          generatedVideos: [
            {
              video: {
                uri: "https://storage.googleapis.com/test-video.mp4",
              },
            },
          ],
        },
      })

      mockFetch.mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(1024)),
      })

      const provider = createVeo3AvatarProvider()
      const result = await Effect.runPromiseExit(provider.generate(mockScript))

      expect(Exit.isSuccess(result)).toBe(true)
      if (Exit.isSuccess(result)) {
        expect(result.value.metadata).toEqual({
          provider: "veo3",
          avatarId: expect.stringContaining("veo3-"),
          characterCount: mockScript.testimonialScript.length,
        })
      }
    })

    it("should call generateVideos with correct parameters", async () => {
      vi.resetModules()
      const { createVeo3AvatarProvider } = await import("./veo3")

      mockGenerateVideos.mockResolvedValue({
        name: "operation-123",
        done: true,
        response: {
          generatedVideos: [
            {
              video: {
                uri: "https://storage.googleapis.com/test-video.mp4",
              },
            },
          ],
        },
      })

      mockFetch.mockResolvedValue({
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(1024)),
      })

      const provider = createVeo3AvatarProvider()
      await Effect.runPromiseExit(provider.generate(mockScript))

      expect(mockGenerateVideos).toHaveBeenCalledWith({
        model: "veo-3.1-generate-preview",
        prompt: expect.stringContaining(mockScript.testimonialScript),
        config: {
          aspectRatio: "9:16",
          resolution: "1080p",
          durationSeconds: "8",
        },
      })
    })
  })

  describe("cost calculation", () => {
    it("should calculate cost at $0.40 per second for 8-second video", async () => {
      vi.resetModules()
      const { calculateVeo3Cost } = await import("./veo3")
      // Cost calculation: 8 seconds * $0.40/second = $3.20
      const cost = calculateVeo3Cost(8)
      expect(cost).toBe(3.2)
    })

    it("should calculate cost correctly for different durations", async () => {
      vi.resetModules()
      const { calculateVeo3Cost } = await import("./veo3")
      expect(calculateVeo3Cost(4)).toBeCloseTo(1.6, 5)
      expect(calculateVeo3Cost(6)).toBeCloseTo(2.4, 5)
    })
  })

  describe("VEO3_CONFIG", () => {
    it("should export correct configuration values", async () => {
      vi.resetModules()
      const { VEO3_CONFIG } = await import("./veo3")
      expect(VEO3_CONFIG.model).toBe("veo-3.1-generate-preview")
      expect(VEO3_CONFIG.aspectRatio).toBe("9:16")
      expect(VEO3_CONFIG.resolution).toBe("1080p")
      expect(VEO3_CONFIG.durationSeconds).toBe(8)
      expect(VEO3_CONFIG.costPerSecond).toBe(0.4)
      expect(VEO3_CONFIG.maxRetries).toBe(3)
    })
  })

})
