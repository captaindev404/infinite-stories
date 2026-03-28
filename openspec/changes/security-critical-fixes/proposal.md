## Why

The security audit (2026-03-28) identified 3 CRITICAL vulnerabilities in the backend that must be fixed before any production traffic. These issues allow unauthenticated users to drain the OpenAI API budget, steal session tokens via logs, and make cross-origin requests from any website.

## What Changes

### CRIT-1: Fix CORS — Replace Wildcard with Allowlist
- **File:** `middleware.ts`
- Replace `Access-Control-Allow-Origin: *` with explicit allowlist
- Only allow: `capacitor://localhost`, `ionic://localhost`, `BETTER_AUTH_URL`, `NEXT_PUBLIC_APP_URL`, `https://appleid.apple.com`
- Add `Vary: Origin` header

### CRIT-2: Add Authentication to All AI Endpoints + Zod Input Validation
- **Files:** 13 route files under `app/api/v1/`
- Add `requireAuth()` guard to every AI endpoint
- Add Zod schema validation for all request bodies (enforce types, max lengths, required fields)
- Add rate limiting calls after auth
- Specific Zod schemas needed:
  - `StoryGenerateSchema`: heroId (string, cuid), eventType (string, max 100), language (enum), etc.
  - `AudioGenerateSchema`: text (string, max 10000), voice (enum), language (enum)
  - `AvatarGenerateSchema`: prompt (string, max 500)
  - `IllustrationGenerateSchema`: prompt (string, max 1000), storyId (string, cuid)
  - `AIAssistantSchema`: description/prompt (string, max 2000), language (enum)
  - `SceneExtractSchema`: storyContent (string, max 50000)

### CRIT-3: Delete Debug Endpoint
- **File:** `app/api/test-auth/route.ts`
- Delete entirely — logs raw session tokens to stdout

### CRIT-4: Sanitize Health Endpoint
- **File:** `app/api/v1/health/route.ts`
- Remove env var names from error responses
- Return generic "unhealthy" status publicly
- Log missing env vars server-side only

## Capabilities

### Modified Capabilities
- `backend-auth`: CORS and middleware hardening
- `ios-integration`: No iOS changes needed (same API contract)

## Impact

- **Backend:** Middleware rewrite, 13 route files get auth guards + Zod validation, 1 file deleted, 1 file sanitized
- **iOS app:** No changes — auth headers already sent on all requests
- **Risk:** Zero — all iOS requests already include Bearer tokens; adding server-side enforcement is purely additive
- **Dependencies:** `zod` (already in project for visual profile validation)
