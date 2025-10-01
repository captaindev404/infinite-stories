# Storage Implementation Documentation

## Overview

This document describes the comprehensive storage bucket operations implemented for the InfiniteStories app, enabling seamless file management between the iOS app and Supabase backend.

## Storage Architecture

### Bucket Structure

The system uses four primary storage buckets:

1. **`hero-avatars`** - Hero avatar images
   - File types: PNG, JPEG, JPG, WebP
   - Size limit: 10MB per file
   - Public access: Yes (read-only)
   - Path structure: `{userId}/{heroId}/avatar.png`

2. **`story-audio`** - Generated story audio files
   - File types: MP3, MPEG, MP4, M4A
   - Size limit: 50MB per file
   - Public access: Yes (read-only)
   - Path structure: `{userId}/{storyId}/audio.mp3`

3. **`story-illustrations`** - Scene illustrations
   - File types: PNG, JPEG, JPG, WebP
   - Size limit: 10MB per file
   - Public access: Yes (read-only)
   - Path structure: `{userId}/{storyId}/scene_{sceneNumber}.png`

4. **`story-assets`** - General story assets
   - File types: All allowed
   - Size limit: 50MB per file
   - Public access: Yes (read-only)
   - Path structure: Flexible based on asset type

### Security & Access Control

#### Row Level Security (RLS) Policies

Each bucket has specific RLS policies:

- **Upload**: Only authenticated users can upload to their own directories
- **Read**: Users can read their own files; public can read all files (for sharing)
- **Update**: Users can update their own files (story-assets only)
- **Delete**: Users can delete their own files (story-assets only)

The policies enforce that:
- Users can only modify files in their own user directory
- Files are publicly readable (for sharing stories)
- Directory structure prevents unauthorized access

## iOS Client Implementation

### SupabaseService.swift Updates

Located at: `/Users/captaindev404/Code/Github/infinite-stories/InfiniteStories/InfiniteStories/Services/SupabaseService.swift`

#### Avatar Operations

```swift
// Upload avatar
func uploadAvatar(heroId: UUID, imageData: Data) async throws -> String

// Download avatar
func downloadAvatar(heroId: UUID) async throws -> Data?

// Delete avatar
func deleteAvatar(heroId: UUID) async throws
```

#### Audio Operations

```swift
// Upload story audio
func uploadStoryAudio(storyId: UUID, audioData: Data) async throws -> String

// Download story audio
func downloadStoryAudio(storyId: UUID) async throws -> Data?

// Delete story audio
func deleteStoryAudio(storyId: UUID) async throws
```

#### Scene Illustration Operations

```swift
// Upload scene illustration
func uploadSceneIllustration(storyId: UUID, sceneNumber: Int, imageData: Data) async throws -> String

// Download scene illustration
func downloadSceneIllustration(storyId: UUID, sceneNumber: Int) async throws -> Data?

// Delete scene illustration
func deleteSceneIllustration(storyId: UUID, sceneNumber: Int) async throws
```

#### Helper Functions

```swift
// Get public URL for any storage file
func getPublicURL(bucket: String, path: String) -> String?

// Delete all storage files for a hero
func deleteAllHeroStorage(heroId: UUID) async throws

// Delete all storage files for a story
func deleteAllStoryStorage(storyId: UUID) async throws
```

### Key Features

1. **Automatic URL Generation**: All upload functions return public URLs
2. **Error Handling**: Graceful handling of not-found errors
3. **File Overwriting**: Uses `upsert: true` for updates
4. **Logging**: Comprehensive logging for debugging
5. **Batch Operations**: Helper functions for cleaning up related files

## Edge Functions Implementation

### Avatar Generation

Location: `/Users/captaindev404/Code/Github/infinite-stories/infinite-stories-backend/supabase/functions/avatar-generation/index.ts`

- Automatically uploads generated avatars to `hero-avatars` bucket
- Path: `{userId}/{heroId}/avatar.png`
- Returns public URL in response
- Updates hero record with avatar URL

### Audio Synthesis

Location: `/Users/captaindev404/Code/Github/infinite-stories/infinite-stories-backend/supabase/functions/audio-synthesis/index.ts`

- Automatically uploads synthesized audio to `story-audio` bucket
- Path: `{userId}/{storyId}/audio.mp3`
- Returns public URL in response
- Tracks file size and duration

### Scene Illustration

Location: `/Users/captaindev404/Code/Github/infinite-stories/infinite-stories-backend/supabase/functions/scene-illustration/index.ts`

- Automatically uploads generated illustrations to `story-illustrations` bucket
- Path: `{userId}/{storyId}/scene_{sceneNumber}.png`
- Returns public URLs for each scene
- Supports batch generation

## Database Migration

Location: `/Users/captaindev404/Code/Github/infinite-stories/infinite-stories-backend/supabase/migrations/20250928_storage_buckets.sql`

The migration:
1. Creates all four storage buckets
2. Sets appropriate file type restrictions
3. Configures size limits
4. Establishes RLS policies
5. Makes buckets publicly readable

## Usage Examples

### iOS Client Usage

