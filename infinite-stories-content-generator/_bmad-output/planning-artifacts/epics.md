---
stepsCompleted: [1, 2, 3]
inputDocuments:
  - _bmad-output/planning-artifacts/prd.md
  - _bmad-output/planning-artifacts/architecture.md
---

# infinite-stories-content-generator - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for infinite-stories-content-generator, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

**Brief Creation & Management (6 FRs)**
- FR1: User can write a brief in natural language via chat interface
- FR2: System can parse natural language brief into structured JSON (hook, persona, emotion, B-roll tags)
- FR3: User can view the parsed structure of their brief
- FR4: User can edit/tweak an existing brief and trigger regeneration
- FR5: User can view history of all briefs created
- FR6: User can duplicate an existing brief as starting point for a new one

**Video Generation (6 FRs)**
- FR7: User can trigger generation of 1-10 video variations from a single brief
- FR8: System can generate AI avatar testimonial content based on brief persona
- FR9: System can integrate B-roll content from InfiniteStories app assets
- FR10: System can compose avatar testimonial with B-roll into final video
- FR11: User can view generation progress/status while videos are being created
- FR12: System can store generated videos in cloud storage (R2)

**Cost Tracking & Budgeting (5 FRs)**
- FR13: System can track cost per video in real-time during generation
- FR14: System can track token consumption per AI provider operation
- FR15: User can view cost breakdown per video (by service type and provider)
- FR16: User can view total cost per generation batch
- FR17: User can view aggregate cost statistics (daily, weekly, monthly)

**Video Review & Quality (5 FRs)**
- FR18: User can preview each generated video
- FR19: User can flag a video as having quality issues (artifacts, incoherences)
- FR20: User can add a note explaining why a video was flagged
- FR21: User can mark a video as approved/passed quality review
- FR22: User can filter videos by quality status (pending, passed, flagged)

**Iteration & Variations (4 FRs)**
- FR23: User can select a winning video and trigger "iterate on winner" workflow
- FR24: System can generate variations of a selected video (adjusting hook, avatar, B-roll)
- FR25: System can track parent-child relationship between generations
- FR26: User can view the lineage/history of iterations for any video

**Video Library & Output (5 FRs)**
- FR27: User can view all generated videos in a gallery/list view
- FR28: User can filter videos by brief, generation batch, date, or status
- FR29: User can download individual videos for upload to TikTok
- FR30: User can view video metadata (cost, generation params, provider used)
- FR31: User can delete videos that are no longer needed

### Non-Functional Requirements

**Performance**
- NFR1: Video generation time <5 minutes per video
- NFR2: UI responsiveness <500ms for user actions
- NFR3: Poll interval 5 seconds for generation status updates
- NFR4: Video preview load <2 seconds

**Reliability**
- NFR5: Generation success rate >95%
- NFR6: Data persistence - zero data loss for briefs, videos, costs
- NFR7: Error recovery - graceful degradation for failed generations
- NFR8: Retry logic - 3 attempts with exponential backoff for transient failures

**Security**
- NFR9: API keys stored in environment variables, never in code
- NFR10: Database access via Prisma with parameterized queries
- NFR11: R2 access via public bucket (MVP) - signed URLs deferred
- NFR12: HTTPS only for all traffic

**Integration**
- NFR13: Provider abstraction - swap providers without code changes
- NFR14: API timeout handling - 30 second timeout per AI call
- NFR15: Rate limit handling - respect provider limits, queue/throttle
- NFR16: InfiniteStories API - authenticated access to B-roll assets

### Additional Requirements

**From Architecture - Starter Template:**
- Project uses minimal setup (clean slate, not community starter)
- Initialize with: `npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --turbopack`
- Add ShadCN: `npx shadcn@latest init`
- Add Prisma: `npx prisma init`

**From Architecture - Technical Decisions:**
- Provider abstraction using Interface + Factory pattern
- DB polling for background job status (no separate job queue)
- Effect library for error handling
- Zustand for client state management
- React Hook Form for all forms
- GitHub Actions for CI/CD
- Dokploy for self-hosted deployment
- Public R2 bucket for video storage
- Env-based token for API protection

**From Architecture - Data Model:**
- Brief: rawInput + parsedData JSON
- Generation: parent-child tracking for "iterate on winner"
- Video: generationParams JSON, quality status
- CostLog: provider-agnostic cost tracking
- Template: (Growth phase)

**From Architecture - Status State Machine:**
- GenerationStatus: PENDING → QUEUED → SCRIPT_GEN → AVATAR_GEN → VIDEO_GEN → COMPOSITING → UPLOADING → COMPLETED | FAILED

### FR Coverage Map

