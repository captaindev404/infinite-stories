import { z } from 'zod';

// ──────────────────────────────────────────────
// Shared enums & reusable fragments
// ──────────────────────────────────────────────

const LanguageEnum = z.enum(['en', 'fr', 'es', 'de', 'it']);

const VoiceEnum = z.enum(['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer', 'coral']);

const HeroSchema = z.object({
  name: z.string().min(1).max(200),
  primaryTrait: z.string().min(1).max(200),
  secondaryTrait: z.string().min(1).max(200),
  appearance: z.string().max(500),
  specialAbility: z.string().max(500),
  avatarPrompt: z.string().max(500).optional(),
  avatarGenerationId: z.string().max(200).optional(),
});

const StoryEventSchema = z.object({
  rawValue: z.string().min(1).max(500),
  promptSeed: z.string().min(1).max(2000),
});

const CustomStoryEventSchema = z.object({
  title: z.string().min(1).max(500),
  promptSeed: z.string().min(1).max(2000),
  keywords: z.array(z.string().max(100)),
  tone: z.string().min(1).max(100),
  ageRange: z.string().min(1).max(50),
  category: z.string().min(1).max(100),
});

// ──────────────────────────────────────────────
// 1. POST /api/v1/stories/generate
// ──────────────────────────────────────────────
export const StoryGenerateSchema = z.object({
  hero: HeroSchema,
  event: StoryEventSchema,
  targetDuration: z.number().positive().max(3600),
  language: LanguageEnum,
});
export type StoryGenerateInput = z.infer<typeof StoryGenerateSchema>;

// ──────────────────────────────────────────────
// 2. POST /api/v1/stories/generate-custom
// ──────────────────────────────────────────────
export const StoryGenerateCustomSchema = z.object({
  hero: HeroSchema,
  customEvent: CustomStoryEventSchema,
  targetDuration: z.number().positive().max(3600),
  language: LanguageEnum,
});
export type StoryGenerateCustomInput = z.infer<typeof StoryGenerateCustomSchema>;

// ──────────────────────────────────────────────
// 3. POST /api/v1/audio/generate
// ──────────────────────────────────────────────
export const AudioGenerateSchema = z.object({
  text: z.string().min(1).max(50000),
  voice: VoiceEnum,
  language: LanguageEnum,
});
export type AudioGenerateInput = z.infer<typeof AudioGenerateSchema>;

// ──────────────────────────────────────────────
// 4. POST /api/v1/images/generate-avatar
// ──────────────────────────────────────────────
export const ImageGenerateAvatarSchema = z.object({
  prompt: z.string().min(1).max(500),
  hero: HeroSchema,
  size: z.string().max(20).optional(),
  quality: z.string().max(20).optional(),
  previousGenerationId: z.string().max(200).optional(),
});
export type ImageGenerateAvatarInput = z.infer<typeof ImageGenerateAvatarSchema>;

// ──────────────────────────────────────────────
// 5. POST /api/v1/images/generate-illustration
// ──────────────────────────────────────────────
export const ImageGenerateIllustrationSchema = z.object({
  prompt: z.string().min(1).max(1000),
  hero: HeroSchema,
  size: z.string().max(20).optional(),
  quality: z.string().max(20).optional(),
  previousGenerationId: z.string().max(200).optional(),
});
export type ImageGenerateIllustrationInput = z.infer<typeof ImageGenerateIllustrationSchema>;

// ──────────────────────────────────────────────
// 6. POST /api/v1/images/generate-pictogram
// ──────────────────────────────────────────────
export const ImageGeneratePictogramSchema = z.object({
  prompt: z.string().min(1).max(500),
  size: z.string().max(20).optional(),
  quality: z.string().max(20).optional(),
  previousGenerationId: z.string().max(200).optional(),
});
export type ImageGeneratePictogramInput = z.infer<typeof ImageGeneratePictogramSchema>;

// ──────────────────────────────────────────────
// 7. POST /api/v1/ai-assistant/enhance-prompt
// ──────────────────────────────────────────────
export const EnhancePromptSchema = z.object({
  title: z.string().min(1).max(500),
  description: z.string().min(1).max(2000),
  category: z.string().max(200).optional(),
  ageRange: z.string().max(50).optional(),
  tone: z.string().max(100).optional(),
});
export type EnhancePromptInput = z.infer<typeof EnhancePromptSchema>;

// ──────────────────────────────────────────────
// 8. POST /api/v1/ai-assistant/generate-keywords
// ──────────────────────────────────────────────
export const GenerateKeywordsSchema = z.object({
  event: z.string().min(1).max(500),
  description: z.string().min(1).max(2000),
});
export type GenerateKeywordsInput = z.infer<typeof GenerateKeywordsSchema>;

// ──────────────────────────────────────────────
// 9. POST /api/v1/ai-assistant/generate-title
// ──────────────────────────────────────────────
export const GenerateTitleSchema = z.object({
  description: z.string().min(1).max(2000),
  language: LanguageEnum.optional(),
});
export type GenerateTitleInput = z.infer<typeof GenerateTitleSchema>;

// ──────────────────────────────────────────────
// 10. POST /api/v1/ai-assistant/sanitize-prompt
// ──────────────────────────────────────────────
export const SanitizePromptSchema = z.object({
  prompt: z.string().min(1).max(10000),
});
export type SanitizePromptInput = z.infer<typeof SanitizePromptSchema>;

// ──────────────────────────────────────────────
// 11. POST /api/v1/ai-assistant/suggest-similar-events
// ──────────────────────────────────────────────
export const SuggestSimilarEventsSchema = z.object({
  description: z.string().min(1).max(2000),
});
export type SuggestSimilarEventsInput = z.infer<typeof SuggestSimilarEventsSchema>;

// ──────────────────────────────────────────────
// 12. POST /api/v1/stories/extract-scenes
// ──────────────────────────────────────────────
export const ExtractScenesSchema = z.object({
  storyContent: z.string().min(1).max(50000),
  storyDuration: z.number().positive(),
  hero: HeroSchema,
  eventContext: z.string().min(1).max(2000),
});
export type ExtractScenesInput = z.infer<typeof ExtractScenesSchema>;

// ──────────────────────────────────────────────
// 13. POST /api/v1/heroes/[heroId]/visual-profile/extract
//     (no body — uses heroId from URL params)
// ──────────────────────────────────────────────
// This endpoint has no request body. Auth is applied via withAuth (no schema).
