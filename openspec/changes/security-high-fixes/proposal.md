## Why

The security audit (2026-03-28) identified 6 HIGH severity issues that could lead to budget drain through misconfigured rate limits, information leakage through proxied error messages, mass assignment vulnerabilities, and SSRF risks through client-supplied URLs.

## What Changes

### HIGH-1: Fix Rate Limits — Wire to Environment Variables
- **File:** `lib/rate-limit/db-rate-limiter.ts`
- Replace hardcoded 1,000/hr limits with env var values
- Defaults: 5/hr story generation, 10/hr audio, 3/hr avatar, 20/hr illustration
- Add validation that limits are positive integers

### HIGH-2: Fix Auth Error Handling
- **File:** `lib/auth/session.ts` + `lib/utils/api-response.ts`
- Change exact string match to `.includes('Unauthorized')` or introduce custom `AuthenticationError` class
- Ensure all auth failures return 401, not 500

### HIGH-3: Remove Mass Assignment Fields
- **File:** `app/api/v1/custom-events/[eventId]/route.ts`
- Remove `usageCount` and `lastUsedAt` from client-settable PATCH fields
- These should only be updated server-side (on story creation, event usage)

### HIGH-4: Remove Client-Supplied avatarUrl from Hero Creation
- **File:** `app/api/v1/heroes/route.ts`
- Remove `avatarUrl`, `avatarPrompt`, `avatarGenerationId` from POST body acceptance
- These fields should only be set via the dedicated avatar generation endpoint

### HIGH-5: Sanitize OpenAI Error Responses
- **Files:** All routes that call OpenAI (`stories/generate`, `audio/generate`, `images/*`)
- Log full OpenAI error server-side
- Return sanitized error to client: `{ error: "AI service error", code: "RATE_LIMIT" | "AI_ERROR" }`

### HIGH-6: Add Input Length Validation + Prompt Injection Defense
- **Files:** `app/api/v1/ai-assistant/*.ts`, `app/api/v1/audio/generate/route.ts`
- Add MAX_LENGTH validation on all text inputs (description: 2000, text: 10000, prompt: 1000)
- Wrap user content in XML delimiters (`<user_input>...</user_input>`) in all prompts
- Add system instruction that content between tags is untrusted

## Impact

- **Backend:** 10+ route files modified, rate limiter config change, error handler fix
- **iOS app:** No changes needed
- **Risk:** Low — tightening existing behavior, not changing API contracts