| FR | Epic | Description |
|----|------|-------------|
| FR1 | Epic 2 | Chat brief input |
| FR2 | Epic 2 | AI parsing to JSON |
| FR3 | Epic 2 | View parsed structure |
| FR4 | Epic 2 | Edit/tweak brief |
| FR5 | Epic 2 | Brief history |
| FR6 | Epic 2 | Duplicate brief |
| FR7 | Epic 3 | Trigger 1-10 generation |
| FR8 | Epic 3 | AI avatar generation |
| FR9 | Epic 3 | B-roll integration |
| FR10 | Epic 3 | Video composition |
| FR11 | Epic 3 | Progress tracking |
| FR12 | Epic 3 | R2 storage |
| FR13 | Epic 4 | Real-time cost tracking |
| FR14 | Epic 4 | Token consumption |
| FR15 | Epic 4 | Per-video cost breakdown |
| FR16 | Epic 4 | Per-batch total cost |
| FR17 | Epic 4 | Aggregate statistics |
| FR18 | Epic 5 | Preview videos |
| FR19 | Epic 5 | Flag quality issues |
| FR20 | Epic 5 | Add flag notes |
| FR21 | Epic 5 | Mark approved |
| FR22 | Epic 5 | Filter by quality |
| FR23 | Epic 6 | Iterate on winner |
| FR24 | Epic 6 | Generate variations |
| FR25 | Epic 6 | Parent-child tracking |
| FR26 | Epic 6 | Iteration lineage |
| FR27 | Epic 5 | Gallery view |
| FR28 | Epic 5 | Filter videos |
| FR29 | Epic 5 | Download for TikTok |
| FR30 | Epic 5 | View metadata |
| FR31 | Epic 5 | Delete videos |

## Epic List

### Epic 1: Project Foundation
> Sets up the complete development environment and technical foundation

**User Outcome:** Development environment ready, database schema deployed, provider interfaces defined

**Scope:**
- Initialize Next.js with TypeScript, Tailwind, ShadCN
- Create Prisma schema (Brief, Generation, Video, CostLog)
- Define provider interfaces (Script, Avatar, Video)
- Setup API auth middleware
- Configure R2 storage client

**FRs covered:** Enables all FRs (foundational)

---

### Epic 2: Brief Creation & Management
> User can write briefs in natural language and have them parsed into structured data

**User Outcome:** User can create, view, edit, and manage briefs via chat interface

**Scope:**
- Chat interface for brief input
- AI parsing to structured JSON
- View parsed structure
- Edit/tweak and regenerate
- View brief history
- Duplicate briefs

**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6

---

### Epic 3: Video Generation Pipeline
> User can trigger batch generation and watch progress in real-time

**User Outcome:** User can generate 1-10 video variations from a single brief

**Scope:**
- Trigger 1-10 video generation
- AI avatar testimonial generation
- B-roll integration from InfiniteStories
- Video composition
- Progress/status tracking
- R2 storage upload

**FRs covered:** FR7, FR8, FR9, FR10, FR11, FR12

---

### Epic 4: Cost Tracking & Visibility
> User can monitor spending in real-time and view aggregate statistics

**User Outcome:** User can see what they're spending per video, per batch, and over time

**Scope:**
- Real-time cost tracking during generation
- Token consumption per operation
- Cost breakdown per video
- Total cost per batch
- Aggregate statistics (daily/weekly/monthly)

**FRs covered:** FR13, FR14, FR15, FR16, FR17

---

### Epic 5: Video Library & Quality Review
> User can browse, review quality, and manage all generated videos

**User Outcome:** User can preview, flag, approve, filter, download, and delete videos

**Scope:**
- Preview videos
- Flag quality issues with notes
- Mark approved/passed
- Filter by quality status
- Gallery/list view
- Filter by brief/batch/date/status
- Download for TikTok
- View metadata
- Delete videos

**FRs covered:** FR18, FR19, FR20, FR21, FR22, FR27, FR28, FR29, FR30, FR31

---

### Epic 6: Iterate on Winners
> User can select winning videos and generate variations to scale success

**User Outcome:** User can take a winning video and create variations to find more winners

**Scope:**
- "Iterate on winner" workflow
- Generate variations (adjust hook, avatar, B-roll)
- Parent-child relationship tracking
- View iteration lineage

**FRs covered:** FR23, FR24, FR25, FR26

---

## Epic 1: Project Foundation

> Sets up the complete development environment and technical foundation

### Story 1.1: Initialize Next.js Project

As a developer,
I want to initialize a Next.js project with the configured tech stack,
So that I have a working development environment to build upon.

**Acceptance Criteria:**

**Given** the project directory is empty
**When** I run the initialization commands
**Then** a Next.js 15 project is created with App Router enabled
**And** TypeScript is configured with strict mode
**And** Tailwind CSS is installed and configured
**And** ShadCN is initialized with default configuration
**And** ESLint is configured for the project
**And** Turbopack is enabled for development
**And** the `src/` directory structure is created
**And** `npm run dev` starts the development server successfully

---

### Story 1.2: Setup Prisma & Database Schema

As a developer,
I want to configure Prisma with the complete database schema,
So that I can persist briefs, generations, videos, and cost logs.

**Acceptance Criteria:**

**Given** the Next.js project is initialized
**When** I run `npx prisma init`
**Then** Prisma is configured with PostgreSQL provider
**And** the following models are defined in `schema.prisma`:

- **Brief**: id, rawInput (Text), parsedData (Json), status (enum), createdAt, updatedAt
- **Generation**: id, briefId (FK), parentGenerationId (nullable FK), targetCount, status (enum: PENDING, QUEUED, SCRIPT_GEN, AVATAR_GEN, VIDEO_GEN, COMPOSITING, UPLOADING, COMPLETED, FAILED), totalCost, createdAt
- **Video**: id, generationId (FK), videoUrl, generationParams (Json), avatarProvider, scriptProvider, status (enum), qualityStatus (enum: PENDING, PASSED, FLAGGED), qualityNote, totalCost, createdAt
- **CostLog**: id, videoId (FK), serviceType, provider, operation, inputUnits, outputUnits, unitType, cost, createdAt

