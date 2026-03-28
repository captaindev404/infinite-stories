# Security Audit Report — InfiniteStories Backend

**Audit Date:** 2026-03-28
**Scope:** `infinite-stories-backend/` (Next.js API + Frontend)
**Auditor:** Claude Code

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | 3 |
| HIGH | 5 |
| MEDIUM | 9 |
| LOW | 6 |
| PASSED | 10 |

---

## CRITICAL — Must Fix Before Production

### CRIT-1: CORS Wildcard — All Origins Accepted

**File:** `middleware.ts` (line 17)

`Access-Control-Allow-Origin: *` is set on every route including authenticated API endpoints and Better Auth session endpoints. Any website can make cross-origin requests to the API. For Bearer token endpoints (used by the iOS app), a malicious site could make authenticated requests if it obtains a token.

**Fix:** Replace wildcard with explicit allowlist of known origins (capacitor://localhost, ionic://localhost, BETTER_AUTH_URL, NEXT_PUBLIC_APP_URL).

---

### CRIT-2: Thirteen Unauthenticated AI Endpoints

**Files:**
- `app/api/v1/stories/generate/route.ts`
- `app/api/v1/stories/generate-custom/route.ts`
- `app/api/v1/audio/generate/route.ts`
- `app/api/v1/images/generate-avatar/route.ts`
- `app/api/v1/images/generate-illustration/route.ts`
- `app/api/v1/images/generate-pictogram/route.ts`
- `app/api/v1/ai-assistant/enhance-prompt/route.ts`
- `app/api/v1/ai-assistant/generate-keywords/route.ts`
- `app/api/v1/ai-assistant/generate-title/route.ts`
- `app/api/v1/ai-assistant/sanitize-prompt/route.ts`
- `app/api/v1/ai-assistant/suggest-similar-events/route.ts`
- `app/api/v1/stories/extract-scenes/route.ts`
- `app/api/v1/heroes/[heroId]/visual-profile/extract/route.ts`

Every one of these routes calls OpenAI APIs (GPT-4o, DALL-E, TTS) with no authentication and no rate limiting. Anyone can drain the OpenAI budget. The audio endpoint accepts arbitrary text with no length limit (~$1.50/request at max length).

**Fix:** Add `requireAuth()` guard and rate limiting at the top of each handler.

---

### CRIT-3: Debug/Test Endpoint Exposed in Production

**File:** `app/api/test-auth/route.ts`

Logs raw Bearer tokens and Authorization headers to stdout via `console.log`. Accessible at `/api/test-auth` in production. Anyone with log access can steal user sessions.

**Fix:** Delete this file entirely.

---

### CRIT-4: Health Endpoint Leaks Infrastructure Configuration

**File:** `app/api/v1/health/route.ts` (lines 23-28)

The unauthenticated health endpoint names which specific environment variables are missing (e.g., "Missing environment variables: OPENAI_API_KEY, BETTER_AUTH_SECRET"). Also returns `NODE_ENV` value.

**Fix:** Return generic health status publicly. Move detailed diagnostics to admin-only endpoint.

---

## HIGH — Fix Soon

### HIGH-1: Rate Limits Set to 1,000/hr — Effectively No Limit

**File:** `lib/rate-limit/db-rate-limiter.ts` (lines 23-44)

All rate limits hardcoded to 1,000 requests/hour. 1,000 illustration requests/hour = $167/user/hour via gpt-image-1. The `.env.example` defines sensible limits (5/hr story, 3/hr avatar) but these are ignored.

**Fix:** Wire rate limits to environment variables: `parseInt(process.env.RATE_LIMIT_STORY_GENERATION || '5')`.

---

### HIGH-2: Auth Error Falls Through to 500

**File:** `lib/auth/session.ts` (line 56) + `lib/utils/api-response.ts` (line 58)

`getOrCreateUser()` throws "Unauthorized: User not authenticated" but `handleApiError()` checks for exact match `error.message === 'Unauthorized'`. Auth failures return 500 instead of 401.

**Fix:** Change to `error.message.includes('Unauthorized')` or use custom error class.

---

### HIGH-3: Mass Assignment — Client Controls Server-Side Fields

**File:** `app/api/v1/custom-events/[eventId]/route.ts` (lines 87-101)

PATCH endpoint accepts `usageCount` and `lastUsedAt` from client. These are server-side analytics fields that should never be client-settable.

**Fix:** Remove `usageCount` and `lastUsedAt` from PATCH-allowed fields.

---

### HIGH-4: Client-Supplied `avatarUrl` on Hero Creation (SSRF Risk)

**File:** `app/api/v1/heroes/route.ts` (lines 173-178)

Hero creation accepts `avatarUrl`, `avatarPrompt`, `avatarGenerationId` directly from client. Enables SSRF (e.g., `http://internal-service:6379/`) and bypasses the secure avatar generation pipeline.

**Fix:** Remove these fields from hero creation. Only set via dedicated `POST /heroes/[heroId]/avatar`.

---

### HIGH-5: OpenAI Error Bodies Proxied to Client

**Files:** Multiple route.ts files (stories/generate, audio/generate, images/*)

OpenAI error responses (model names, org IDs, quota details) forwarded verbatim to clients.

**Fix:** Log full error server-side, return sanitized error to client.

---

### HIGH-6: No Input Validation + Prompt Injection on AI Endpoints

**Files:** `app/api/v1/ai-assistant/*.ts`, `app/api/v1/audio/generate/route.ts`

No text length limits on any AI input. Audio endpoint accepts unlimited text. AI assistant routes have no sanitization before prompt building, enabling prompt injection.

**Fix:** Add MAX_LENGTH validation. Wrap user content in XML delimiters in prompts.

---

## MEDIUM — Address Before Scale

### MED-1: Email Verification Disabled
**File:** `lib/auth/auth.ts:29` — `requireEmailVerification: false`. Anyone can create accounts with emails they don't control.

### MED-2: No Pagination Limit Cap
**Files:** `heroes/route.ts:36`, `stories/route.ts:234` — No max cap on `limit` param. `limit=100000` loads entire table.

### MED-3: Prompt Injection in Scene Extraction
**File:** `stories/extract-scenes/route.ts:111` — Story content interpolated directly into system prompt without delimiters.

### MED-4: Raw OpenAI Errors in audioGenerationError
**File:** `stories/[storyId]/audio/route.ts:199` — `audioGenerationError` field contains raw OpenAI error details.

### MED-5: IDOR in Sessions GET by storyId
**File:** `analytics/sessions/route.ts:252` — No ownership verification when filtering sessions by storyId.

### MED-6: No HTTP Security Headers
**Files:** `middleware.ts`, `next.config.ts` — No CSP, X-Frame-Options, HSTS, X-Content-Type-Options.

### MED-7: Weak PostgreSQL Password + Exposed Port
**File:** `docker-compose.yml:10,13` — Default `postgres:password` with port 5432 exposed to host.

### MED-8: Internal Errors Leaked in handleApiError
**File:** `lib/utils/api-response.ts:80` — Unhandled errors forward `.message` to client (Prisma table names, stack traces).

### MED-9: Arbitrary audioUrl in Batch Import
**File:** `app/api/batch/stories/route.ts:73` — Client can set arbitrary `audioUrl` (SSRF, cross-user access).

---

## LOW — Nice to Have

### LOW-1: No Request Body Size Limits
No explicit body size limits on routes. Multi-megabyte payloads can trigger many chunked GPT-4o calls.

### LOW-2: Missing CORS Preflight Cache Header
`middleware.ts` — No `Access-Control-Max-Age` on OPTIONS responses.

### LOW-3: Story→User Cascade Missing
`prisma/schema.prisma` — No explicit `User` relation on `Story` model. Stories orphaned on user deletion.

### LOW-4: OAuth Tokens Stored in Plaintext
`prisma/schema.prisma:63` — `accessToken`/`refreshToken` in Account table stored unencrypted.

### LOW-5: 30-Day Session Lifetime
`lib/auth/auth.ts:43` — Long session for a children's data app. Consider 7 days with sliding renewal.

### LOW-6: No Request Body Size Limits per Route
No per-route size limits. `extract-scenes` accepts unlimited story content.

---

## PASSED — Areas That Look Good

1. **Ownership checks** on all resource CRUD endpoints (heroes, stories, events)
2. **Prisma ORM** — no raw SQL, no injection risk
3. **Docker non-root user** with dumb-init signal handling
4. **R2 signed URLs** with 15-minute expiry, 1-hour max cap
5. **Zod validation** on visual profile endpoint (model to follow)
6. **Content sanitization** on image generation (SanitizationService)
7. **No .env files in git history** — gitignore correctly configured
8. **Secure cookies in production** — `useSecureCookies` conditional on NODE_ENV
9. **Multi-stage Docker build** — minimal production image
10. **Rate limiting infrastructure** exists and is correctly implemented (values need tuning)