```swift
// Upload an avatar
let avatarURL = try await SupabaseService.shared.uploadAvatar(
    heroId: hero.id,
    imageData: avatarImageData
)

// Download story audio
if let audioData = try await SupabaseService.shared.downloadStoryAudio(
    storyId: story.id
) {
    // Play audio
}

// Upload scene illustration
let illustrationURL = try await SupabaseService.shared.uploadSceneIllustration(
    storyId: story.id,
    sceneNumber: 1,
    imageData: sceneImageData
)

// Clean up all story files
try await SupabaseService.shared.deleteAllStoryStorage(
    storyId: story.id
)
```

### Edge Function Response

```json
// Avatar Generation Response
{
  "avatar_url": "https://localhost:54321/storage/v1/object/public/hero-avatars/userId/heroId/avatar.png",
  "generation_id": "gen_abc123",
  "file_size_bytes": 245678
}

// Audio Synthesis Response
{
  "audio_url": "https://localhost:54321/storage/v1/object/public/story-audio/userId/storyId/audio.mp3",
  "duration_seconds": 180,
  "file_size_bytes": 2456789
}

// Scene Illustration Response
{
  "illustrations": [
    {
      "scene_number": 1,
      "image_url": "https://localhost:54321/storage/v1/object/public/story-illustrations/userId/storyId/scene_1.png",
      "generation_id": "gen_xyz789"
    }
  ]
}
```

## Testing

### Test Script

Location: `/Users/captaindev404/Code/Github/infinite-stories/infinite-stories-backend/test-storage-operations.sh`

The test script verifies:
1. Bucket existence and accessibility
2. Upload functionality
3. Public URL generation
4. RLS policy enforcement

### Running Tests

```bash
cd infinite-stories-backend
./test-storage-operations.sh
```

## File Naming Conventions

### Consistency Rules

1. **User Isolation**: All files start with `{userId}/`
2. **Resource Grouping**: Second level is resource ID (`{heroId}/` or `{storyId}/`)
3. **Fixed Names**: Final filename is standardized:
   - Avatars: `avatar.png`
   - Audio: `audio.mp3`
   - Illustrations: `scene_{number}.png`

### Benefits

- Predictable URLs for client-side caching
- Easy file management and cleanup
- Clear ownership structure
- Simplified access control

## Error Handling

### Client-Side

- **404 Not Found**: Returns `nil` for optional downloads
- **Upload Failures**: Throws `SupabaseError` with details
- **Network Errors**: Wrapped in `SupabaseError.networkError`
- **Auth Errors**: Throws `SupabaseError.authenticationError`

### Server-Side

- **Storage Failures**: Logged with request ID
- **Fallback**: Returns error response with details
- **Retry Logic**: Not implemented (future enhancement)

## Performance Considerations

### Caching

- Files served with 24-hour cache headers
- Public URLs can be cached client-side
- Consider CDN integration for production

### File Sizes

- Avatar images: 1024x1024 PNG (~500KB-2MB)
- Audio files: MP3 format (~1-5MB per story)
- Illustrations: 1024x1024 PNG (~500KB-2MB each)

### Optimization Opportunities

1. Image compression before upload
2. Progressive loading for illustrations
3. Audio streaming instead of full download
4. Thumbnail generation for previews

## Security Best Practices

1. **Never expose service role key** in client applications
2. **Validate file types** before upload
3. **Enforce size limits** to prevent abuse
4. **Use HTTPS** for all storage operations
5. **Implement rate limiting** for uploads

## Migration Path

### From Local Storage to Supabase Storage

1. Existing files remain in app's Documents directory
2. New files uploaded to Supabase Storage
3. Gradual migration as files are accessed
4. Fallback to local files if cloud unavailable

### Backward Compatibility

The implementation maintains compatibility by:
- Keeping existing local file operations
- Adding storage operations alongside
- Using URLs that can point to either location
- Graceful degradation if storage unavailable

## Future Enhancements

### Planned Features

1. **Automatic Thumbnails**: Generate preview images
2. **Compression**: Optimize file sizes before upload
3. **Batch Operations**: Upload multiple files efficiently
4. **Progress Tracking**: Show upload/download progress
5. **Offline Queue**: Queue uploads when offline

### Potential Optimizations

1. **CDN Integration**: Use CloudFlare or similar
2. **Image Formats**: Support modern formats (WebP, AVIF)
3. **Adaptive Quality**: Adjust based on network speed
4. **Lazy Loading**: Load illustrations as needed
5. **Background Uploads**: iOS background task integration

## Troubleshooting

### Common Issues

1. **"Bucket not found"**: Run `npx supabase db reset` to apply migrations
2. **"Permission denied"**: Check RLS policies and user authentication
3. **"File too large"**: Respect bucket size limits
4. **"Invalid file type"**: Ensure MIME type matches bucket configuration

### Debug Commands

```bash
# Check bucket configuration
curl -H "apikey: SERVICE_KEY" http://localhost:54321/storage/v1/bucket

# List files in bucket
curl -H "apikey: ANON_KEY" http://localhost:54321/storage/v1/object/list/hero-avatars

# Check storage logs
docker logs supabase_storage_infinite-stories-backend
```

## Conclusion

The storage implementation provides a robust, secure, and scalable solution for managing generated content in the InfiniteStories app. The architecture supports future growth while maintaining simplicity and performance.