**And** all foreign key relationships are defined
**And** `npx prisma db push` creates the tables successfully
**And** Prisma Client is generated and can be imported

---

### Story 1.3: Define Provider Interfaces

As a developer,
I want provider interfaces defined using Interface + Factory pattern,
So that I can swap AI providers without changing business logic.

**Acceptance Criteria:**

**Given** Prisma schema is configured
**When** I create the provider interfaces in `src/lib/providers/`
**Then** the following files exist:

- `types.ts` with interfaces: IScriptProvider, IAvatarProvider, IVideoProvider
- `factory.ts` with createProvider() function
- `script/index.ts` with script provider exports
- `avatar/index.ts` with avatar provider exports
- `video/index.ts` with video provider exports

**And** IScriptProvider defines: `generate(brief: ParsedBrief): Effect<Script[], ScriptError>`
**And** IAvatarProvider defines: `generate(script: Script): Effect<AvatarClip, AvatarError>`
**And** IVideoProvider defines: `compose(avatar: AvatarClip, broll: BRollClip[]): Effect<Video, VideoError>`
**And** createProvider() returns the correct implementation based on config
**And** all interfaces use Effect return types for error handling

---

### Story 1.4: Configure R2 Storage Client

As a developer,
I want an R2 storage client configured,
So that I can upload and retrieve generated videos.

**Acceptance Criteria:**

**Given** provider interfaces are defined
**When** I create the R2 client in `src/lib/r2/`
**Then** `client.ts` exports a configured S3 client for Cloudflare R2
**And** `upload.ts` exports `uploadVideo(buffer: Buffer, key: string): Effect<string, UploadError>`
**And** `upload.ts` exports `getVideoUrl(key: string): string`
**And** environment variables are read: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME
**And** upload returns the public URL of the uploaded video
**And** the client handles connection errors gracefully with Effect errors

---

### Story 1.5: Setup API Auth Middleware

As a developer,
I want API authentication middleware configured,
So that API routes are protected from unauthorized access.

**Acceptance Criteria:**

**Given** R2 client is configured
**When** I create auth middleware in `src/lib/auth/`
**Then** `middleware.ts` exports a `validateToken` function
**And** the function checks for `Authorization: Bearer {token}` header
**And** the token is validated against `ADMIN_TOKEN` environment variable
**And** invalid/missing tokens return 401 Unauthorized
**And** valid tokens allow the request to proceed
**And** `src/middleware.ts` applies auth to all `/api/*` routes except health checks

---

### Story 1.6: Configure Effect Error Types

As a developer,
I want Effect error types defined for the application,
So that all errors are typed and handled consistently.

**Acceptance Criteria:**

**Given** auth middleware is configured
**When** I create error types in `src/lib/errors/`
**Then** `types.ts` defines AppError as discriminated union with _tag:

- BriefNotFound, BriefParseError
- GenerationNotFound, GenerationFailed
- VideoNotFound, VideoCompositionError
- ProviderError (with provider name and message)
- UploadError, DownloadError
- RateLimited (with retryAfter)
- ValidationError (with field errors)
- Unauthorized

**And** `handlers.ts` exports `errorToResponse(error: AppError): ApiResponse`
**And** each error type maps to appropriate HTTP status code
**And** error responses follow the API wrapper format: `{ data: null, error: { _tag, ... }, meta: { timestamp } }`

---

## Epic 2: Brief Creation & Management

> User can write briefs in natural language and have them parsed into structured data

### Story 2.1: Create Brief API & Database Operations

As a user,
I want to create a new brief via API,
So that my brief input is persisted and ready for processing.

**Acceptance Criteria:**

**Given** I am authenticated
**When** I POST to `/api/briefs` with `{ rawInput: "my brief text" }`
**Then** a new Brief record is created with status DRAFT
**And** the response contains the brief id and rawInput
**And** parsedData is null (not yet parsed)
**And** createdAt and updatedAt timestamps are set
**And** the response follows the API wrapper format

**Given** I provide empty rawInput
**When** I POST to `/api/briefs`
**Then** I receive a 400 ValidationError with field error for rawInput

---

### Story 2.2: AI Brief Parsing to Structured JSON

As a user,
I want my natural language brief parsed into structured JSON,
So that the system understands my hook, persona, emotion, and B-roll requirements.

**Acceptance Criteria:**

**Given** a Brief exists with rawInput and status DRAFT
**When** I POST to `/api/briefs/[id]/parse`
**Then** the system calls the script provider to parse the brief
**And** parsedData is populated with structured JSON containing:
  - hook: string (the attention-grabbing opening)
  - persona: { type, age, demographic, tone }
  - emotion: string (the emotional angle)
  - brollTags: string[] (scene descriptions for B-roll)
  - testimonialPoints: string[] (key messages)
**And** Brief status changes to PARSED
**And** a CostLog entry is created for the parsing operation
**And** the response includes the full parsedData

