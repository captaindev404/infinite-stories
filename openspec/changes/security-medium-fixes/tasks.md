## 1. Pagination Capping

- [x] 1.1 Create `lib/api/pagination.ts` with `clampPagination(rawLimit, rawOffset)` utility (max 100, default 50, offset >= 0)
- [x] 1.2 Apply `clampPagination` to `app/api/v1/heroes/route.ts` GET handler
- [x] 1.3 Apply `clampPagination` to `app/api/v1/stories/route.ts` GET handler (if pagination exists)
- [x] 1.4 Apply `clampPagination` to any other list endpoints with `limit`/`offset` params

## 2. Scene Extraction Prompt Safety

- [x] 2.1 Apply `wrapUserInput()` to `storyContent` in `app/api/v1/stories/extract-scenes/route.ts`
- [x] 2.2 Apply `wrapUserInput()` to `eventContext` in `app/api/v1/stories/extract-scenes/route.ts`
- [x] 2.3 Add `UNTRUSTED_INPUT_INSTRUCTION` to the system prompt in scene extraction

## 3. HTTP Security Headers

- [x] 3.1 Add security headers to `next.config.ts`: `Strict-Transport-Security`, `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Content-Security-Policy`, `Permissions-Policy`

## 4. Analytics IDOR Fix

- [x] 4.1 In analytics sessions endpoint, add story ownership check when filtering by `storyId`
- [x] 4.2 Return 403 if the requesting user does not own the story

## 5. Audio Error Sanitization

- [x] 5.1 Sanitize `audioGenerationError` before storing in database (strip model names, token counts, raw errors)
- [x] 5.2 Ensure stored error messages are generic (e.g., "Audio generation failed")

## 6. Production Error Sanitization

- [x] 6.1 Update `handleApiError()` in `lib/utils/api-response.ts` to return generic message for 500s in production
- [x] 6.2 Keep detailed error messages for 4xx responses in all environments
- [x] 6.3 Keep detailed error messages for all responses in development

## 7. Batch Import URL Validation

- [x] 7.1 Add R2 URL pattern validation to `app/api/batch/stories/route.ts` for `audioUrl`
- [x] 7.2 Reject external URLs that don't match `R2_PUBLIC_URL` pattern

## 8. Docker Compose Hardening

- [x] 8.1 Replace hardcoded `postgres:password` with `${POSTGRES_PASSWORD}` env var substitution
- [x] 8.2 Remove host port 5432 binding (use Docker internal network only)
- [x] 8.3 Create `.env.docker.example` with documented variables

## 9. Email Verification Documentation

- [x] 9.1 Update comment in `lib/auth/auth.ts` explaining deferral rationale and migration steps

## 10. Verification

- [x] 10.1 Verify `npm run build` passes
- [ ] 10.2 Deploy to dev and verify
- [ ] 10.3 Deploy to staging and verify
- [ ] 10.4 Deploy to production
