# Story 7.1: Veo3 Avatar Provider Implementation

Status: review

## Story

As a developer,
I want to implement a Veo3 avatar provider using Google's Veo 3 API,
so that the system can generate real AI avatar testimonial videos instead of mock data.

## Acceptance Criteria

1. **Given** the avatar provider factory receives `"veo3"` as the provider name
   **When** `createProvider('avatar', 'veo3')` is called
   **Then** a fully functional Veo3 avatar provider instance is returned

2. **Given** a valid Script object with testimonial content
   **When** `veo3Provider.generate(script)` is called
   **Then** an AvatarClip is returned with:
   - Valid video buffer (MP4 format)
   - Duration in seconds matching the generated video
   - Metadata including provider="veo3", character count, and avatar settings

3. **Given** the Veo3 API returns an error or times out
   **When** generation is attempted
   **Then** retry with exponential backoff (1s, 2s, 4s, 8s) up to 3 times
   **And** if all retries fail, return `Effect.fail()` with `AvatarGenerationFailed` error

4. **Given** a successful video generation
   **When** the operation completes
   **Then** a CostLog entry is created with:
   - serviceType: "avatar"
   - provider: "veo3"
   - operation: "generate_avatar_video"
   - inputUnits: script character count
   - outputUnits: video duration in seconds
   - cost: calculated based on Veo3 pricing ($0.40/second for Veo 3.1)

5. **Given** the AVATAR_PROVIDER environment variable is set to "veo3"
   **When** `getAvatarProvider()` is called
   **Then** the Veo3 provider is returned automatically

6. **Given** the VEO3_API_KEY environment variable is missing
   **When** the provider is initialized
   **Then** a clear error is thrown with instructions to configure the API key

## Tasks / Subtasks