**Given** the AI fails to parse the brief
**When** parsing is attempted
**Then** status remains DRAFT
**And** a BriefParseError is returned with details
**And** the user can retry parsing

---

### Story 2.3: Chat Interface for Brief Input

As a user,
I want a Telegram-style chat interface to write my brief,
So that I can naturally describe my ad concept.

**Acceptance Criteria:**

**Given** I navigate to the brief creation page
**When** the page loads
**Then** I see a chat-style interface with a text input at the bottom
**And** I see a welcome message explaining how to write a brief

**Given** I type my brief in the chat input
**When** I press Enter or click Send
**Then** my message appears in the chat as a user bubble
**And** a loading indicator shows while the brief is being created
**And** the brief is created via POST `/api/briefs`
**And** parsing is automatically triggered
**And** the parsed result appears as a system response

**Given** parsing completes successfully
**When** the response is received
**Then** I see a formatted display of the parsed structure
**And** I have options to "Generate Videos" or "Edit Brief"

---

### Story 2.4: View Parsed Brief Structure

As a user,
I want to view the parsed structure of my brief,
So that I can verify the system understood my intent correctly.

**Acceptance Criteria:**

**Given** I have a Brief with status PARSED
**When** I GET `/api/briefs/[id]`
**Then** I receive the full brief including parsedData

**Given** I am viewing a brief in the UI
**When** the parsed data is displayed
**Then** I see clearly labeled sections for:
  - Hook (the opening line)
  - Persona (avatar characteristics)
  - Emotion (the feeling to convey)
  - B-roll Tags (visual scenes)
  - Testimonial Points (key messages)
**And** each section is visually distinct and easy to read

---

### Story 2.5: Edit Brief & Trigger Regeneration

As a user,
I want to edit my brief and re-parse it,
So that I can refine my concept without starting over.

**Acceptance Criteria:**

**Given** I have an existing Brief
**When** I PATCH `/api/briefs/[id]` with `{ rawInput: "updated text" }`
**Then** the rawInput is updated
**And** parsedData is cleared (set to null)
**And** status is reset to DRAFT
**And** updatedAt timestamp is refreshed

**Given** I am viewing a brief in the UI
**When** I click "Edit Brief"
**Then** the rawInput becomes editable in a text area
**And** I can modify the text
**And** clicking "Save & Re-parse" updates the brief and triggers parsing
**And** the new parsed structure is displayed

**Given** the brief has existing generations
**When** I edit and re-parse
**Then** existing generations are preserved (not deleted)
**And** the brief can be used for new generations

---

### Story 2.6: Brief History List View

As a user,
I want to view all my briefs in a list,
So that I can find and manage my previous concepts.

**Acceptance Criteria:**

**Given** I am authenticated
**When** I GET `/api/briefs`
**Then** I receive a list of all briefs sorted by createdAt descending
**And** each brief includes: id, rawInput (truncated), status, createdAt

**Given** I navigate to the briefs page
**When** the page loads
**Then** I see a list/table of all my briefs
**And** each row shows: brief preview (first 100 chars), status badge, creation date
**And** clicking a row navigates to the brief detail view

**Given** I have many briefs
**When** viewing the list
**Then** briefs are paginated (20 per page)
**And** I can navigate between pages

---

### Story 2.7: Duplicate Existing Brief

As a user,
I want to duplicate an existing brief,
So that I can use a successful concept as a starting point for variations.

**Acceptance Criteria:**

**Given** I have an existing Brief
**When** I POST `/api/briefs/[id]/duplicate`
**Then** a new Brief is created with the same rawInput
**And** the new brief has status DRAFT
**And** parsedData is null (requires re-parsing)
**And** the response contains the new brief id

**Given** I am viewing a brief in the UI
**When** I click "Duplicate"
**Then** I am navigated to the new brief
**And** the chat shows the duplicated text
**And** I can edit before parsing

---

## Epic 3: Video Generation Pipeline

> User can trigger batch generation and watch progress in real-time

### Story 3.1: Create Generation & Trigger Pipeline

As a user,
I want to trigger generation of multiple video variations from my brief,
So that I can test different ad concepts at scale.

**Acceptance Criteria:**

**Given** I have a Brief with status PARSED
**When** I POST `/api/briefs/[id]/generations` with `{ targetCount: 10 }`
**Then** a new Generation record is created with:
  - briefId linked to the brief
  - targetCount set to requested count (1-10)
  - status set to PENDING
  - totalCost initialized to 0
**And** the generation pipeline is triggered asynchronously
**And** the response includes the generation id and status

**Given** targetCount is outside 1-10 range
**When** I attempt to create a generation
**Then** I receive a 400 ValidationError

**Given** the Brief is not in PARSED status
**When** I attempt to create a generation
**Then** I receive a 400 error indicating brief must be parsed first

---

### Story 3.2: Script Generation via Provider

As a system,
I want to generate multiple ad scripts from a parsed brief,
So that each video variation has unique but on-brand copy.

**Acceptance Criteria:**

**Given** a Generation is in PENDING status
**When** the pipeline starts processing
**Then** status changes to QUEUED, then to SCRIPT_GEN
**And** the script provider is called with parsedData
**And** the provider generates `targetCount` unique scripts
**And** each script contains: hook, testimonialScript, callToAction
**And** scripts vary in tone/phrasing while maintaining core message

