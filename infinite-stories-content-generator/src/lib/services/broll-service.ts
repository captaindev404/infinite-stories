import type { BRollClip } from "@/lib/providers/types"

/**
 * Fetches B-roll clips from InfiniteStories API based on tags
 * In MVP, this returns mock clips. Will be replaced with actual API integration.
 */
export async function fetchBRollClips(tags: string[]): Promise<BRollClip[]> {
  // TODO: Replace with actual InfiniteStories API call
  // For MVP, return mock B-roll clips based on tags

  const mockClips: BRollClip[] = tags.map((tag, index) => ({
    id: `broll-${index}-${Date.now()}`,
    url: `https://example.com/broll/${encodeURIComponent(tag)}.mp4`,
    type: "video" as const,
    tag,
    durationSeconds: 3 + Math.random() * 2, // 3-5 seconds
  }))

  // Simulate API delay
  await new Promise((resolve) => setTimeout(resolve, 100))

  return mockClips
}

/**
 * Fetches a single B-roll clip by tag with fallback
 */
export async function fetchBRollClipByTag(tag: string): Promise<BRollClip | null> {
  const clips = await fetchBRollClips([tag])
  return clips[0] ?? null
}

/**
 * Gets fallback B-roll clips when specific tags aren't available
 */
export function getFallbackBRollClips(count: number): BRollClip[] {
  const fallbacks = [
    { tag: "app-interface", url: "https://example.com/broll/app-interface.mp4" },
    { tag: "happy-child", url: "https://example.com/broll/happy-child.mp4" },
    { tag: "bedtime-scene", url: "https://example.com/broll/bedtime-scene.mp4" },
    { tag: "family-moment", url: "https://example.com/broll/family-moment.mp4" },
    { tag: "story-illustration", url: "https://example.com/broll/story-illustration.mp4" },
  ]

  return fallbacks.slice(0, count).map((f, i) => ({
    id: `fallback-${i}-${Date.now()}`,
    url: f.url,
    type: "video" as const,
    tag: f.tag,
    durationSeconds: 4,
  }))
}
