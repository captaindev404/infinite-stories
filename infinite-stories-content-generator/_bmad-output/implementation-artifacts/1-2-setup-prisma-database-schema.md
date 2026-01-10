# Story 1.2: Setup Prisma & Database Schema

## Story

As a developer,
I want to configure Prisma with the complete database schema,
So that I can persist briefs, generations, videos, and cost logs.

## Status

completed

## Acceptance Criteria

- [x] **AC1**: Prisma is configured with PostgreSQL provider
- [x] **AC2**: Brief model defined (id, rawInput, parsedData, status, timestamps)
- [x] **AC3**: Generation model defined (id, briefId FK, parentGenerationId nullable FK, targetCount, status enum, totalCost, timestamps)
- [x] **AC4**: Video model defined (id, generationId FK, videoUrl, generationParams JSON, providers, status, qualityStatus, qualityNote, totalCost, timestamps)
- [x] **AC5**: CostLog model defined (id, videoId FK, serviceType, provider, operation, units, cost, timestamps)
- [x] **AC6**: All foreign key relationships are defined
- [x] **AC7**: Prisma Client generated successfully
- [x] **AC8**: Prisma Client can be imported via singleton

## Tasks/Subtasks

- [x] **Task 1**: Initialize Prisma
  - [x] Run `npx prisma init`
  - [x] Configure PostgreSQL provider in schema.prisma
  - [x] Set DATABASE_URL in .env and .env.example
- [x] **Task 2**: Define enums
  - [x] BriefStatus enum (DRAFT, PARSED)
  - [x] GenerationStatus enum (PENDING, QUEUED, SCRIPT_GEN, AVATAR_GEN, VIDEO_GEN, COMPOSITING, UPLOADING, COMPLETED, FAILED)
  - [x] VideoStatus enum (PENDING, PROCESSING, COMPLETED, FAILED)
  - [x] QualityStatus enum (PENDING, PASSED, FLAGGED)
- [x] **Task 3**: Define Brief model
  - [x] id, rawInput (Text), parsedData (Json?), status, createdAt, updatedAt
  - [x] Relation to Generation[]
- [x] **Task 4**: Define Generation model
  - [x] id, briefId, parentGenerationId?, targetCount, status, totalCost, createdAt
  - [x] Relations: Brief, parent Generation?, child Generation[], Video[]
- [x] **Task 5**: Define Video model
  - [x] id, generationId, videoUrl?, generationParams (Json), avatarProvider?, scriptProvider?, status, qualityStatus, qualityNote?, totalCost, createdAt
  - [x] Relations: Generation, CostLog[]
- [x] **Task 6**: Define CostLog model
  - [x] id, videoId?, serviceType, provider, operation, inputUnits, outputUnits, unitType, cost, createdAt
  - [x] Relation: Video?
- [x] **Task 7**: Generate and verify Prisma Client
  - [x] Run `npx prisma generate`
  - [x] Create src/lib/db/client.ts with singleton pattern
  - [x] Verify import works

## Dev Notes

### Architecture Requirements
- From project-context.md: Prisma with PostgreSQL on Dokploy
- GenerationStatus state machine: PENDING → QUEUED → SCRIPT_GEN → AVATAR_GEN → VIDEO_GEN → COMPOSITING → UPLOADING → COMPLETED | FAILED
- Use Json type for parsedData and generationParams

### Technical Specifications
- Prisma 5.22.0 (stable, traditional schema support)
- PostgreSQL provider
- Decimal for cost fields (10,4 for totals, 10,6 for individual costs)
- DateTime for timestamps with @default(now())

## Dev Agent Record

### Implementation Plan
1. Initialize Prisma with npx prisma init
2. Define all enums in schema
3. Define models with proper relations
4. Generate Prisma client
5. Create singleton pattern for client

### Debug Log
- Prisma 7 has breaking changes (no url in schema)
- Downgraded to Prisma 5.22.0 for traditional schema support
- prisma.config.ts removed (not needed for Prisma 5)
- Generated client successfully to node_modules/@prisma/client

### Completion Notes
All acceptance criteria satisfied:
- 4 enums defined: BriefStatus, GenerationStatus, VideoStatus, QualityStatus
- 4 models defined: Brief, Generation, Video, CostLog
- All FK relationships with proper cascade behavior
- Indexes on frequently queried fields
- Singleton client pattern at src/lib/db/client.ts
- Build and lint pass

## File List

_Files created/modified by this story:_

**New Files:**
- `prisma/schema.prisma` - Complete database schema
- `.env` - Environment variables (DATABASE_URL)
- `.env.example` - Template for environment setup
- `src/lib/db/client.ts` - Prisma client singleton
- `src/lib/db/index.ts` - Barrel export

**Modified Files:**
- `package.json` - Added prisma and @prisma/client dependencies

## Change Log

| Date | Change |
|------|--------|
| 2026-01-09 | Story created from Epic 1 |
| 2026-01-09 | Implementation completed - all ACs satisfied |
