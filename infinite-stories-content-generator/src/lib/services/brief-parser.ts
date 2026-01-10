import { Effect } from "effect"
import type { ParsedBrief, ScriptError } from "@/lib/providers/types"

/**
 * Parse a natural language brief into structured data
 * This is a mock implementation - replace with real AI provider
 */
export function parseBrief(
  rawInput: string
): Effect.Effect<ParsedBrief, ScriptError> {
  return Effect.try({
    try: () => {
      // Mock parsing logic - extracts key elements from the text
      const words = rawInput.toLowerCase().split(/\s+/)

      // Extract hook (first sentence or first 10 words)
      const sentences = rawInput.split(/[.!?]+/)
      const hook = sentences[0]?.trim() || rawInput.slice(0, 50)

      // Mock persona detection based on keywords
      const persona = detectPersona(words)

      // Mock emotion detection
      const emotion = detectEmotion(words)

      // Extract potential B-roll tags from the text
      const brollTags = extractBrollTags(rawInput)

      // Extract testimonial points (sentences after the first)
      const testimonialPoints = sentences
        .slice(1)
        .map((s) => s.trim())
        .filter((s) => s.length > 10)
        .slice(0, 5)

      if (testimonialPoints.length === 0) {
        testimonialPoints.push("Great experience with the app")
        testimonialPoints.push("My kids love the stories")
      }

      return {
        hook,
        persona,
        emotion,
        brollTags,
        testimonialPoints,
      }
    },
    catch: (error) => ({
      _tag: "ScriptParseError" as const,
      message: error instanceof Error ? error.message : "Failed to parse brief",
    }),
  })
}

function detectPersona(words: string[]): ParsedBrief["persona"] {
  // Default persona
  let type = "parent"
  let age = "30-40"
  let demographic = "general"
  let tone = "enthusiastic"

  // Simple keyword detection
  if (words.includes("mom") || words.includes("mother")) {
    type = "mother"
    demographic = "female"
  } else if (words.includes("dad") || words.includes("father")) {
    type = "father"
    demographic = "male"
  } else if (words.includes("grandparent") || words.includes("grandma") || words.includes("grandpa")) {
    type = "grandparent"
    age = "55-65"
  }

  if (words.includes("professional") || words.includes("busy")) {
    tone = "professional"
  } else if (words.includes("fun") || words.includes("playful")) {
    tone = "playful"
  } else if (words.includes("calm") || words.includes("relaxing")) {
    tone = "calm"
  }

  return { type, age, demographic, tone }
}

function detectEmotion(words: string[]): string {
  if (words.some((w) => ["love", "amazing", "wonderful", "fantastic"].includes(w))) {
    return "joy"
  }
  if (words.some((w) => ["calm", "peaceful", "relaxing", "soothing"].includes(w))) {
    return "serenity"
  }
  if (words.some((w) => ["exciting", "adventure", "fun", "thrilling"].includes(w))) {
    return "excitement"
  }
  if (words.some((w) => ["trust", "safe", "reliable", "secure"].includes(w))) {
    return "trust"
  }
  return "warmth"
}

function extractBrollTags(text: string): string[] {
  const tags: string[] = []

  // Common B-roll scene keywords
  const sceneKeywords: Record<string, string> = {
    bedtime: "child-sleeping",
    sleep: "cozy-bedroom",
    story: "reading-together",
    read: "book-closeup",
    kid: "happy-child",
    child: "child-playing",
    family: "family-moment",
    parent: "parent-child",
    night: "nighttime-routine",
    dream: "dreamy-clouds",
    imagination: "magical-scene",
    adventure: "adventure-scene",
    app: "app-interface",
    phone: "phone-usage",
    tablet: "tablet-usage",
  }

  const lowerText = text.toLowerCase()
  for (const [keyword, tag] of Object.entries(sceneKeywords)) {
    if (lowerText.includes(keyword) && !tags.includes(tag)) {
      tags.push(tag)
    }
  }

  // Default tags if none found
  if (tags.length === 0) {
    tags.push("child-sleeping", "reading-together", "app-interface")
  }

  return tags.slice(0, 6) // Max 6 B-roll tags
}
