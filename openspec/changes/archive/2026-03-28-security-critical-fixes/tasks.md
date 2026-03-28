## 1. CORS Hardening

- [x] 1.1 Create CORS allowlist array in `middleware.ts` from env vars (`BETTER_AUTH_URL`, `NEXT_PUBLIC_APP_URL`) plus static origins (`http://localhost:3000`, `capacitor://localhost`, `ionic://localhost`, `https://appleid.apple.com`)
- [x] 1.2 Replace `Access-Control-Allow-Origin: *` with dynamic origin check: reflect origin only if in allowlist, skip header if no Origin present (native iOS)
- [x] 1.3 Add `Vary: Origin` header when origin is reflected
- [x] 1.4 Verify: request from allowed origin gets CORS headers, disallowed origin does not, no-Origin request passes through

## 2. Centralized Auth + Validation Utilities

- [x] 2.1 Create `lib/api/schemas.ts` with Zod schemas: `StoryGenerateSchema`, `StoryGenerateCustomSchema`, `AudioGenerateSchema`, `AvatarGenerateSchema`, `IllustrationGenerateSchema`, `PictogramGenerateSchema`, `AIAssistantEnhanceSchema`, `AIAssistantKeywordsSchema`, `AIAssistantTitleSchema`, `AIAssistantSanitizeSchema`, `AIAssistantSuggestSchema`, `SceneExtractSchema`, `VisualProfileExtractSchema`
- [x] 2.2 Define max lengths per schema: text 10000, prompt 500 (avatar) / 1000 (illustration), description 2000, storyContent 50000
- [x] 2.3 Define enums: language (`en`, `fr`, `es`, `de`, `it`), voice (`alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`, `coral`)
- [x] 2.4 Create `lib/api/with-auth.ts` with `withAuthAndValidation<T>(request, schema, operation, handler)` wrapper
- [x] 2.5 Create `lib/api/with-auth.ts` variant `withAuth(request, handler)` for endpoints that don't need body validation (GET routes)
- [x] 2.6 Add `formatZodErrors(error: ZodError)` helper that produces user-friendly validation messages

## 3. Apply Auth + Validation to AI Endpoints

- [x] 3.1 Apply `withAuthAndValidation` to `app/api/v1/stories/generate/route.ts`
- [x] 3.2 Apply `withAuthAndValidation` to `app/api/v1/stories/generate-custom/route.ts`
- [x] 3.3 Apply `withAuthAndValidation` to `app/api/v1/audio/generate/route.ts`
- [x] 3.4 Apply `withAuthAndValidation` to `app/api/v1/images/generate-avatar/route.ts`
- [x] 3.5 Apply `withAuthAndValidation` to `app/api/v1/images/generate-illustration/route.ts`
- [x] 3.6 Apply `withAuthAndValidation` to `app/api/v1/images/generate-pictogram/route.ts`
- [x] 3.7 Apply `withAuthAndValidation` to `app/api/v1/ai-assistant/enhance-prompt/route.ts`
- [x] 3.8 Apply `withAuthAndValidation` to `app/api/v1/ai-assistant/generate-keywords/route.ts`
- [x] 3.9 Apply `withAuthAndValidation` to `app/api/v1/ai-assistant/generate-title/route.ts`
- [x] 3.10 Apply `withAuthAndValidation` to `app/api/v1/ai-assistant/sanitize-prompt/route.ts`
- [x] 3.11 Apply `withAuthAndValidation` to `app/api/v1/ai-assistant/suggest-similar-events/route.ts`
- [x] 3.12 Apply `withAuth` to `app/api/v1/stories/extract-scenes/route.ts` (POST with body validation)
- [x] 3.13 Apply `withAuth` to `app/api/v1/heroes/[heroId]/visual-profile/extract/route.ts`

## 4. Delete Debug Endpoint

- [x] 4.1 Delete `app/api/test-auth/route.ts`
- [x] 4.2 Verify `GET /api/test-auth` returns 404

## 5. Sanitize Health Endpoint

- [x] 5.1 Remove env var names from error response in `app/api/v1/health/route.ts`
- [x] 5.2 Return `{ "status": "unhealthy" }` with 503 when misconfigured (no variable names)
- [x] 5.3 Log missing env var names server-side with `console.error`
- [x] 5.4 Remove `NODE_ENV` from success response body

## 6. Testing + Deployment

- [x] 6.1 Verify `npm run build` passes with all changes
- [ ] 6.2 Test on iOS device: sign in, generate story, generate audio, generate illustration — all work with Bearer token
- [ ] 6.3 Test unauthenticated request to `/api/v1/stories/generate` returns 401
- [ ] 6.4 Test invalid body to `/api/v1/audio/generate` returns 400 with Zod error
- [ ] 6.5 Test CORS: request from disallowed origin is blocked
- [ ] 6.6 Deploy to dev environment
- [ ] 6.7 Deploy to staging environment
- [ ] 6.8 Deploy to production environment
