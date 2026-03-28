## Why

The security audit (2026-03-28) identified 9 MEDIUM severity issues covering information leakage, missing security headers, pagination abuse, prompt injection, IDOR vulnerabilities, and infrastructure hardening.

## What Changes

### MED-1: Enable Email Verification
- **File:** `lib/auth/auth.ts`
- Set `requireEmailVerification: true` or document the decision to rely on Apple Sign-In only
- If enabling, integrate an email service (e.g., Resend, SendGrid)

### MED-2: Cap Pagination Limits
- **Files:** `heroes/route.ts`, `stories/route.ts`, all list endpoints
- Cap `limit` at 100, validate `offset` is non-negative
- Handle NaN from `parseInt` gracefully (default to 50)

### MED-3: Fix Prompt Injection in Scene Extraction
- **File:** `stories/extract-scenes/route.ts`
- Wrap `storyContent` in XML delimiters (`<story_content>...</story_content>`)
- Add system instruction that content between tags is untrusted user content

### MED-4: Sanitize audioGenerationError
- **File:** `stories/[storyId]/audio/route.ts`
- Translate raw OpenAI error codes to user-friendly messages before storing/returning
- Strip model names, token counts, and internal details

### MED-5: Fix IDOR in Sessions by storyId
- **File:** `analytics/sessions/route.ts`
- When filtering by `storyId`, verify the story belongs to the requesting user
- Return 403 if user doesn't own the story

### MED-6: Add HTTP Security Headers
- **File:** `next.config.ts` or `middleware.ts`
- Add: `Strict-Transport-Security`, `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: origin-when-cross-origin`, `Content-Security-Policy`

### MED-7: Harden Docker Compose for Development
- **File:** `docker-compose.yml`
- Remove port 5432 binding (use Docker internal network only)
- Generate strong random password instead of `postgres:password`
- Add `.env` template for docker-compose credentials

### MED-8: Sanitize handleApiError for Production
- **File:** `lib/utils/api-response.ts`
- In production, replace `error.message` with generic "An unexpected error occurred"
- Keep detailed messages in development only
- Log full error server-side always

### MED-9: Validate audioUrl in Batch Import
- **File:** `app/api/batch/stories/route.ts`
- Validate `audioUrl` matches expected R2 URL pattern
- Reject arbitrary external URLs to prevent SSRF

## Impact

- **Backend:** 12+ files modified across middleware, routes, config
- **iOS app:** No changes needed
- **Infrastructure:** Docker compose hardening
- **Risk:** Low — all changes are defensive hardening
