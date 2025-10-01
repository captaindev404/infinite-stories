# Edge Functions Analysis Report

## Executive Summary

Investigation of all story generation-related edge functions revealed several critical issues that need immediate attention. The main problems are in the scene-illustration function with undefined variables, and potential parameter validation mismatches across functions.

## 1. story-generation/index.ts

### Expected Parameters
```typescript
interface StoryGenerationRequest {
  hero_id: string;          // UUID, required
  event: {                  // Object, required
    type: string;           // 'built_in' or 'custom'
    data: any;             // Event-specific data
  };
  target_duration: number;  // 60-600 seconds
  language: string;        // 'en', 'es', 'fr', 'de', 'it'
}
```

### Parameter Validation ✅
- Properly validates all required fields using StoryGenerationSchema
- UUID validation for hero_id
- Enum validation for event type and language
- Duration range validation (60-600 seconds)

### OpenAI API Integration ✅
- Uses GPT-5 Mini with configurable reasoning effort (line 263)
- Proper error handling for API calls
- Includes usage tracking and cost calculation

### Database Operations ✅
- Verifies hero ownership (lines 442-452)
- Handles custom events lookup (lines 469-482)
- Saves story and scenes to database (lines 517-565)

### Response Format ✅
```typescript
interface StoryGenerationResponse {
  story_id: string;
  title: string;
  content: string;
  estimated_duration: number;
  word_count: number;
  scenes: Array<{
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion: string;
    importance: string;
  }>;
}
```

### Issues Found
- **MINOR**: Built-in event lookup expects either 'name' or 'event' field in data (line 460), iOS should standardize on 'name'

## 2. avatar-generation/index.ts

### Expected Parameters
```typescript
interface AvatarGenerationRequest {
  hero_id: string;                    // UUID, required
  prompt: string;                     // 10-1000 chars, required
  size?: string;                      // '1024x1024', '1792x1024', '1024x1792'
  quality?: string;                   // 'low', 'medium', 'high'
  previous_generation_id?: string;    // For visual consistency
}
```

### Parameter Validation ✅
- Validates using AvatarGenerationSchema
- Optional parameters have defaults (size: '1024x1024', quality: 'high')
- Prompt length validation (10-1000 characters)

### OpenAI API Integration ✅
- Uses DALL-E 3 (GPT-5 image model)
- Supports generation ID chaining for consistency (lines 303-312)
- Proper base64 to binary conversion (lines 325-330)

### Database Operations ✅
- Verifies hero ownership (lines 247-256)
- Updates hero with avatar info (lines 176-198)
- Stores generation chain for consistency (lines 203-230)

### Storage Operations ✅
- Uploads to 'hero-avatars' bucket
- Uses consistent naming: `{userId}/{heroId}/avatar.png`
- Supports upsert for updates

### Response Format ✅
```typescript
interface AvatarGenerationResponse {
  avatar_url: string;
  generation_id: string;
  revised_prompt?: string;
  file_size_bytes: number;
  image_size: string;
  quality: string;
}
```

### Issues Found
- None identified

## 3. scene-illustration/index.ts

### Expected Parameters
```typescript
interface SceneIllustrationRequest {
  story_id: string;                   // UUID, required
  scenes: Array<{                    // 1-20 scenes, required
    scene_number: number;
    text_segment: string;
    illustration_prompt: string;
    timestamp_seconds: number;
    emotion?: string;
    importance?: string;
  }>;
  hero_id: string;                   // UUID, required
  process_async?: boolean;           // For background processing
}
```

### Parameter Validation ✅
- Validates using SceneIllustrationSchema
- Array length validation (1-20 scenes)
- Scene object validation

### OpenAI API Integration ⚠️
- Uses DALL-E 3 with generation ID chaining
- Supports batch processing with delays

### Database Operations ✅
- Verifies story and hero ownership (lines 473-495)
- Updates story_illustrations table (lines 341-389)

### Storage Operations ❌ **CRITICAL ISSUE**
- **BUG at line 188**: Undefined variables `storyId` and `userId` in generateSceneIllustration function
- Should be passed as parameters or extracted from context

### Response Format ✅
```typescript
interface SceneIllustrationResponse {
  job_id?: string;           // For async processing
  illustrations?: Array<{
    scene_number: number;
    image_url: string;
    generation_id: string;
    status: 'completed' | 'failed';
    error_message?: string;
  }>;
  status: 'processing' | 'completed' | 'partial';
  total_scenes: number;
  completed_scenes: number;
  estimated_completion?: string;
}
```

### Issues Found
- **CRITICAL**: Lines 188-194 - `storyId` and `userId` are undefined in generateSceneIllustration
- **Fix Required**: Pass these as function parameters

## 4. audio-synthesis/index.ts

### Expected Parameters
```typescript
interface AudioSynthesisRequest {
  story_id: string;    // UUID, optional (made optional at line 141)
  text: string;        // 1-50000 chars, required
  voice: string;       // 'coral', 'nova', 'fable', 'alloy', 'echo', 'onyx', 'shimmer'
  language: string;    // 'en', 'es', 'fr', 'de', 'it'
}
```

### Parameter Validation ✅
- Validates using AudioSynthesisSchema
- Text length validation (1-50000 chars)
- Voice and language enum validation
- Note: story_id is optional (line 141 in validation.ts)

