# Story 1.4: Configure R2 Storage Client

## Story

As a developer,
I want an R2 storage client configured,
So that I can upload and retrieve generated videos.

## Status

completed

## Acceptance Criteria

- [x] **AC1**: client.ts exports configured S3 client for Cloudflare R2
- [x] **AC2**: uploadVideo function returns Effect with public URL or error
- [x] **AC3**: getVideoUrl function returns public URL for key
- [x] **AC4**: Environment variables read: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME
- [x] **AC5**: Upload returns public URL of uploaded video
- [x] **AC6**: Client handles connection errors gracefully with Effect errors

## Tasks/Subtasks

- [x] **Task 1**: Install AWS S3 SDK
  - [x] npm install @aws-sdk/client-s3
- [x] **Task 2**: Create R2 client
  - [x] Create src/lib/r2/client.ts
  - [x] Configure S3Client for R2 endpoint
  - [x] Read env vars for credentials
- [x] **Task 3**: Create upload function
  - [x] Create src/lib/r2/upload.ts
  - [x] uploadVideo(buffer, key) with Effect return
  - [x] Handle errors with UploadError type
- [x] **Task 4**: Create URL helper
  - [x] getVideoUrl(key) returns public URL
  - [x] generateVideoKey() for consistent key format
- [x] **Task 5**: Create barrel exports
  - [x] src/lib/r2/index.ts

## Dev Agent Record

### Implementation Plan
1. Install @aws-sdk/client-s3
2. Create R2 client with S3-compatible endpoint
3. Create upload functions with Effect error handling
4. Create URL helpers for public access

### Debug Log
- AWS S3 SDK installed successfully
- R2 uses S3-compatible API, works with standard SDK
- Public URL format uses R2's dev subdomain

### Completion Notes
All acceptance criteria satisfied:
- S3Client configured for R2 endpoint
- uploadVideo returns Effect<string, UploadError>
- UploadError uses discriminated union with _tag
- Environment variables handled with fallback to empty string
- isR2Configured() helper for runtime checks

## File List

**New Files:**
- `src/lib/r2/client.ts` - R2 client configuration
- `src/lib/r2/upload.ts` - Upload functions with Effect
- `src/lib/r2/index.ts` - Barrel exports

**Modified Files:**
- `package.json` - Added @aws-sdk/client-s3

## Change Log

| Date | Change |
|------|--------|
| 2026-01-09 | Story created from Epic 1 |
| 2026-01-09 | Implementation completed - all ACs satisfied |