**Given** script generation succeeds
**When** all scripts are generated
**Then** a CostLog entry is created with:
  - serviceType: "script"
  - provider: (configured provider name)
  - inputUnits: token count
  - outputUnits: token count
  - cost: calculated cost
**And** scripts are stored in memory for next pipeline stage

**Given** script generation fails
**When** an error occurs
**Then** retry with exponential backoff (up to 3 attempts)
**And** if all retries fail, Generation status → FAILED
**And** error details are logged

---

### Story 3.3: Avatar Testimonial Generation

As a system,
I want to generate AI avatar testimonial videos,
So that each ad has a realistic spokesperson delivering the script.

**Acceptance Criteria:**

**Given** scripts have been generated successfully
**When** the pipeline reaches AVATAR_GEN status
**Then** status changes to AVATAR_GEN
**And** the avatar provider is called for each script
**And** avatar parameters are derived from brief persona (age, demographic, tone)
**And** each avatar clip contains the testimonial delivery

**Given** avatar generation succeeds for a video
**When** the clip is ready
**Then** a CostLog entry is created with:
  - serviceType: "avatar"
  - provider: (configured provider name)
  - inputUnits: script character count
  - outputUnits: video duration in seconds
  - cost: calculated cost
**And** avatar clip is stored temporarily for composition

**Given** avatar generation fails for one video
**When** an error occurs
**Then** that specific video is marked as FAILED
**And** other videos continue processing
**And** Generation continues if at least one video succeeds

---

### Story 3.4: B-roll Integration from InfiniteStories

As a system,
I want to fetch B-roll content from InfiniteStories,
So that ads showcase the actual app experience.

**Acceptance Criteria:**

**Given** the pipeline is processing and has parsed brollTags
**When** B-roll is needed for composition
**Then** the system calls InfiniteStories API with brollTags
**And** matching illustrations/scenes are retrieved
**And** B-roll clips are formatted for video composition

**Given** specific brollTags are requested
**When** fetching from InfiniteStories
**Then** the API returns:
  - imageUrl or videoUrl for each tag
  - metadata (scene type, duration if video)
**And** results are cached for the generation session

**Given** a brollTag has no matching content
**When** the fetch returns empty
**Then** fallback generic B-roll is used
**And** the video is still generated (not failed)

**Given** InfiniteStories API is unavailable
**When** the fetch fails
**Then** retry with exponential backoff
**And** if all retries fail, use fallback B-roll
**And** log warning but continue generation

---

### Story 3.5: Video Composition Pipeline

As a system,
I want to compose avatar clips with B-roll into final videos,
So that each ad is a polished, ready-to-upload asset.

**Acceptance Criteria:**

**Given** avatar clips and B-roll are ready
**When** the pipeline reaches VIDEO_GEN status
**Then** status changes to VIDEO_GEN, then COMPOSITING
**And** the video provider composes each video with:
  - Avatar testimonial as primary content
  - B-roll clips as visual overlays/cutaways
  - Transitions between segments
**And** output is TikTok-optimized format (9:16, 15-60 seconds)

**Given** composition succeeds for a video
**When** the video is rendered
**Then** a Video record is created with:
  - generationId linked
  - generationParams storing all parameters used
  - avatarProvider and scriptProvider recorded
  - status: PENDING (awaiting upload)
  - qualityStatus: PENDING
**And** a CostLog entry is created for composition

**Given** composition fails for one video
**When** an error occurs
**Then** that Video record is created with status FAILED
**And** error is logged in generationParams
**And** other videos continue processing

---

### Story 3.6: Generation Progress Tracking UI

As a user,
I want to see real-time progress of my generation,
So that I know what's happening and when videos will be ready.

**Acceptance Criteria:**

**Given** I have triggered a generation
**When** I navigate to `/generations/[id]`
**Then** I see the current generation status
**And** I see a progress indicator showing the pipeline stage:
  - PENDING → QUEUED → SCRIPT_GEN → AVATAR_GEN → VIDEO_GEN → COMPOSITING → UPLOADING → COMPLETED

**Given** generation is in progress
**When** viewing the progress page
**Then** the UI polls `/api/generations/[id]` every 5 seconds
**And** status updates are reflected immediately
**And** I see count of videos: "3 of 10 completed"

**Given** generation completes
**When** status becomes COMPLETED
**Then** polling stops
**And** I see a success message
**And** I have a button to "View Videos"

**Given** generation fails
**When** status becomes FAILED
**Then** I see an error message with details
**And** I have options to "Retry" or "Edit Brief"

---

### Story 3.7: Upload Completed Videos to R2

As a system,
I want to upload completed videos to R2 storage,
So that videos are persisted and accessible for review/download.

**Acceptance Criteria:**

**Given** a video has been composed successfully
**When** the pipeline reaches UPLOADING status
**Then** each completed video is uploaded to R2
**And** the upload key follows pattern: `generations/{generationId}/{videoId}.mp4`
**And** Video.videoUrl is updated with the public URL

**Given** upload succeeds for a video
**When** the URL is saved
**Then** Video.status changes to COMPLETED
**And** a CostLog entry is created with:
  - serviceType: "storage"
  - provider: "r2"
  - outputUnits: file size in bytes
  - cost: calculated storage cost

