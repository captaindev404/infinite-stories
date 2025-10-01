# iOS Edge Function Integration Fixes

## Immediate Actions Required

### 1. ✅ Fixed: scene-illustration/index.ts Critical Bug
**Status**: FIXED
- Added missing `storyId` and `userId` parameters to `generateSceneIllustration` function
- Updated function signature at line 130-137
- Updated function call at line 333-341

### 2. iOS App Changes Required

#### Story Generation Request Format
Ensure your iOS app sends built-in events with the 'name' field:

```swift
// ✅ Correct format for built-in events
let event = [
    "type": "built_in",
    "data": [
        "name": "Bedtime Adventure"  // Use 'name' not 'event'
    ]
]

// ✅ Correct format for custom events
let event = [
    "type": "custom",
    "data": [
        "custom_event_id": "uuid-here"
    ]
]
```

#### Audio Synthesis Optional story_id
The `story_id` parameter is now optional for audio synthesis:

```swift
// With story (will save to story record)
let request = [
    "story_id": "uuid-here",  // Optional
    "text": "Story content...",
    "voice": "coral",
    "language": "en"
]

// Standalone TTS (no story association)
let request = [
    "text": "Any text to convert...",
    "voice": "nova",
    "language": "es"
]
```

## Testing Checklist

### Story Generation
```bash
curl -X POST https://your-project.supabase.co/functions/v1/story-generation \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "valid-uuid",
    "event": {
      "type": "built_in",
      "data": {
        "name": "Bedtime Adventure"
      }
    },
    "target_duration": 180,
    "language": "en"
  }'
```

### Avatar Generation
```bash
curl -X POST https://your-project.supabase.co/functions/v1/avatar-generation \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "hero_id": "valid-uuid",
    "prompt": "A magical hero with a kind heart",
    "size": "1024x1024",
    "quality": "high"
  }'
```

### Scene Illustration (Fixed)
```bash
curl -X POST https://your-project.supabase.co/functions/v1/scene-illustration \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "valid-uuid",
    "hero_id": "valid-uuid",
    "scenes": [{
      "scene_number": 1,
      "text_segment": "Once upon a time...",
      "illustration_prompt": "A magical forest scene",
      "timestamp_seconds": 0,
      "emotion": "peaceful",
      "importance": "key"
    }],
    "process_async": false
  }'
```

### Audio Synthesis
```bash
curl -X POST https://your-project.supabase.co/functions/v1/audio-synthesis \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "story_id": "valid-uuid",
    "text": "Story content here...",
    "voice": "coral",
    "language": "en"
  }'
```

## Deployment Steps

1. **Deploy the fixed scene-illustration function**:
```bash
cd infinite-stories-backend
npx supabase functions deploy scene-illustration
```

2. **Monitor logs for errors**:
```bash
npx supabase functions logs scene-illustration --tail
```

3. **Test with your iOS app**:
   - Ensure all parameters are being sent correctly
   - Check response format matches expectations
   - Verify error handling works properly

## Common iOS Integration Errors and Solutions

### Error: "Hero not found or access denied"
**Cause**: hero_id doesn't belong to authenticated user
**Solution**: Ensure hero_id is valid and belongs to the current user

### Error: "Unknown built-in event"
**Cause**: Using 'event' field instead of 'name' for built-in events
**Solution**: Use `data: { "name": "EventName" }` format

### Error: "Unsupported voice"
**Cause**: Voice name not in allowed list
**Solution**: Use one of: coral, nova, fable, alloy, echo, onyx, shimmer

### Error: "Field 'scenes' must have at least 1 items"
**Cause**: Empty scenes array
**Solution**: Ensure at least one scene is provided

### Error: "Too many scenes (maximum 10)"
**Cause**: Trying to process more than 10 scenes at once
**Solution**: Limit batch size or use async processing

## Response Format Validation

Ensure your iOS models match these response formats:

### StoryGenerationResponse
```swift
struct StoryGenerationResponse: Codable {
    let story_id: String
    let title: String
    let content: String
    let estimated_duration: Double
    let word_count: Int
    let scenes: [Scene]
}

struct Scene: Codable {
    let scene_number: Int
    let text_segment: String
    let illustration_prompt: String
    let timestamp_seconds: Double
    let emotion: String
    let importance: String
}
```

### AvatarGenerationResponse
```swift
struct AvatarGenerationResponse: Codable {
    let avatar_url: String
    let generation_id: String
    let revised_prompt: String?
    let file_size_bytes: Int
    let image_size: String
    let quality: String
}
```

### SceneIllustrationResponse
```swift
struct SceneIllustrationResponse: Codable {
    let job_id: String?
    let illustrations: [Illustration]?
    let status: String
    let total_scenes: Int
    let completed_scenes: Int
    let estimated_completion: String?
}

struct Illustration: Codable {
    let scene_number: Int
    let image_url: String
    let generation_id: String
    let status: String
    let error_message: String?
}
```

### AudioSynthesisResponse
```swift
struct AudioSynthesisResponse: Codable {
    let audio_url: String
    let duration_seconds: Double
    let file_size_bytes: Int
    let voice_used: String
    let language: String
}
```

## Contact for Issues

If you encounter any issues after implementing these fixes:
1. Check the edge function logs for detailed error messages
2. Verify all required environment variables are set
3. Ensure your Supabase project has the correct storage buckets created
4. Validate that RLS policies allow the operations

The critical bug in scene-illustration has been fixed. Deploy this change immediately to prevent runtime errors.