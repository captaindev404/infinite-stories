## Context

The security audit (2026-03-28) found that 13 AI-facing API endpoints have no authentication, the CORS policy allows all origins, a debug endpoint logs raw session tokens, and the health endpoint leaks environment variable names. The backend is a Next.js 16 App Router application using Better Auth for session management, Prisma for database access, and the OpenAI API for story/audio/illustration generation. The iOS app already sends Bearer tokens on all requests — adding server-side enforcement is purely additive with zero client-side changes.

**Stakeholders**: Security, Backend, iOS (no changes needed)
**Constraints**: Deployed on Dokploy (standard Node.js runtime via Nixpacks/Docker, NOT Vercel Edge Runtime). Middleware has full Node.js access including Prisma and Better Auth. Zod is already a dependency (used in visual-profile routes).

## Goals / Non-Goals

**Goals:**
- Block all unauthenticated access to AI endpoints (story, audio, image, ai-assistant)
- Validate all request bodies with Zod schemas (types, max lengths, required fields)
- Replace CORS wildcard with explicit origin allowlist
- Remove the debug endpoint that logs session tokens
- Sanitize the health endpoint to not leak env var names

**Non-Goals:**
- Changing the iOS app (it already sends auth headers)
- Adding Zod validation to non-AI endpoints (separate HIGH proposal covers those)
- Implementing request body size limits (covered in LOW proposal)
- Adding security headers (covered in MEDIUM proposal)

## Decisions

### Decision 1: CORS — Origin Allowlist in Middleware

**What**: Replace `Access-Control-Allow-Origin: *` with a dynamic allowlist that reads the `Origin` header and only reflects it if it's in the allowed set.

**Why**: The middleware runs on Dokploy with full Node.js runtime. CORS origin checking in middleware is the standard pattern for multiple allowed origins and avoids duplicating logic across 40+ routes.

**Allowlist** (covers all 3 Dokploy environments + local dev):
- `http://localhost:3000` — Local development
- `capacitor://localhost` — Capacitor mobile apps
- `ionic://localhost` — Ionic mobile apps
- `https://appleid.apple.com` — Sign in with Apple callbacks
- `process.env.BETTER_AUTH_URL` — Per-environment backend URL (dev: `https://infinite-stories-web-dev.captaindev.io`, staging: `https://infinite-stories-web-staging.captaindev.io`, production: `https://infinite-stories-web.captaindev.io`)
- `process.env.NEXT_PUBLIC_APP_URL` — Per-environment frontend URL (same as above, Next.js serves both)
- Requests with **no Origin header** (native iOS app sends Bearer tokens without Origin) must be allowed through — only restrict when Origin IS present and doesn't match

**Alternatives considered**:
- Move CORS to route handlers: Rejected — would require duplicating CORS logic in 40+ routes
- Use Next.js `headers()` config: Rejected — doesn't support dynamic origin matching

### Decision 2: Centralized Auth + Validation Wrapper

**What**: Create a `withAuthAndValidation<T>(schema: ZodSchema<T>, handler: (user, body: T) => Response)` utility that wraps route handlers with auth check, Zod parsing, and rate limiting in a single function call.

**Why**: 13 routes need the same pattern. A wrapper avoids duplicating auth+validation boilerplate and ensures consistency. The visual-profile route already uses Zod — this extends the pattern project-wide.

**Pattern**:
```typescript
// lib/api/with-auth.ts
export async function withAuthAndValidation<T>(
  request: Request,
  schema: ZodSchema<T>,
  operation: RateLimitOperation,
  handler: (user: AuthUser, body: T) => Promise<Response>
): Promise<Response> {
  const user = await requireAuth();
  if (!user) return errorResponse('Unauthorized', 'Authentication required', 401);

  await enforceRateLimit(user.id, operation);

  const body = await request.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) return errorResponse('ValidationError', formatZodErrors(parsed.error), 400);

  return handler(user, parsed.data);
}
```

**Alternatives considered**:
- Per-route inline validation: Rejected — 13x code duplication, inconsistent error formats
- Middleware-level auth: Possible on Dokploy (full Node.js runtime), but Better Auth's `getSession()` uses `headers()` from `next/headers` which works best in route handlers. Keeping auth in the wrapper function is cleaner and more testable.

### Decision 3: Zod Schemas in Dedicated File

**What**: Create `lib/api/schemas.ts` with all request body Zod schemas. Each schema enforces types, max lengths, enums, and required fields.

**Why**: Centralized schemas are testable, reusable, and serve as living documentation of the API contract. Max lengths prevent budget abuse (e.g., 10,000 char limit on TTS text prevents $1.50/request attacks).

**Key constraints**:
- `text` for TTS: max 10,000 characters (~$0.15/request vs $1.50 uncapped)
- `prompt` for avatars: max 500 characters
- `prompt` for illustrations: max 1,000 characters
- `description` for AI assistant: max 2,000 characters
- `storyContent` for scene extraction: max 50,000 characters
- `language`: enum of supported languages (en, fr, es, de, it)
- `voice`: enum of supported voices (alloy, echo, fable, onyx, nova, shimmer, coral)

### Decision 4: Health Endpoint — Split Public/Private

**What**: The public `/api/v1/health` returns only `{ status: "healthy" | "unhealthy" }`. Missing env var details are logged server-side only. Optionally, add an admin-only `/api/v1/health/detailed` behind auth for diagnostics.

**Why**: Leaking which env vars are missing gives attackers a precise map of the infrastructure. The public health endpoint is used by Dokploy for container health checks — it only needs a boolean signal.

### Decision 5: Delete test-auth, Don't Migrate

**What**: Delete `app/api/test-auth/route.ts` entirely. No replacement.

**Why**: The endpoint's only purpose is debugging auth during development. `console.log` of raw tokens is a liability. Better Auth provides its own `/api/auth/session` endpoint for session inspection, which doesn't log tokens.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Breaking iOS app if auth enforcement rejects valid requests | iOS already sends Bearer tokens; validate on staging first with TestFlight build |
| Zod validation too strict, rejecting valid requests | Start with permissive max lengths, tighten after observing real traffic patterns |
| CORS allowlist missing a legitimate origin | Include all known origins; add env var `ADDITIONAL_CORS_ORIGINS` for future additions |
| Rate limiting blocks legitimate heavy users | Current limits (5/hr story) are per-user; power users unlikely to hit this |

## Migration Plan

1. Create `lib/api/with-auth.ts` wrapper and `lib/api/schemas.ts`
2. Update CORS in `middleware.ts`
3. Delete `app/api/test-auth/route.ts`
4. Sanitize `app/api/v1/health/route.ts`
5. Apply `withAuthAndValidation` to all 13 AI routes
6. Deploy to dev, test with iOS app
7. Deploy to staging, test with TestFlight
8. Deploy to production

**Rollback**: Revert the commit. No schema migrations, no data changes.

## Open Questions

- Should `ADDITIONAL_CORS_ORIGINS` be a comma-separated env var for flexible origin management?
- Should Zod schemas be exported for potential client-side reuse (shared validation)?