**Given** all videos are uploaded
**When** the last upload completes
**Then** Generation.status changes to COMPLETED
**And** Generation.totalCost is calculated as sum of all CostLog entries
**And** the generation is ready for review

**Given** upload fails for a video
**When** an error occurs
**Then** retry with exponential backoff
**And** if all retries fail, Video.status → FAILED
**And** other videos continue uploading

---

## Epic 4: Cost Tracking & Visibility

> User can monitor spending in real-time and view aggregate statistics

### Story 4.1: Real-time Cost Tracking During Generation

As a user,
I want to see costs accumulating in real-time during generation,
So that I can monitor spending as it happens.

**Acceptance Criteria:**

**Given** a generation is in progress
**When** each AI operation completes (script, avatar, video, upload)
**Then** a CostLog entry is created immediately with:
  - videoId (if applicable)
  - serviceType: "script" | "avatar" | "video" | "storage"
  - provider: the provider name used
  - operation: specific operation (e.g., "generate_script", "render_avatar")
  - inputUnits and outputUnits with unitType
  - cost: calculated based on provider pricing
  - createdAt: timestamp

**Given** I am viewing the generation progress page
**When** costs are logged
**Then** the running total is updated in the UI
**And** I see "Current cost: $X.XX" updating as operations complete

**Given** the generation completes
**When** all CostLogs are recorded
**Then** Generation.totalCost equals sum of all related CostLog.cost values

---

### Story 4.2: Per-Video Cost Breakdown View

As a user,
I want to see the cost breakdown for each video,
So that I understand what operations cost the most.

**Acceptance Criteria:**

**Given** I have a completed video
**When** I GET `/api/videos/[id]/costs`
**Then** I receive all CostLog entries for that video
**And** the response includes:
  - Total cost for the video
  - Breakdown by serviceType (script, avatar, video, storage)
  - Each operation with its cost

**Given** I am viewing a video detail page
**When** I click "View Cost Breakdown"
**Then** I see a breakdown showing:
  - Script generation: $X.XX
  - Avatar generation: $X.XX
  - Video composition: $X.XX
  - Storage: $X.XX
  - **Total: $X.XX**
**And** each line shows the provider used

**Given** a video failed during generation
**When** viewing its cost breakdown
**Then** I see partial costs for completed operations
**And** failed operations show $0.00 with "Failed" indicator

---

### Story 4.3: Generation Batch Cost Summary

As a user,
I want to see the total cost for a generation batch,
So that I know how much a set of variations cost.

**Acceptance Criteria:**

**Given** I have a completed generation
**When** I GET `/api/generations/[id]`
**Then** the response includes:
  - totalCost: sum of all video costs
  - videoCount: number of videos generated
  - averageCostPerVideo: totalCost / videoCount

**Given** I am viewing a generation detail page
**When** the generation is complete
**Then** I see a cost summary card showing:
  - Total batch cost: $X.XX
  - Videos generated: N
  - Average per video: $X.XX
**And** I can expand to see per-video costs

**Given** I am viewing the generation progress page
**When** the generation is still in progress
**Then** I see running totals updating in real-time
**And** estimated final cost based on progress

---

### Story 4.4: Aggregate Cost Statistics Dashboard

As a user,
I want to view aggregate cost statistics over time,
So that I can track my spending and budget effectively.

**Acceptance Criteria:**

**Given** I am authenticated
**When** I GET `/api/cost-logs/stats?period=daily`
**Then** I receive aggregated costs grouped by day
**And** the response includes:
  - date, totalCost, videoCount for each day
  - breakdown by serviceType

**Given** I navigate to the costs dashboard page
**When** the page loads
**Then** I see:
  - Today's spending: $X.XX
  - This week: $X.XX
  - This month: $X.XX
  - All time: $X.XX

**Given** I am on the costs dashboard
**When** I view the breakdown section
**Then** I see spending by service type:
  - Script generation: $X.XX (XX%)
  - Avatar generation: $X.XX (XX%)
  - Video composition: $X.XX (XX%)
  - Storage: $X.XX (XX%)

**Given** I am on the costs dashboard
**When** I view the trends section
**Then** I see a simple chart showing daily costs for the past 30 days
**And** I can see which days had the highest spending

**Given** I want to filter by date range
**When** I select a custom date range
**Then** all statistics update to reflect that period

---

## Epic 5: Video Library & Quality Review

> User can browse, review quality, and manage all generated videos

### Story 5.1: Video Gallery List View

As a user,
I want to view all my generated videos in a gallery,
So that I can browse and select videos for review.

**Acceptance Criteria:**

**Given** I am authenticated
**When** I GET `/api/videos`
**Then** I receive a paginated list of all videos
**And** each video includes: id, videoUrl, thumbnailUrl, status, qualityStatus, totalCost, createdAt
**And** results are sorted by createdAt descending (newest first)
**And** pagination supports limit and offset parameters

**Given** I navigate to the video library page
**When** the page loads
**Then** I see a grid/gallery of video thumbnails
**And** each thumbnail shows:
  - Video preview image
  - Quality status badge (Pending/Passed/Flagged)
  - Cost indicator
  - Creation date