### OpenAI API Integration ✅
- Uses gpt-4o-mini-tts model
- Custom voice instructions based on voice and language (lines 55-126)
- Speed set to 0.95 for better narration (line 330)

### Database Operations ⚠️
- Verifies story access if story_id provided (lines 283-292)
- Updates story with audio info (lines 237-267)
- **Note**: Function works without story_id (standalone TTS)

### Storage Operations ✅
- Uploads to 'story-audio' bucket
- Naming convention: `{userId}/{storyId}/audio.mp3`
- Supports upsert for updates

### Response Format ✅
```typescript
interface AudioSynthesisResponse {
  audio_url: string;
  duration_seconds: number;
  file_size_bytes: number;
  voice_used: string;
  language: string;
}
```

### Issues Found
- **MINOR**: story_id is optional but upload still requires it for file naming

## 5. sync-orchestrator/index.ts

### Expected Parameters
```typescript
interface SyncRequest {
  device_id: string;                              // Required
  device_name?: string;
  device_type: 'ios' | 'android' | 'web';        // Required
  app_version?: string;
  last_sync_cursor?: number;
  entity_types?: string[];
  local_changes: LocalChange[];                   // Required
  capabilities?: {
    supports_real_time: boolean;
    supports_file_sync: boolean;
    max_batch_size: number;
  };
}
```

### Parameter Validation ✅
- Comprehensive validation schema (lines 457-502)
- Entity type validation
- Operation type validation

### Sync Logic ✅
- Bidirectional sync with conflict detection
- Version-based optimistic locking
- Device presence tracking

### Database Operations ✅
- Uses RPC for atomic operations
- Proper transaction handling
- Sync metadata management

### Response Format ✅
```typescript
interface SyncResponse {
  sync_cursor: number;
  device_id: string;
  server_changes: ServerChange[];
  conflicts: ConflictInfo[];
  sync_status: {
    total_processed: number;
    successful: number;
    conflicts: number;
    errors: number;
  };
  next_sync_recommended_at: string;
  real_time_enabled: boolean;
}
```

### Issues Found
- None identified

## 6. extract-scenes/index.ts (Additional Function)

### Expected Parameters ✅
```typescript
interface SceneExtractionRequest {
  story_content: string;
  story_duration: number;
  hero: {
    id: string;
    name: string;
    user_id?: string;
  };
  event_context: string;
}
```

### Implementation ✅
- Standalone scene extraction service
- Uses GPT-5 Mini with high reasoning effort
- Proper caching and validation

## Critical Fixes Required

### 1. scene-illustration/index.ts - Line 188-194
**Problem**: Undefined variables in generateSceneIllustration function

**Current Code**:
```typescript
async function generateSceneIllustration(
  scene: any,
  hero: any,
  storyTitle: string,
  previousGenerationId: string | null,
  requestId: string
): Promise<...> {
  // ... code ...
  const { url: imageUrl } = await uploadSceneImage(
    imageData,
    scene.scene_number,
    storyId,  // ❌ UNDEFINED
    userId,   // ❌ UNDEFINED
    requestId
  );
```

**Fix**:
```typescript
async function generateSceneIllustration(
  scene: any,
  hero: any,
  storyTitle: string,
  storyId: string,        // ✅ Add parameter
  userId: string,          // ✅ Add parameter
  previousGenerationId: string | null,
  requestId: string
): Promise<...> {
  // ... code ...
  const { url: imageUrl } = await uploadSceneImage(
    imageData,
    scene.scene_number,
    storyId,  // ✅ Now defined
    userId,   // ✅ Now defined
    requestId
  );
```

And update the call in processSyncIllustrations (line 331):
```typescript
const result = await generateSceneIllustration(
  scene,
  hero,
  story.title,
  request.story_id,  // ✅ Add story_id
  userId,            // ✅ Add userId
  lastGenerationId,
  requestId
);
```

### 2. story-generation/index.ts - Line 460
**Problem**: Inconsistent event data field naming

**Current Code**:
```typescript
const eventKey = (request.event.data.name || request.event.data.event) as keyof typeof BUILT_IN_EVENTS;
```

**Recommendation**: iOS should standardize on using 'name' field for built-in events

## Recommendations for iOS App Integration

1. **Story Generation**:
   - Always send 'name' field for built-in events in event.data
   - Ensure target_duration is between 60-600 seconds

2. **Avatar Generation**:
   - Optional parameters will default if not provided
   - Use previous_generation_id from hero for consistency

3. **Scene Illustration**:
   - Limit batch size to 10 scenes maximum
   - Consider async processing for >3 scenes

4. **Audio Synthesis**:
   - story_id is optional for standalone TTS
   - Voice must match allowed enum values

5. **Sync Orchestrator**:
   - Include device capabilities for optimal sync
   - Handle conflicts based on resolution_hint

## Performance Considerations

1. **Caching**: All functions implement caching with appropriate TTLs
2. **Rate Limiting**: Batch operations check rate limits
3. **Async Processing**: Scene illustration supports background processing
4. **Error Recovery**: All functions have retry logic and error handling

## Security Validations

✅ All functions properly validate:
- JWT authentication
- User ownership of resources
- Input sanitization
- Content filtering for child safety

## Summary

Most edge functions are correctly implemented with proper parameter validation and error handling. The critical issue in scene-illustration/index.ts must be fixed immediately as it will cause runtime errors. The iOS app should ensure it sends data in the expected format, particularly for built-in events and optional parameters.