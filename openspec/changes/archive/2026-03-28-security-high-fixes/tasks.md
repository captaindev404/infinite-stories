## 1. Rate Limit Configuration

- [x] 1.1 Add `parseEnvInt(key, fallback)` helper in `lib/rate-limit/db-rate-limiter.ts`
- [x] 1.2 Replace hardcoded `1000` limits with env var lookups: `RATE_LIMIT_STORY_GENERATION` (default 5), `RATE_LIMIT_AUDIO_GENERATION` (default 10), `RATE_LIMIT_AVATAR_GENERATION` (default 3), `RATE_LIMIT_ILLUSTRATION_GENERATION` (default 20), `RATE_LIMIT_AI_ASSISTANT` (default 30)
- [x] 1.3 Add rate limit env vars to `.env.example` with documented defaults

## 2. Auth Error Handling

- [x] 2.1 Create `AuthenticationError` class in `lib/utils/api-response.ts`
- [x] 2.2 Update `handleApiError()` to check `instanceof AuthenticationError` before string matching
- [x] 2.3 Update `requireAuthOrThrow()` in `lib/auth/session.ts` to throw `AuthenticationError` instead of generic `Error`

## 3. Mass Assignment Prevention

- [x] 3.1 Add `UpdateCustomEventSchema` to `lib/api/schemas.ts` (exclude `usageCount`, `lastUsedAt`)
- [x] 3.2 Apply `withAuthAndValidation` with `UpdateCustomEventSchema` to `app/api/v1/custom-events/[eventId]/route.ts` PATCH handler
- [x] 3.3 Add `CreateHeroSchema` to `lib/api/schemas.ts` (exclude `avatarUrl`, `avatarPrompt`, `avatarGenerationId`)
- [x] 3.4 Apply `withAuthAndValidation` with `CreateHeroSchema` to `app/api/v1/heroes/route.ts` POST handler

## 4. OpenAI Error Sanitization

- [x] 4.1 Create `lib/api/ai-errors.ts` with `sanitizeAIError(error)` utility
- [x] 4.2 Apply `sanitizeAIError` to `app/api/v1/stories/generate/route.ts`
- [x] 4.3 Apply `sanitizeAIError` to `app/api/v1/stories/generate-custom/route.ts`
- [x] 4.4 Apply `sanitizeAIError` to `app/api/v1/audio/generate/route.ts`
- [x] 4.5 Apply `sanitizeAIError` to `app/api/v1/images/generate-avatar/route.ts`
- [x] 4.6 Apply `sanitizeAIError` to `app/api/v1/images/generate-illustration/route.ts`
- [x] 4.7 Apply `sanitizeAIError` to `app/api/v1/images/generate-pictogram/route.ts`
- [x] 4.8 Apply `sanitizeAIError` to all `app/api/v1/ai-assistant/*/route.ts` endpoints

## 5. Prompt Injection Defense

- [x] 5.1 Create `lib/api/prompt-safety.ts` with `wrapUserInput(input)` and `UNTRUSTED_INPUT_INSTRUCTION` constant
- [x] 5.2 Apply prompt sandboxing to `app/api/v1/stories/generate/route.ts` (hero traits, event description)
- [x] 5.3 Apply prompt sandboxing to `app/api/v1/stories/generate-custom/route.ts`
- [x] 5.4 Apply prompt sandboxing to `app/api/v1/ai-assistant/enhance-prompt/route.ts` (title, description, category, ageRange, tone)
- [x] 5.5 Apply prompt sandboxing to `app/api/v1/ai-assistant/generate-keywords/route.ts`
- [x] 5.6 Apply prompt sandboxing to `app/api/v1/ai-assistant/generate-title/route.ts`
- [x] 5.7 Apply prompt sandboxing to `app/api/v1/ai-assistant/sanitize-prompt/route.ts`
- [x] 5.8 Apply prompt sandboxing to `app/api/v1/ai-assistant/suggest-similar-events/route.ts`
- [x] 5.9 Apply prompt sandboxing to `app/api/v1/images/generate-avatar/route.ts` (prompt)
- [x] 5.10 Apply prompt sandboxing to `app/api/v1/images/generate-illustration/route.ts` (prompt)
- [x] 5.11 Apply prompt sandboxing to `app/api/v1/images/generate-pictogram/route.ts`

## 6. Verification

- [x] 6.1 Verify `npm run build` passes with all changes
- [x] 6.2 Add rate limit env vars to Dokploy dev environment
- [x] 6.3 Add rate limit env vars to Dokploy staging environment
- [x] 6.4 Add rate limit env vars to Dokploy production environment
- [x] 6.5 Deploy to dev and verify
- [x] 6.6 Deploy to staging and verify
- [x] 6.7 Deploy to production
