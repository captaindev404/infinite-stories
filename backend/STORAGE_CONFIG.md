# Firebase Storage Configuration

## Overview
This document describes the Firebase Storage configuration for the InfiniteStories app, migrated from Supabase Storage to Firebase Storage.

## Bucket Structure

### 1. User Avatars
- **Path**: `/users/{userId}/avatar/{filename}`
- **Purpose**: Store user profile pictures
- **Access**:
  - Read: Public (all users can view avatars)
  - Write: Owner only (users can only upload their own avatar)
  - Delete: Owner only
- **File Types**: PNG, JPEG, JPG, WebP
- **Size Limit**: 10MB
- **Example**: `/users/abc123/avatar/profile.jpg`

### 2. Story Audio
- **Path**: `/stories/{storyId}/audio/{filename}`
- **Purpose**: Store generated TTS audio files for stories
- **Access**:
  - Read: Public (anyone can listen to stories)
  - Create: Authenticated users only
  - Update/Delete: Disabled (preserve content integrity)
- **File Types**: MPEG, MP3, MP4, M4A
- **Size Limit**: 50MB
- **Example**: `/stories/story456/audio/narration.mp3`

### 3. Hero Avatars
- **Path**: `/heroes/{heroId}/avatar/{filename}`
- **Purpose**: Store generated character avatars
- **Access**:
  - Read: Public (viewable by all)
  - Create: Authenticated users only
  - Update/Delete: Disabled (maintain visual consistency)
- **File Types**: PNG, JPEG, JPG, WebP
- **Size Limit**: 10MB
- **Example**: `/heroes/hero789/avatar/character.png`

### 4. Story Illustrations
- **Path**: `/stories/{storyId}/scenes/{sceneId}/illustration/{filename}`
- **Purpose**: Store generated scene illustrations
- **Access**:
  - Read: Public
  - Create: Authenticated users only
  - Update/Delete: Disabled (preserve illustrations)
- **File Types**: PNG, JPEG, JPG, WebP
- **Size Limit**: 10MB
- **Example**: `/stories/story456/scenes/scene1/illustration/forest.jpg`

### 5. User Private Content
- **Path**: `/users/{userId}/private/{allPaths=**}`
- **Purpose**: Store user's private files
- **Access**:
  - Read/Write/Delete: Owner only
- **File Types**: All types allowed
- **Size Limit**: 50MB
- **Example**: `/users/abc123/private/notes/draft.txt`

### 6. Temporary Uploads
- **Path**: `/temp/{userId}/{sessionId}/{filename}`
- **Purpose**: Staging area for file processing
- **Access**:
  - Read/Write/Delete: Owner only
- **File Types**: All types allowed
- **Size Limit**: 100MB
- **Lifecycle**: Auto-delete after 24 hours
- **Example**: `/temp/abc123/session789/upload.tmp`

### 7. System Assets
- **Path**: `/system/{allPaths=**}`
- **Purpose**: Store app resources and default assets
- **Access**:
  - Read: Public
  - Write: Admin only (via Admin SDK)
- **File Types**: All types allowed
- **Example**: `/system/defaults/avatar_placeholder.png`

## Security Features

### Authentication Requirements
- Firebase Authentication required for write operations
- User ID verification for owner-specific paths
- JWT token validation

### Content Validation
- File type validation (MIME type checking)
- File size limits enforced
- Path structure validation

### Data Integrity
- Immutable content for generated assets (audio, illustrations)
- Version control through unique filenames
- Audit trail through Cloud Functions

## CORS Configuration

The `cors.json` file configures Cross-Origin Resource Sharing:
- Public GET requests allowed from all origins
- Full access from localhost and Firebase domains
- iOS/Android app support through custom schemes
- Proper headers for resumable uploads

To apply CORS configuration:
```bash
gsutil cors set cors.json gs://YOUR_BUCKET_NAME
```

## Migration from Supabase

### Mapping Table

| Supabase Bucket | Firebase Path | Notes |
|-----------------|---------------|-------|
| `story-audio` | `/stories/{storyId}/audio/` | Organized by story |
| `hero-avatars` | `/heroes/{heroId}/avatar/` | Organized by hero |
| `story-illustrations` | `/stories/{storyId}/scenes/{sceneId}/illustration/` | Nested by scene |
| `story-assets` | `/users/{userId}/private/` | User-specific storage |

### Key Differences
1. **Path Structure**: Firebase uses nested paths instead of flat bucket structure
2. **Security Rules**: Firebase rules are more granular and path-based
3. **Public Access**: Firebase allows public read on specific paths
4. **Immutability**: Generated content is write-once in Firebase

## Integration with Cloud Functions

Cloud Functions should use the Firebase Admin SDK to bypass security rules when necessary:

```javascript
const admin = require('firebase-admin');
const storage = admin.storage();
const bucket = storage.bucket();

// Upload file
async function uploadFile(path, buffer, contentType) {
  const file = bucket.file(path);
  await file.save(buffer, {
    metadata: {
      contentType: contentType,
      cacheControl: 'public, max-age=3600'
    }
  });
  return file.publicUrl();
}

// Get download URL
async function getDownloadURL(path) {
  const file = bucket.file(path);
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: '01-01-2030'
  });
  return url;
}
```

## Testing with Emulator

The Firebase Storage emulator is configured on port 9199:

```bash
# Start emulator
firebase emulators:start --only storage

# Test upload
curl -X POST http://localhost:9199/v0/b/default-bucket/o \
  -H "Content-Type: application/json" \
  -d '{"name": "test.txt", "contentType": "text/plain"}'
```

## Monitoring and Maintenance

### Usage Monitoring
- Track storage usage in Firebase Console
- Monitor bandwidth consumption
- Set up budget alerts

### Cleanup Tasks
- Implement lifecycle rules for temp files
- Archive old content if needed
- Monitor orphaned files

### Performance Optimization
- Use appropriate image formats (WebP for web)
- Implement CDN caching
- Compress audio files appropriately
- Use thumbnail generation for previews

## Deployment Checklist

- [x] Storage rules configured for production
- [x] CORS configuration prepared
- [x] Path structure documented
- [x] Security rules tested
- [ ] Apply CORS to production bucket: `gsutil cors set cors.json gs://YOUR_BUCKET_NAME`
- [ ] Deploy storage rules: `firebase deploy --only storage`
- [ ] Test all access patterns with emulator
- [ ] Migrate existing content from Supabase (if needed)
- [ ] Update iOS app to use Firebase Storage paths
- [ ] Implement Cloud Functions for file operations
- [ ] Set up monitoring and alerts
- [ ] Configure backup strategy

## Important Notes

1. **Default Bucket**: Firebase projects have a default bucket named `{project-id}.appspot.com`
2. **Public URLs**: Public files can be accessed at `https://storage.googleapis.com/{bucket-name}/{path}`
3. **Download URLs**: Use signed URLs for temporary access to private files
4. **iOS Integration**: Use Firebase iOS SDK for seamless integration
5. **Lifecycle Rules**: Configure via Google Cloud Console for advanced lifecycle management