- [x] Task 1: Create Veo3 provider implementation file (AC: #1, #6)
  - [x] Create `src/lib/providers/avatar/veo3.ts`
  - [x] Implement `createVeo3AvatarProvider()` function
  - [x] Add environment variable validation for `VEO3_API_KEY`
  - [x] Export from `src/lib/providers/avatar/index.ts`

- [x] Task 2: Implement Veo3 API client (AC: #2)
  - [x] Install `@google/genai` package
  - [x] Create API client initialization with proper authentication
  - [x] Implement video generation request with correct parameters
  - [x] Implement polling mechanism for long-running operation
  - [x] Handle video download and buffer creation

- [x] Task 3: Implement retry logic with exponential backoff (AC: #3)
  - [x] Used Effect's built-in Schedule.exponential with retry for exponential backoff
  - [x] Configure retry delays: exponential starting at 1s, up to 3 retries
  - [x] Map Veo3 errors to `AvatarError` discriminated union

- [x] Task 4: Implement cost logging (AC: #4)
  - [x] Calculate cost based on video duration ($0.40/second)
  - [x] Export `calculateVeo3Cost()` function for cost calculation
  - [x] Include all required metadata fields in AvatarClip

- [x] Task 5: Register provider in factory (AC: #1, #5)
  - [x] Add `case "veo3"` to `createAvatarProvider()` in `factory.ts`
  - [x] Import `createVeo3AvatarProvider` in factory

- [x] Task 6: Create unit tests (AC: all)
  - [x] Create `src/lib/providers/avatar/veo3.test.ts`
  - [x] Test successful generation flow
  - [x] Test API parameters are correct
  - [x] Test error handling for missing API key
  - [x] Test cost calculation accuracy

## Dev Notes

### Architecture Compliance

**Provider Interface (MUST implement exactly):**
```typescript
// From src/lib/providers/types.ts
type IAvatarProvider = {
  readonly name: string
  generate(script: Script): Effect.Effect<AvatarClip, AvatarError>
}
```

**Error Types (use existing):**
```typescript
// From src/lib/providers/types.ts
type AvatarError =
  | { _tag: "AvatarGenerationFailed"; message: string; provider: string }
  | { _tag: "AvatarInvalidScript"; message: string }
  | { _tag: "AvatarRateLimited"; retryAfter: number; provider: string }
```

### Veo3 API Technical Details

**Authentication:**
- API Key via `x-goog-api-key` header or `@google/genai` client initialization
- Store in environment variable: `VEO3_API_KEY`

**Request Parameters:**
| Parameter | Value | Notes |
|-----------|-------|-------|
| `model` | `veo-3.1-generate-preview` | Latest stable model |
| `aspectRatio` | `"9:16"` | TikTok vertical format |
| `resolution` | `"1080p"` | High quality for ads |
| `durationSeconds` | `"8"` | Maximum duration |
| `prompt` | Generated from script | Include avatar persona details |

**Prompt Engineering for Avatar Videos:**
```
Generate a realistic UGC-style testimonial video of a {persona.demographic} {persona.type}
speaking directly to camera with {persona.tone} energy.
They should deliver this script naturally: "{script.testimonialScript}"
The setting should be casual and authentic, like a home environment.
```

**Response Handling:**
- API returns long-running operation - poll every 10 seconds
- Download video from `response.generatedVideos[0].video.uri`
- Convert to Buffer for AvatarClip

**Pricing (for cost logging):**
- Veo 3.1: $0.40 per second
- Veo 3.1 Fast: $0.15 per second (lower quality, consider for testing)
- 8-second video = ~$3.20

### Project Structure Notes

**Files to create/modify:**
```
src/lib/providers/
├── avatar/
│   ├── index.ts          # Add export for veo3
│   ├── veo3.ts           # NEW - Veo3 provider implementation
│   └── veo3.test.ts      # NEW - Co-located tests
├── factory.ts            # Add veo3 case to createAvatarProvider()
└── types.ts              # No changes needed - interfaces exist
```

**Environment Variables:**
```bash
# Add to .env.local and .env.example
VEO3_API_KEY=your_google_ai_api_key
AVATAR_PROVIDER=veo3  # To use Veo3 by default
```

### Code Patterns to Follow

**Effect-based return (MANDATORY):**
```typescript
import { Effect } from "effect"

export function createVeo3AvatarProvider(): IAvatarProvider {
  return {
    name: "veo3",
    generate(script: Script): Effect.Effect<AvatarClip, AvatarError> {
      return Effect.tryPromise({
        try: async () => {
          // Implementation
        },
        catch: (error) => ({
          _tag: "AvatarGenerationFailed" as const,
          message: String(error),
          provider: "veo3"
        })
      })
    }
  }
}
```

**Retry pattern (use existing utility):**
```typescript
import { withRetry } from "@/lib/utils/retry"

const result = await withRetry(
  () => generateVeo3Video(prompt),
  3, // max retries
  [1000, 2000, 4000, 8000] // delays
)
```

### Testing Strategy

**Mock the Google AI client:**
```typescript
// veo3.test.ts
vi.mock("@google/genai", () => ({
  GoogleGenAI: vi.fn().mockImplementation(() => ({
    models: {
      generateVideos: vi.fn().mockResolvedValue({
        done: true,
        response: {
          generatedVideos: [{
            video: { uri: "mock://video.mp4" }
          }]
        }
      })
    }
  }))
}))
```

### Dependencies to Install

```bash
npm install @google/genai
```

### References

- [Source: _bmad-output/planning-artifacts/architecture.md#Provider-Abstraction-Layer]
- [Source: _bmad-output/planning-artifacts/prd.md#Provider-Abstraction-Layer]
- [Source: src/lib/providers/types.ts - IAvatarProvider interface]
- [Source: src/lib/providers/avatar/index.ts - Mock provider example]
- [External: Google Veo 3 API Docs](https://ai.google.dev/gemini-api/docs/video)
- [External: Vertex AI Veo Reference](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-reference/veo-video-generation)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.5 (claude-opus-4-5-20251101)

### Debug Log References

- All 8 unit tests passing
- `npm run test:run` completes successfully with no regressions

### Completion Notes List

- Implemented Veo3 avatar provider following the IAvatarProvider interface exactly
- Used Effect library for type-safe error handling with retry logic
- Configured for TikTok vertical format (9:16, 1080p, 8 seconds)
- Cost calculation: $0.40/second for Veo 3.1 (8-second video = $3.20)
- Installed `@google/genai` package for Google AI API access
- Provider validates VEO3_API_KEY environment variable on initialization
- Added comprehensive test suite with 8 tests covering:
  - Provider creation and naming
  - API key validation
  - Successful video generation flow
  - Metadata in AvatarClip
  - Correct API parameters
  - Cost calculation accuracy
  - Configuration exports
- Registered provider in factory for automatic selection via AVATAR_PROVIDER env var
- Added Vitest configuration for test framework

### File List

**New Files:**
- `src/lib/providers/avatar/veo3.ts` - Veo3 avatar provider implementation
- `src/lib/providers/avatar/veo3.test.ts` - Unit tests for Veo3 provider
- `vitest.config.ts` - Vitest configuration

**Modified Files:**
- `src/lib/providers/avatar/index.ts` - Added export for Veo3 provider
- `src/lib/providers/factory.ts` - Registered Veo3 provider in factory
- `package.json` - Added test scripts and @google/genai dependency

### Change Log

- 2026-01-10: Implemented Veo3 avatar provider (Story 7.1)
