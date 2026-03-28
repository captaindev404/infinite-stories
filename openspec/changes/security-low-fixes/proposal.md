# Security LOW Fixes

## Why

The security audit (2026-03-28) identified 6 LOW severity improvements for defense-in-depth. These are not blocking issues but improve the overall security posture of the application.

## What Changes

### LOW-1: Add Request Body Size Limits
- Add explicit body size limits per route type via Next.js config
- AI text inputs: 32KB, file uploads: 4MB, default: 16KB
- Prevents resource exhaustion from oversized payloads

### LOW-2: Add CORS Preflight Cache Header
- **File:** `middleware.ts`
- Add `Access-Control-Max-Age: 3600` on OPTIONS responses
- Reduces preflight request frequency from mobile clients

### LOW-3: Add Story-to-User Cascade on Delete
- **File:** `prisma/schema.prisma`
- Add explicit `user User @relation(fields: [userId], references: [id], onDelete: Cascade)` on Story model
- Prevents orphaned stories when users are deleted

### LOW-4: Encrypt OAuth Tokens at Rest
- **File:** `prisma/schema.prisma` + new encryption utility
- Encrypt `accessToken` and `refreshToken` in Account table using application-layer encryption
- Use AES-256-GCM with key from environment variable

### LOW-5: Reduce Session Lifetime
- **File:** `lib/auth/auth.ts`
- Reduce from 30 days to 7 days with sliding window renewal
- Better for a children's data app — limits exposure from stolen devices/tokens

### LOW-6: Add Per-Route Body Size Limits
- Add `export const config = { api: { bodyParser: { sizeLimit: '32kb' } } }` to AI routes
- Prevents multi-megabyte payloads triggering expensive chunked processing

## Impact

- **Backend:** Schema migration (LOW-3), auth config change (LOW-5), middleware update (LOW-2), new utility (LOW-4)
- **iOS app:** May need session refresh logic update if session lifetime changes (LOW-5)
- **Risk:** LOW-3 requires Prisma migration; LOW-5 will sign out users with sessions older than 7 days
