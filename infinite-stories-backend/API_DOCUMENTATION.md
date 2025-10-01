# Infinite Stories Backend API Documentation

Comprehensive API documentation for the Infinite Stories Supabase Edge Functions backend, providing a secure, scalable, and child-safe story generation platform.

## Overview

The InfiniteStories backend is a Supabase-powered API that provides comprehensive story generation, audio synthesis, and illustration services designed specifically for children aged 4-10. Built with safety, performance, and scalability at its core.

### Key Features
- **Complete Story Generation**: AI-powered personalized bedtime stories with scene extraction
- **Multi-Voice Audio Synthesis**: Text-to-speech with 7 specialized voices
- **Visual Generation**: Hero avatars and scene illustrations with consistency
- **Content Safety**: Multi-layer filtering system ensuring child-appropriate content
- **Performance Optimized**: Database-backed caching and rate limiting
- **Multi-Language Support**: 5 languages (English, Spanish, French, German, Italian)

## Table of Contents

- [Architecture](#architecture)
- [Authentication](#authentication)
- [Error Handling](#error-handling)
- [Rate Limiting](#rate-limiting)
- [Content Safety](#content-safety)
- [API Endpoints](#api-endpoints)
  - [Story Generation API](#story-generation-api)
  - [Audio Synthesis API](#audio-synthesis-api)
  - [Avatar Generation API](#avatar-generation-api)
  - [Scene Illustration API](#scene-illustration-api)
- [Database Schema](#database-schema)
- [Caching Strategy](#caching-strategy)
- [Usage Tracking](#usage-tracking)
- [iOS Integration Examples](#ios-integration-examples)
- [WebSocket Real-Time Updates](#websocket-real-time-updates)
- [Testing](#testing)

## Architecture

### System Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   iOS Client    │────▶│  Supabase Edge Func  │────▶│   OpenAI API    │
│                 │◀────│                      │◀────│                 │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                               │        │
                               ▼        ▼
                        ┌──────────┐ ┌──────────┐
                        │PostgreSQL│ │ Storage  │
                        └──────────┘ └──────────┘
```

### Edge Functions Structure

```
supabase/functions/
├── story-generation/     # Story creation with scene extraction
├── audio-synthesis/      # Text-to-speech conversion
├── avatar-generation/    # Hero avatar creation
├── scene-illustration/   # Scene image generation
└── _shared/             # Shared utilities
    ├── auth.ts          # JWT validation
    ├── cache.ts         # Caching layer
    ├── content-filter.ts # Safety filtering
    ├── cors.ts          # CORS handling
    ├── errors.ts        # Error management
    ├── logger.ts        # Logging system
    ├── openai-client.ts # OpenAI integration
    ├── rate-limiter.ts  # Rate limiting
    └── validation.ts    # Input validation
```

### Technology Stack

- **Runtime**: Deno (Edge Functions)
- **Database**: PostgreSQL with Row Level Security
- **Storage**: Supabase Storage (S3-compatible)
- **Authentication**: Supabase Auth with JWT
- **AI Models**: OpenAI GPT-5, gpt-4o-mini-tts, GPT-5 (images)
- **Languages**: TypeScript, SQL

### Request Flow

1. **Authentication**: JWT validation via Supabase Auth
2. **Rate Limiting**: Per-user, per-function limits
3. **Input Validation**: Schema validation with Zod
4. **Content Filtering**: Multi-layer safety checks
5. **Processing**: AI model interaction
6. **Caching**: Response caching for performance
7. **Storage**: Asset persistence in Supabase Storage
8. **Response**: Standardized JSON response

## Authentication

All API endpoints require authentication via Supabase JWT tokens.

### Headers Required
```http
Authorization: Bearer <supabase-jwt-token>
Content-Type: application/json
```

### iOS Authentication Setup
```swift
import Supabase

class SupabaseClient {
    static let shared = SupabaseClient(
        supabaseURL: URL(string: "https://your-project-ref.supabase.co")!,
        supabaseKey: "your-supabase-anon-key"
    )
}

func getCurrentToken() async throws -> String {
    let session = try await SupabaseClient.shared.auth.session
    return session.accessToken
}
```

## Error Handling

### Standard Error Response Format
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message",
    "details": {},
    "retry_after": 3600
  },
  "request_id": "uuid-request-id",
  "timestamp": "2023-09-27T15:30:00Z"
}
```

### Error Codes
| Code | Description | HTTP Status |
|------|-------------|-------------|
| `UNAUTHORIZED` | Invalid or missing JWT token | 401 |
| `RATE_LIMITED` | Rate limit exceeded | 429 |
| `INVALID_REQUEST` | Request validation failed | 400 |
| `CONTENT_POLICY_VIOLATION` | Content violates safety policies | 400 |
| `OPENAI_ERROR` | OpenAI API error | 500 |
| `TIMEOUT` | Request timed out | 408 |
| `INTERNAL_ERROR` | Internal server error | 500 |

## Rate Limiting

### Overview

Rate limiting is enforced at the user level to ensure fair usage and prevent abuse. The system tracks API calls per user, per function with automatic cleanup of expired records.

### Rate Limits by Function

| Function | Free Tier | Premium Tier | Window | Burst |
|----------|-----------|--------------|--------|-------|
| Story Generation | 10 requests | 50 requests | per hour | 3 |
| Audio Synthesis | 15 requests | 75 requests | per hour | 5 |
| Avatar Generation | 8 requests | 40 requests | per hour | 2 |
| Scene Illustration | 25 requests | 100 requests | per hour | 10 |

### Rate Limit Headers

Response headers indicate rate limit status:

```http
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 7
X-RateLimit-Reset: 1696118400
X-RateLimit-Retry-After: 3600
```

### Rate Limit Response

When rate limit is exceeded:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Rate limit exceeded. Please try again later.",
    "details": {
      "limit": 10,
      "window": "1h",
      "reset_at": "2024-09-27T16:00:00Z"
    },
    "retry_after": 3600
  },
  "request_id": "uuid-request-id"
}
```

## Content Safety

### Multi-Layer Filtering System

The backend implements comprehensive content filtering to ensure all generated content is appropriate for children aged 4-10.

#### 1. Rule-Based Filtering

Automatic replacement of inappropriate terms with child-friendly alternatives:

```typescript
// Example replacements
"weapon" → "magical wand"
"fight" → "challenge"
"scary" → "mysterious"
"alone" → "with friends"
```

#### 2. AI-Powered Content Analysis

GPT-5 analyzes content for appropriateness:

```typescript
interface ContentAnalysis {
  is_appropriate: boolean;
  confidence: number;
  concerns: string[];
  suggested_modifications: string[];
}
```

#### 3. Image Prompt Sanitization

All image generation prompts are filtered:
- Ensures bright, colorful, child-friendly imagery
- Adds safety modifiers (\"child-friendly\", \"watercolor style\")
- Removes any potentially concerning elements
- Enforces companionship (children never shown alone)

#### 4. Companionship Enforcement

Critical safety feature ensuring children are never depicted alone:

```typescript
// Automatic additions to prompts
if (promptContainsChild && !promptContainsCompanion) {
  prompt += " with friendly animal companions"
}
```

### Filtering Categories

| Category | Description | Action |
|----------|-------------|--------|
| Violence | Fighting, weapons, conflict | Replace with peaceful alternatives |
| Fear | Scary, dark, frightening elements | Transform to mysterious/magical |
| Isolation | Children alone or lost | Add companions or helpers |
| Inappropriate | Adult themes or language | Remove or replace entirely |
| Medical | Illness, injury references | Replace with magical ailments |
| Family | Parental absence themes | Add magical guardians |

### Content Validation Flow

```
User Input → Rule-Based Filter → AI Analysis → Final Validation → Safe Output
     ↓              ↓                ↓              ↓
   Log           Replace         Analyze        Verify
```

## API Endpoints

All endpoints follow RESTful conventions and return JSON responses.

### Base URL
```
https://{project-ref}.supabase.co/functions/v1
```

## Story Generation API

Creates personalized bedtime stories with automatic scene extraction for illustrations.

### Endpoint
```
POST /functions/v1/story-generation
```

### Request Format
```json
{
  "hero_id": "uuid-of-hero",
  "event": {
    "type": "built_in" | "custom",
    "data": {
      "event": "magical_forest_adventure",
      "custom_event_id": "uuid-for-custom-events"
    }
  },
  "target_duration": 300,
  "language": "en"
}
```

### Response Format
```json
{
  "success": true,
  "data": {
    "story_id": "uuid-of-generated-story",
    "title": "Luna and the Magical Forest Adventure",
    "content": "Once upon a time, in a magical forest...",
    "estimated_duration": 320,
    "word_count": 456,
    "scenes": [
      {
        "scene_number": 1,
        "text_segment": "Luna stepped into the magical forest...",
        "illustration_prompt": "A cheerful child entering a bright magical forest...",
        "timestamp_seconds": 0,
        "emotion": "joyful",
        "importance": "key"
      }
    ]
  },
  "meta": {
    "request_id": "uuid",
    "processing_time": 1200,
    "cached": false
  }
}
```

### Built-in Events
```swift
enum StoryEvent: String, CaseIterable {
    case magicalForestAdventure = "magical_forest_adventure"
    case friendlyDragonEncounter = "friendly_dragon_encounter"
    case underwaterTreasureHunt = "underwater_treasure_hunt"
    case cloudCastleJourney = "cloud_castle_journey"
    case timeTravelMission = "time_travel_mission"
    case spaceExploration = "space_exploration"
    case miniatureWorldDiscovery = "miniature_world_discovery"
    case weatherWizardTraining = "weather_wizard_training"
    case animalLanguageLearning = "animal_language_learning"
    case dreamWorldAdventure = "dream_world_adventure"
}
```

## Audio Synthesis API

### Endpoint
```
POST /functions/v1/audio-synthesis
```

### Request Format
```json
{
  "story_id": "uuid-of-story",
  "text": "Once upon a time, in a magical forest...",
  "voice": "coral",
  "language": "en"
}
```

### Supported Voices
| Voice | Description | Best For |
|-------|-------------|----------|
| `coral` | Warm, gentle, nurturing | Bedtime stories |
| `nova` | Friendly, cheerful, engaging | Adventure stories |
| `fable` | Wise, grandfather-like | Traditional tales |
| `alloy` | Clear, pleasant, neutral | Educational content |
| `echo` | Soft, dreamy, ethereal | Magical stories |
| `onyx` | Deep, warm, reassuring | Protective character |
| `shimmer` | Bright, melodic, enchanting | Whimsical tales |

### Response Format
```json
{
  "success": true,
  "data": {
    "audio_url": "https://storage.url/path/to/audio.mp3",
    "duration_seconds": 320,
    "file_size_bytes": 1048576,
    "voice_used": "coral",
    "language": "en"
  },
  "meta": {
    "request_id": "uuid",
    "processing_time": 3500,
    "cached": false
  }
}
```

## Avatar Generation API

### Endpoint
```
POST /functions/v1/avatar-generation
```

### Request Format
```json
{
  "hero_id": "uuid-of-hero",
  "prompt": "A brave and kind child with curly brown hair...",
  "size": "1024x1024",
  "quality": "high",
  "previous_generation_id": "optional-for-consistency"
}
```

### Response Format
```json
{
  "success": true,
  "data": {
    "avatar_url": "https://storage.url/path/to/avatar.png",
    "generation_id": "gen_12345",
    "revised_prompt": "AI-revised prompt for safety",
    "file_size_bytes": 2097152,
    "image_size": "1024x1024",
    "quality": "high"
  },
  "meta": {
    "request_id": "uuid",
    "processing_time": 8000,
    "cached": false
  }
}
```

## Scene Illustration API

### Endpoint
```
POST /functions/v1/scene-illustration
```

### Request Format
```json
{
  "story_id": "uuid-of-story",
  "scenes": [
    {
      "scene_number": 1,
      "text_segment": "Luna stepped into the magical forest...",
      "illustration_prompt": "A cheerful child entering a bright magical forest...",
      "timestamp_seconds": 0,
      "emotion": "joyful",
      "importance": "key"
    }
  ],
  "hero_id": "uuid-of-hero",
  "process_async": false
}
```

### Response Format
```json
{
  "success": true,
  "data": {
    "illustrations": [
      {
        "scene_number": 1,
        "image_url": "https://storage.url/path/to/scene1.png",
        "generation_id": "gen_67890",
        "status": "completed"
      }
    ],
    "status": "completed",
    "total_scenes": 1,
    "completed_scenes": 1
  },
  "meta": {
    "request_id": "uuid",
    "processing_time": 15000,
    "cached": false
  }
}
```

## iOS Integration Examples

### Complete Story Creation Service
```swift
class StoryService {
    func createCompleteStory(
        hero: Hero,
        event: StoryEvent,
        voice: Voice,
        targetDuration: Int = 300
    ) async throws -> CompleteStory {

        // 1. Generate story content
        let storyRequest = StoryGenerationRequest(
            heroId: hero.id,
            event: EventData(
                type: "built_in",
                data: ["event": event.rawValue]
            ),
            targetDuration: targetDuration,
            language: "en"
        )

        let storyResponse = try await generateStory(request: storyRequest)

        // 2. Generate audio
        let audioRequest = AudioSynthesisRequest(
            storyId: storyResponse.storyId,
            text: storyResponse.content,
            voice: voice.rawValue,
            language: "en"
        )

        let audioResponse = try await synthesizeAudio(request: audioRequest)

        // 3. Generate scene illustrations
        if !storyResponse.scenes.isEmpty {
            let illustrationRequest = SceneIllustrationRequest(
                storyId: storyResponse.storyId,
                scenes: storyResponse.scenes.map { scene in
                    SceneData(
                        sceneNumber: scene.sceneNumber,
                        textSegment: scene.textSegment,
                        illustrationPrompt: scene.illustrationPrompt,
                        timestampSeconds: scene.timestampSeconds,
                        emotion: scene.emotion,
                        importance: scene.importance
                    )
                },
                heroId: hero.id,
                processAsync: false
            )

            let _ = try await generateSceneIllustrations(request: illustrationRequest)
        }

        return CompleteStory(
            story: storyResponse,
            audioUrl: audioResponse.audioUrl,
            duration: audioResponse.durationSeconds
        )
    }
}
```

### Error Handling with Official SDK Benefits
```swift
class APIClient {
    func handleOpenAIError(_ error: Error) -> AIServiceError {
        // The official SDK provides better error context
        if let apiError = error as? APIError {
            switch apiError.code {
            case "RATE_LIMITED":
                return .rateLimitExceeded
            case "CONTENT_POLICY_VIOLATION":
                return .contentPolicyViolation(apiError.message)
            case "TIMEOUT":
                return .networkError(error)
            default:
                return .apiError(apiError.message)
            }
        }
        return .networkError(error)
    }
}
```

### Cost Monitoring
```swift
class CostTracker {
    func trackAPIUsage(response: StoryGenerationResponse) {
        // Monitor GPT-5 cost
        if let usage = response.tokenUsage {
            let estimatedCost = calculateGPT5Cost(usage)

            Analytics.track("api_cost", properties: [
                "model": "gpt-5",
                "function": "story_generation",
                "tokens": usage.totalTokens,
                "cost": estimatedCost,
                "reasoning_tokens": usage.reasoningTokens ?? 0
            ])
        }
    }

    private func calculateGPT5Cost(_ usage: TokenUsage) -> Double {
        // GPT-5 pricing: $0.0015 per 1K input tokens, $0.006 per 1K output tokens
        let inputCost = Double(usage.promptTokens) / 1000.0 * 0.0015
        let outputCost = Double(usage.completionTokens) / 1000.0 * 0.006
        return inputCost + outputCost
    }
}
```

## Database Schema

### Core Tables

#### heroes
Stores character information for personalized stories.

```sql
CREATE TABLE heroes (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    name TEXT NOT NULL,
    primary_trait TEXT NOT NULL,
    secondary_trait TEXT NOT NULL,
    appearance TEXT,
    special_ability TEXT,
    avatar_url TEXT,
    avatar_generation_id TEXT,
    visual_profile JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true
);
```

#### stories
Generated story content with metadata.

```sql
CREATE TABLE stories (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    hero_id UUID REFERENCES heroes(id),
    custom_event_id UUID REFERENCES custom_events(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    event_type TEXT,
    event_data JSONB,
    audio_url TEXT,
    audio_duration INTERVAL,
    language TEXT DEFAULT 'en',
    estimated_duration INTERVAL,
    word_count INTEGER,
    generation_metadata JSONB,
    created_at TIMESTAMPTZ,
    is_favorite BOOLEAN DEFAULT false,
    play_count INTEGER DEFAULT 0
);
```

#### story_scenes
Extracted scenes for illustration generation.

```sql
CREATE TABLE story_scenes (
    id UUID PRIMARY KEY,
    story_id UUID REFERENCES stories(id),
    scene_number INTEGER NOT NULL,
    text_segment TEXT NOT NULL,
    illustration_prompt TEXT NOT NULL,
    sanitized_prompt TEXT,
    timestamp_seconds DECIMAL NOT NULL,
    emotion TEXT,
    importance TEXT,
    created_at TIMESTAMPTZ
);
```

#### story_illustrations
Generated images for story scenes.

```sql
CREATE TABLE story_illustrations (
    id UUID PRIMARY KEY,
    scene_id UUID REFERENCES story_scenes(id),
    story_id UUID REFERENCES stories(id),
    image_url TEXT,
    generation_id TEXT,
    previous_generation_id TEXT,
    revised_prompt TEXT,
    status TEXT DEFAULT 'pending',
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    generation_metadata JSONB
);
```

#### api_usage
Tracks API usage for monitoring and billing.

```sql
CREATE TABLE api_usage (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    function_name TEXT NOT NULL,
    request_id TEXT,
    status TEXT,
    response_time_ms INTEGER,
    tokens_used INTEGER,
    cost_estimate DECIMAL,
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
);
```

#### rate_limits
Manages per-user rate limiting.

```sql
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY,
    user_id UUID,
    function_name TEXT,
    request_count INTEGER,
    window_start TIMESTAMPTZ,
    window_end TIMESTAMPTZ,
    UNIQUE(user_id, function_name, window_start)
);
```

#### cache_entries
Database-backed caching system.

```sql
CREATE TABLE cache_entries (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ,
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ
);
```

### Row Level Security Policies

All tables implement RLS for data isolation:

```sql
-- Example: Users can only access their own stories
CREATE POLICY "Users can view own stories" ON stories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stories" ON stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

## Caching Strategy

### Cache Layers

1. **Database Cache**: Persistent cache in PostgreSQL
2. **Edge Function Memory**: In-memory cache for hot data
3. **CDN Cache**: Static assets cached at edge locations

### Cache Configuration

| Content Type | TTL | Strategy |
|--------------|-----|----------|
| Story Content | 24 hours | Database cache |
| Audio Files | 7 days | CDN cache |
| Avatar Images | 30 days | CDN cache |
| Scene Illustrations | 30 days | CDN cache |
| API Responses | 1 hour | Database cache |

### Cache Key Patterns

```typescript
// Story generation cache key
`story:${hero_id}:${event_type}:${event_id}:${language}:${duration}`

// Audio synthesis cache key
`audio:${story_id}:${voice}:${language}`

// Avatar generation cache key
`avatar:${hero_id}:${generation_id}`

// Scene illustration cache key
`scene:${story_id}:${scene_number}:${generation_id}`
```

## Usage Tracking

### Metrics Collected

- **Request Metrics**: Function name, user ID, response time
- **Token Usage**: Input/output tokens for cost calculation
- **Error Tracking**: Error types, messages, and stack traces
- **Cache Performance**: Hit/miss ratios, access patterns

### Cost Calculation

```typescript
interface CostCalculation {
  model: string;
  input_tokens: number;
  output_tokens: number;
  input_cost_per_1k: number;
  output_cost_per_1k: number;
  total_cost: number;
}
```

### Analytics Queries

```sql
-- Daily usage by function
SELECT
    function_name,
    DATE(created_at) as date,
    COUNT(*) as requests,
    AVG(response_time_ms) as avg_response_time,
    SUM(cost_estimate) as total_cost
FROM api_usage
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY function_name, DATE(created_at)
ORDER BY date DESC, function_name;

-- User activity summary
SELECT
    user_id,
    COUNT(DISTINCT DATE(created_at)) as active_days,
    COUNT(*) as total_requests,
    SUM(cost_estimate) as total_cost
FROM api_usage
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY user_id
ORDER BY total_requests DESC;
```

## WebSocket Real-Time Updates

### Subscription Types

```typescript
// Subscribe to story generation status
const storySubscription = supabase
  .channel('story-updates')
  .on('postgres_changes',
    {
      event: 'INSERT',
      schema: 'public',
      table: 'stories',
      filter: `user_id=eq.${userId}`
    },
    (payload) => {
      console.log('New story created:', payload.new);
    }
  )
  .subscribe();

// Subscribe to illustration generation progress
const illustrationSubscription = supabase
  .channel('illustration-progress')
  .on('postgres_changes',
    {
      event: 'UPDATE',
      schema: 'public',
      table: 'story_illustrations',
      filter: `story_id=eq.${storyId}`
    },
    (payload) => {
      console.log('Illustration status:', payload.new.status);
    }
  )
  .subscribe();
```

### Real-Time Events

| Event | Table | Trigger |
|-------|-------|---------|
| story.created | stories | INSERT |
| story.updated | stories | UPDATE |
| audio.ready | stories | UPDATE (audio_url) |
| scene.illustrated | story_illustrations | UPDATE (status='completed') |
| hero.created | heroes | INSERT |

## Testing

### Test Endpoints

Each function includes a test mode for development:

```bash
# Test story generation
curl -X POST http://localhost:54321/functions/v1/story-generation \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "X-Test-Mode: true" \
  -d '{"test": true}'
```

### Test Data

Seed data for testing is available in `supabase/seed.sql`:

```sql
-- Test hero
INSERT INTO heroes (user_id, name, primary_trait, secondary_trait)
VALUES (auth.uid(), 'Luna', 'brave', 'kind');

-- Test custom event
INSERT INTO custom_events (user_id, title, prompt_seed)
VALUES (auth.uid(), 'Rainbow Bridge Adventure', 'discovers a rainbow bridge to a cloud kingdom');
```

### Integration Tests

```typescript
// Example integration test
describe('Story Generation', () => {
  it('should generate a complete story with scenes', async () => {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/story-generation`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        hero_id: testHeroId,
        event: {
          type: 'built_in',
          data: { event: 'magical_forest_adventure' }
        },
        target_duration: 300,
        language: 'en'
      })
    });

    const story = await response.json();
    expect(story).toHaveProperty('story_id');
    expect(story).toHaveProperty('scenes');
    expect(story.scenes.length).toBeGreaterThan(0);
  });
});
```

### Load Testing

```bash
# Using Apache Bench for load testing
ab -n 100 -c 10 \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -p request.json \
  https://project-ref.supabase.co/functions/v1/story-generation
```

## Advanced Features

### Batch Processing

Process multiple scenes or stories in parallel:

```typescript
// Batch scene illustration
POST /functions/v1/scene-illustration
{
  "story_id": "uuid",
  "scenes": [...],
  "process_async": true,
  "batch_size": 5
}
```

### Streaming Responses

Real-time story generation with streaming:

```typescript
// Enable streaming for long stories
const eventSource = new EventSource(
  `${SUPABASE_URL}/functions/v1/story-generation-stream`,
  {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  }
);

eventSource.onmessage = (event) => {
  const chunk = JSON.parse(event.data);
  console.log('Story chunk:', chunk.content);
};
```

### Custom Voice Training

Upload voice samples for personalized narration:

```typescript
interface VoiceProfile {
  voice_id: string;
  samples: AudioFile[];
  characteristics: {
    pitch: number;
    speed: number;
    emotion: string;
  };
}
```

### Multi-Model Fallback

Automatic fallback to alternative models:

```typescript
const modelConfig = {
  model: 'gpt-5',
  maxRetries: 3,
  reasoning_effort: 'low',  // configurable: minimal, low, medium, high
  text_verbosity: 'low'      // configurable: low, medium, high
};
```

### Content Versioning

Track and rollback content changes:

```sql
CREATE TABLE content_versions (
    id UUID PRIMARY KEY,
    content_id UUID,
    content_type TEXT,
    version_number INTEGER,
    content JSONB,
    created_at TIMESTAMPTZ,
    created_by UUID
);
```

## Performance Optimization

### Request Optimization

- **Batch Requests**: Combine multiple API calls
- **Parallel Processing**: Concurrent scene generation
- **Smart Caching**: Predictive cache warming
- **Connection Pooling**: Reuse database connections

### Response Times

| Operation | P50 | P95 | P99 |
|-----------|-----|-----|-----|
| Story Generation | 1.2s | 2.5s | 4.0s |
| Audio Synthesis | 2.0s | 3.5s | 5.0s |
| Avatar Generation | 3.0s | 5.0s | 8.0s |
| Scene Illustration | 4.0s | 7.0s | 10.0s |

## Security Best Practices

### API Key Management

```typescript
// Never expose service role key to clients
const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_ANON_KEY // Public key only
);
```

### Input Sanitization

All inputs are validated and sanitized:

```typescript
const sanitizedInput = DOMPurify.sanitize(userInput);
const validatedData = schema.parse(sanitizedInput);
```

### Rate Limiting Implementation

```typescript
class RateLimiter {
  async checkLimit(userId: string, functionName: string): Promise<boolean> {
    const window = 3600; // 1 hour
    const limit = this.getLimit(functionName);

    const count = await this.getRequestCount(userId, functionName, window);
    return count < limit;
  }
}
```

## Migration Guide

### From Direct OpenAI to Supabase Backend

1. **Update API Endpoints**
   ```typescript
   // Before
   const response = await openai.createCompletion({...});

   // After
   const response = await fetch(`${SUPABASE_URL}/functions/v1/story-generation`, {
     headers: { 'Authorization': `Bearer ${token}` },
     body: JSON.stringify({...})
   });
   ```

2. **Authentication Migration**
   ```typescript
   // Initialize Supabase client
   const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

   // Get auth token
   const { data: { session } } = await supabase.auth.getSession();
   const token = session?.access_token;
   ```

3. **Error Handling Updates**
   ```typescript
   try {
     const response = await callSupabaseFunction(data);
   } catch (error) {
     if (error.code === 'RATE_LIMITED') {
       // Handle rate limiting
     } else if (error.code === 'CONTENT_POLICY_VIOLATION') {
       // Handle content safety
     }
   }
   ```

## Monitoring and Observability

### Metrics Dashboard

Key metrics to monitor:

- **API Health**: Success rate, error distribution
- **Performance**: Response times, throughput
- **Usage**: Requests per user, token consumption
- **Cost**: API costs by function and user

### Logging Structure

```typescript
interface LogEntry {
  timestamp: string;
  request_id: string;
  user_id: string;
  function_name: string;
  level: 'info' | 'warn' | 'error';
  message: string;
  metadata: Record<string, any>;
}
```

### Alert Configuration

```yaml
alerts:
  - name: high_error_rate
    condition: error_rate > 0.05
    window: 5m
    action: notify_oncall

  - name: slow_response
    condition: p95_latency > 5000ms
    window: 10m
    action: scale_up
```

---

This comprehensive API documentation provides everything needed to integrate with and operate the InfiniteStories Supabase backend. For additional support, consult the deployment guide or contact the development team.