**And** clicking a thumbnail opens the video detail view

**Given** I have many videos
**When** scrolling the gallery
**Then** more videos load automatically (infinite scroll)
**Or** pagination controls allow navigation between pages

---

### Story 5.2: Video Filtering & Search

As a user,
I want to filter videos by various criteria,
So that I can quickly find specific videos.

**Acceptance Criteria:**

**Given** I am on the video library page
**When** I apply filters
**Then** the gallery updates to show only matching videos

**Given** I want to filter by quality status
**When** I select "Pending", "Passed", or "Flagged"
**Then** only videos with that qualityStatus are shown

**Given** I want to filter by brief
**When** I select a specific brief from the dropdown
**Then** only videos generated from that brief are shown

**Given** I want to filter by generation batch
**When** I select a specific generation
**Then** only videos from that generation are shown

**Given** I want to filter by date range
**When** I select start and end dates
**Then** only videos created within that range are shown

**Given** I want to filter by video status
**When** I select "Completed" or "Failed"
**Then** only videos with that status are shown

**Given** I apply multiple filters
**When** filters are combined
**Then** all filter criteria are applied (AND logic)
**And** I can clear individual filters or all filters

---

### Story 5.3: Video Preview Player

As a user,
I want to preview videos directly in the browser,
So that I can review them without downloading.

**Acceptance Criteria:**

**Given** I click on a video thumbnail
**When** the video detail modal/page opens
**Then** the video player loads automatically
**And** the video starts playing (or shows play button)
**And** player controls include: play/pause, volume, fullscreen, progress bar

**Given** I am previewing a video
**When** I interact with the player
**Then** I can scrub through the video timeline
**And** I can adjust volume or mute
**And** I can toggle fullscreen mode
**And** video loads within 2 seconds (NFR4)

**Given** the video URL is invalid or expired
**When** I try to preview
**Then** I see an error message "Video unavailable"
**And** I have an option to report the issue

---

### Story 5.4: Flag Video Quality Issues

As a user,
I want to flag videos with quality issues,
So that I can track which videos have artifacts or problems.

**Acceptance Criteria:**

**Given** I am viewing a video
**When** I click "Flag Quality Issue"
**Then** a dialog opens asking for the issue type and notes

**Given** I am in the flag dialog
**When** I select an issue type (e.g., "Visual artifact", "Audio issue", "6-finger problem", "Incoherent", "Other")
**And** I optionally add a note explaining the issue
**And** I click "Submit Flag"
**Then** PATCH `/api/videos/[id]` is called with:
  - qualityStatus: "FLAGGED"
  - qualityNote: the entered note
**And** the video card shows a "Flagged" badge
**And** I see a success confirmation

**Given** I flag a video
**When** viewing the video later
**Then** I can see the flag reason and notes
**And** I can update the flag or remove it

---

### Story 5.5: Approve/Pass Quality Review

As a user,
I want to mark videos as approved/passed,
So that I know which videos are ready for upload to TikTok.

**Acceptance Criteria:**

**Given** I am viewing a video with qualityStatus PENDING or FLAGGED
**When** I click "Approve" or "Mark as Passed"
**Then** PATCH `/api/videos/[id]` is called with qualityStatus: "PASSED"
**And** the video card shows a "Passed" badge (green checkmark)
**And** qualityNote is cleared if it was previously flagged

**Given** I am viewing the video gallery
**When** I want to quickly approve multiple videos
**Then** I can select multiple videos via checkboxes
**And** I can click "Approve Selected" to batch-approve
**And** all selected videos are updated to PASSED status

**Given** I accidentally approve a video
**When** I want to undo
**Then** I can change the status back to PENDING or flag it

---

### Story 5.6: View Video Metadata

As a user,
I want to view detailed metadata for each video,
So that I understand how it was generated and what it cost.

**Acceptance Criteria:**

**Given** I am viewing a video detail page
**When** I look at the metadata section
**Then** I see:
  - Generation date and time
  - Brief it was generated from (linked)
  - Generation batch (linked)
  - Total cost for this video
  - Avatar provider used
  - Script provider used

**Given** I want to see generation parameters
**When** I expand "Generation Details"
**Then** I see the generationParams JSON formatted readably:
  - Script content used
  - Avatar settings
  - B-roll tags matched
  - Any variation parameters

**Given** I want to see the original brief
**When** I click the brief link
**Then** I navigate to the brief detail view

---

### Story 5.7: Download Video for TikTok

As a user,
I want to download videos to my device,
So that I can upload them to TikTok Ads.

**Acceptance Criteria:**

**Given** I am viewing a video with status COMPLETED
**When** I click "Download"
**Then** the video file downloads to my device
**And** the filename is descriptive: `{briefId}-{videoId}.mp4`
**And** the file is in TikTok-compatible format (MP4, H.264)

**Given** I am in the video gallery
**When** I select multiple videos
**Then** I can click "Download Selected"
**And** videos download as individual files (or as a zip if >3 videos)

**Given** I want to copy the direct URL
**When** I click "Copy URL"
**Then** the R2 public URL is copied to clipboard
**And** I see a "URL copied" confirmation

---

### Story 5.8: Delete Videos

As a user,
I want to delete videos I no longer need,
So that I can clean up my library and manage storage.

