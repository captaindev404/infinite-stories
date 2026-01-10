# Story 1.6: Configure Effect Error Types

## Story

As a developer,
I want Effect error types defined for the application,
So that all errors are typed and handled consistently.

## Status

completed

## Acceptance Criteria

- [x] **AC1**: types.ts defines AppError as discriminated union with _tag
- [x] **AC2**: Error types include: BriefNotFound, BriefParseError, GenerationNotFound, GenerationFailed, VideoNotFound, VideoCompositionError, ProviderError, UploadError, DownloadError, RateLimited, ValidationError, Unauthorized
- [x] **AC3**: handlers.ts exports errorToResponse(error: AppError): ApiResponse
- [x] **AC4**: Each error type maps to appropriate HTTP status code
- [x] **AC5**: Error responses follow API wrapper format: { data: null, error: { _tag, ... }, meta: { timestamp } }

## Tasks/Subtasks

- [x] **Task 1**: Create error types
  - [x] Create src/lib/errors/types.ts
  - [x] Define all error types with _tag
  - [x] Define AppError union type
  - [x] Define ApiResponse type
- [x] **Task 2**: Create error handlers
  - [x] Create src/lib/errors/handlers.ts
  - [x] errorToResponse() function
  - [x] errorToNextResponse() with status codes
  - [x] successResponse() and successToNextResponse() helpers
- [x] **Task 3**: Create error factories
  - [x] AppErrors object with factory functions
  - [x] Type-safe error creation helpers
- [x] **Task 4**: Create barrel exports
  - [x] src/lib/errors/index.ts

## Dev Agent Record

### Implementation Plan
1. Define all error types with _tag discriminant
2. Create AppError union type
3. Map error types to HTTP status codes
4. Create response helpers

### Debug Log
- All error types use _tag for discrimination
- HTTP status codes mapped: 400, 401, 404, 429, 500
- RateLimited includes Retry-After header

### Completion Notes
All acceptance criteria satisfied:
- 12 error types defined with _tag
- AppError union type for type-safe error handling
- ApiResponse<T> generic type for API responses
- Status code mapping: 400 (validation), 401 (auth), 404 (not found), 429 (rate limit), 500 (server)
- AppErrors factory object for easy error creation

## File List

**New Files:**
- `src/lib/errors/types.ts` - Error type definitions
- `src/lib/errors/handlers.ts` - Response handlers
- `src/lib/errors/index.ts` - Barrel exports

## Change Log

| Date | Change |
|------|--------|
| 2026-01-09 | Story created from Epic 1 |
| 2026-01-09 | Implementation completed - all ACs satisfied |
