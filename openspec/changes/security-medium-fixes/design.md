## Context

The security audit (2026-03-28) identified 9 MEDIUM severity issues. CRITICAL and HIGH fixes are already deployed (auth guards, Zod validation, CORS, rate limits, error sanitization, prompt injection defense, mass assignment prevention). These MEDIUM fixes address remaining gaps: missing security headers, pagination abuse, prompt injection in scene extraction, IDOR in analytics, Docker hardening, and production error sanitization.

**Stakeholders**: Security, Backend
**Constraints**: Deployed on Dokploy (standard Node.js runtime). Next.js 16 App Router. Better Auth for sessions. iOS app requires no changes.

## Goals / Non-Goals

**Goals:**
- Add HTTP security headers (HSTS, CSP, X-Frame-Options, etc.)
- Cap pagination to prevent resource exhaustion
- Fix prompt injection in scene extraction (missed in HIGH fixes)
- Sanitize stored audioGenerationError messages
- Fix IDOR in analytics sessions endpoint
- Harden Docker compose for development
- Make handleApiError production-safe (no stack traces)
- Validate audioUrl in batch import to prevent SSRF
- Decide on email verification strategy

**Non-Goals:**
- Implementing a full email service (deferred — Apple Sign-In covers most users)
- Adding CSP nonce support (requires significant SSR changes)
- Rate limiting per-IP (requires Redis, covered in infrastructure roadmap)

## Decisions

### Decision 1: Email Verification — Document Deferral

**What**: Keep `requireEmailVerification: false` and document the rationale. Add a TODO with clear migration steps for when email verification is needed.

**Why**: The primary auth flow is Sign in with Apple (email already verified by Apple). The email/password flow is secondary. Adding email verification requires an email service (Resend/SendGrid), DNS records, and transactional email templates — significant effort for low current impact. The audit flagged it as MEDIUM, not CRITICAL.

**Alternatives considered**:
- Enable immediately with Resend: Deferred — adds external dependency and cost for minimal current benefit
- Block email/password sign-up: Too aggressive — useful for development and testing

### Decision 2: Pagination — Server-Side Cap with Safe Defaults

**What**: Add a `clampPagination(limit, offset)` utility that caps `limit` at 100 and ensures `offset` is non-negative. Handle NaN from parseInt gracefully.

**Why**: Uncapped `limit` allows a single request to fetch the entire database. While auth prevents anonymous access, a compromised token could exfiltrate all data. The cap limits blast radius.

**Pattern**:
```typescript
// lib/api/pagination.ts
export function clampPagination(rawLimit?: string | null, rawOffset?: string | null) {
  const limit = Math.min(Math.max(parseInt(rawLimit || '', 10) || 50, 1), 100);
  const offset = Math.max(parseInt(rawOffset || '', 10) || 0, 0);
  return { limit, offset };
}
```

### Decision 3: Scene Extraction — Apply Existing Prompt Safety

**What**: Apply `wrapUserInput()` and `UNTRUSTED_INPUT_INSTRUCTION` from the HIGH fixes to the scene extraction endpoint's `storyContent` and `eventContext` fields.

**Why**: Scene extraction was missed in the HIGH prompt injection sweep because it uses `withAuth` (no body validation schema initially), but it still interpolates user content into prompts. The `prompt-safety.ts` utilities already exist — just need to apply them.

### Decision 4: Security Headers — Next.js Config

**What**: Add security headers via `next.config.ts` headers configuration. This covers all routes without middleware changes.

**Headers**:
- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: origin-when-cross-origin`
- `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https:; connect-src 'self' https://api.openai.com`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`

**Why**: `next.config.ts` headers apply globally and don't require middleware changes. The CSP is permissive (`unsafe-inline` for styles, `unsafe-eval` for Next.js hydration) — tightening requires nonce support which is a larger effort.

**Alternatives considered**:
- Middleware headers: Rejected — middleware already handles CORS; adding more headers there increases complexity
- Strict CSP with nonces: Deferred — requires `nonce` generation per request and `Script` component changes

### Decision 5: Docker Compose — Environment Variable Credentials

**What**: Replace hardcoded `postgres:password` with `${POSTGRES_PASSWORD:-$(openssl rand -hex 16)}` pattern. Remove port 5432 binding, use Docker internal network only. Add `.env.docker.example`.

**Why**: Even in development, hardcoded credentials are a bad habit that can leak into CI/CD or be copied to production configs. Internal-only networking prevents accidental exposure.

### Decision 6: Production Error Sanitization in handleApiError

**What**: In production (`NODE_ENV=production`), replace generic `error.message` with "An unexpected error occurred" for 500 responses. Keep detailed messages for 4xx responses (validation, not found, etc.) and in development.

**Why**: Stack traces and internal error details in 500 responses leak implementation details. 4xx errors (validation, auth) are safe to return since they describe client mistakes, not server internals.

**Pattern**:
```typescript
// In handleApiError, for the generic 500 fallback:
const isProduction = process.env.NODE_ENV === 'production';
return errorResponse(
  'InternalServerError',
  isProduction ? 'An unexpected error occurred' : error.message,
  500
);
```

### Decision 7: audioUrl Validation — R2 URL Pattern

**What**: Validate that `audioUrl` in batch import matches the expected R2 URL pattern (`https://<R2_PUBLIC_URL>/...`). Reject arbitrary external URLs.

**Why**: Accepting arbitrary URLs allows SSRF — the server could be tricked into fetching internal resources. Restricting to the known R2 bucket URL eliminates this vector.

### Decision 8: IDOR Fix — Story Ownership Check

**What**: In the analytics sessions endpoint, when filtering by `storyId`, verify the story belongs to the requesting user before returning results.

**Why**: Without this check, any authenticated user could query analytics for any story by guessing IDs, leaking usage data.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| CSP too permissive (`unsafe-inline`) | Acceptable for now; strict CSP with nonces is a separate project |
| Pagination cap may break existing clients requesting >100 items | iOS app uses default pagination; cap at 100 is generous |
| Docker compose changes may break existing local setups | Document migration in README; old `.env` files still work |
| Production error sanitization hides debugging info | Full errors logged server-side; add request ID for correlation |

## Migration Plan

1. Create `lib/api/pagination.ts` utility
2. Apply pagination caps to all list endpoints
3. Apply prompt safety to scene extraction
4. Add security headers to `next.config.ts`
5. Fix IDOR in analytics sessions
6. Sanitize audioGenerationError storage
7. Update handleApiError for production
8. Validate audioUrl in batch import
9. Harden Docker compose
10. Document email verification deferral
11. Deploy to dev → staging → production

**Rollback**: Revert the commit. No schema migrations, no data changes.

## Open Questions

- Should we add a request ID header to all responses for log correlation?
- Should the CSP be further relaxed for external image sources (user avatars)?