**Acceptance Criteria:**

**Given** I am viewing a video
**When** I click "Delete"
**Then** a confirmation dialog appears: "Delete this video? This cannot be undone."

**Given** I confirm deletion
**When** I click "Yes, Delete"
**Then** DELETE `/api/videos/[id]` is called
**And** the Video record is deleted from the database
**And** the video file is deleted from R2 storage
**And** associated CostLog entries are preserved (for historical cost tracking)
**And** I see a success message
**And** I am returned to the gallery

**Given** I want to delete multiple videos
**When** I select videos in the gallery
**Then** I can click "Delete Selected"
**And** a confirmation shows count: "Delete 5 videos?"
**And** all selected videos are deleted on confirmation

**Given** a video is part of an iteration lineage
**When** I try to delete it
**Then** I see a warning: "This video has variations based on it"
**And** I can still proceed with deletion
**And** child generations maintain their parentGenerationId (becomes orphaned reference)

---

## Epic 6: Iterate on Winners

> User can select winning videos and generate variations to scale success

### Story 6.1: Iterate on Winner Workflow

As a user,
I want to select a winning video and create variations of it,
So that I can scale successful ad concepts.

**Acceptance Criteria:**

**Given** I am viewing a video with qualityStatus PASSED
**When** I click "Iterate on Winner"
**Then** an iteration dialog/page opens showing:
  - The source video thumbnail
  - The original brief summary
  - Options to adjust: hook, avatar, B-roll, testimonial points

**Given** I am in the iterate dialog
**When** I configure variation options
**Then** I can:
  - Keep original hook or request variations
  - Keep same avatar style or change persona
  - Keep same B-roll tags or modify them
  - Specify number of variations (1-10)

**Given** I configure and click "Generate Variations"
**When** the request is submitted
**Then** POST `/api/videos/[id]/iterate` is called with:
  - sourceVideoId: the winning video
  - variationParams: the configured adjustments
  - targetCount: number of variations
**And** a new Generation is created with parentGenerationId set
**And** I am navigated to the generation progress page

---

### Story 6.2: Generate Variations with Adjusted Parameters

As a system,
I want to generate variations based on a winning video's parameters,
So that new videos maintain the winning formula while exploring alternatives.

**Acceptance Criteria:**

**Given** an iteration request is received
**When** the generation pipeline starts
**Then** the source video's generationParams are loaded as the base
**And** the variation adjustments are applied:
  - If hook variation requested: generate N different hooks maintaining core message
  - If avatar variation requested: use different persona within same demographic
  - If B-roll variation requested: use alternative matching scenes
**And** unchanged parameters are preserved exactly

**Given** the pipeline generates scripts
**When** "keep original hook" is selected
**Then** the hook remains identical to source
**And** only testimonial delivery/phrasing varies

**Given** the pipeline generates avatars
**When** "vary avatar" is selected
**Then** persona attributes change (age, appearance) within brief constraints
**And** tone and demographic remain consistent

**Given** variations are generated
**When** each video completes
**Then** Video.generationParams stores:
  - sourceVideoId: the original winner
  - variationType: what was varied
  - originalParams: reference to source params

---

### Story 6.3: Parent-Child Generation Tracking

As a system,
I want to track parent-child relationships between generations,
So that iteration history is preserved and queryable.

**Acceptance Criteria:**

**Given** a new Generation is created from iteration
**When** the generation record is saved
**Then** parentGenerationId is set to the source video's generationId
**And** sourceVideoId is stored in the generation metadata

**Given** I GET `/api/generations/[id]`
**When** the generation has a parent
**Then** the response includes:
  - parentGenerationId
  - parentGeneration: { id, briefId, createdAt } (summary)
  - sourceVideo: { id, videoUrl, thumbnailUrl } (if from specific video)

**Given** I GET `/api/generations/[id]/children`
**When** the generation has child iterations
**Then** I receive a list of all generations where parentGenerationId = this id
**And** each child includes basic summary info

**Given** a generation has both parent and children
**When** querying relationships
**Then** the full tree structure is navigable in both directions

---

### Story 6.4: View Iteration Lineage/History

As a user,
I want to view the complete iteration history for any video,
So that I can understand how winning formulas evolved.

**Acceptance Criteria:**

**Given** I am viewing a video that resulted from iteration
**When** I click "View Lineage" or "Iteration History"
**Then** I see a visual tree/timeline showing:
  - Original brief at the root
  - First generation videos
  - Iterations branching from winners
  - Current video highlighted in the tree

**Given** I am viewing the lineage tree
**When** I click on any video in the tree
**Then** I can preview that video
**And** I can see what was changed between generations
**And** I can navigate to that video's detail page

**Given** I am viewing a video detail page
**When** the video has parent iterations
**Then** I see a "Parent" section showing:
  - Link to parent generation
  - Link to source video (the winner it was based on)
  - What parameters were varied

**Given** I am viewing a video detail page
**When** the video has been used as a winner for iterations
**Then** I see a "Variations" section showing:
  - Count of child generations
  - Links to view children
  - Quick stats (how many videos generated from this winner)

**Given** I want to compare iterations
**When** I select multiple videos from the same lineage
**Then** I can view them side-by-side
**And** I see the parameter differences highlighted
