# Firestore Database Schema

This document outlines the Firestore collections structure migrated from the Supabase PostgreSQL schema.

## Collections Structure

### 1. users
Main user profile collection.
```javascript
{
  userId: string,           // Firebase Auth UID
  email: string,
  displayName: string,
  photoURL: string,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  metadata: {
    subscription: string,
    preferences: object
  }
}
```

### 2. heroes
Character information for stories.
```javascript
{
  id: string,               // Auto-generated document ID
  userId: string,           // Owner's Firebase Auth UID
  name: string,
  primaryTrait: string,
  secondaryTrait: string,
  appearance: string,
  specialAbility: string,
  avatarPrompt: string,
  avatarUrl: string,
  avatarGenerationId: string,  // GPT-Image generation ID
  visualProfile: object,     // Detailed visual characteristics
  isActive: boolean,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  // Sync metadata
  clientId: string,         // SwiftData UUID
  syncStatus: string,
  syncVersion: number,
  deviceId: string
}
```

### 3. stories
Generated stories collection.
```javascript
{
  id: string,               // Auto-generated document ID
  userId: string,           // Owner's Firebase Auth UID
  heroId: string,           // Reference to heroes collection
  customEventId: string,    // Reference to customEvents collection
  title: string,
  content: string,
  eventType: 'built_in' | 'custom',
  eventData: object,        // Event details and configuration
  audioUrl: string,
  audioDuration: number,    // Duration in seconds
  audioVoice: string,
  language: string,         // Default: 'en'
  estimatedDuration: number,
  wordCount: number,
  generationMetadata: object, // OpenAI API response details
  isFavorite: boolean,
  playCount: number,
  lastPlayedAt: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  // Sync metadata
  clientId: string,
  syncStatus: string,
  syncVersion: number,
  deviceId: string
}
```

#### 3.1. stories/{storyId}/scenes (Subcollection)
Extracted scenes from stories for illustrations.
```javascript
{
  id: string,
  storyId: string,          // Parent story ID
  sceneNumber: number,
  textSegment: string,
  illustrationPrompt: string,
  sanitizedPrompt: string,  // After content filtering
  timestampSeconds: number, // Seconds into audio
  emotion: string,          // joyful, peaceful, exciting, etc.
  importance: string,       // key, major, minor
  createdAt: Timestamp
}
```

#### 3.2. stories/{storyId}/illustrations (Subcollection)
Generated scene images.
```javascript
{
  id: string,
  sceneId: string,          // Reference to scene
  storyId: string,          // Parent story ID
  imageUrl: string,
  generationId: string,     // GPT-Image generation ID
  previousGenerationId: string, // For consistency chaining
  revisedPrompt: string,    // OpenAI's revised prompt
  status: string,           // pending, processing, completed, failed
  errorMessage: string,
  retryCount: number,
  generationMetadata: object,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### 4. customEvents
User-created story events.
```javascript
{
  id: string,
  userId: string,
  title: string,
  description: string,
  promptSeed: string,
  category: string,
  ageRange: string,
  tone: string,
  keywords: array,
  pictogramUrl: string,
  usageCount: number,
  isFavorite: boolean,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  // Sync metadata
  clientId: string,
  syncStatus: string,
  syncVersion: number,
  deviceId: string
}
```

### 5. apiUsage
API usage tracking (backend-managed).
```javascript
{
  id: string,
  userId: string,
  storyId: string,
  functionName: string,
  requestId: string,        // Unique request ID
  modelUsed: string,        // gpt-4o, tts-1-hd, dall-e-3
  tokensUsed: number,
  promptTokens: number,
  completionTokens: number,
  costEstimate: number,
  status: string,           // success, failed, rate_limited
  errorMessage: string,
  responseTimeMs: number,
  metadata: object,
  createdAt: Timestamp
}
```

### 6. rateLimits
Rate limiting per user (backend-managed).
```javascript
{
  userId: string,
  functionName: string,
  windowStart: Timestamp,
  requestCount: number,
  createdAt: Timestamp
}
```

### 7. apiCache
Cache for API responses (backend-managed).
```javascript
{
  cacheKey: string,         // Primary key
  response: object,
  expiresAt: Timestamp,
  hitCount: number,
  lastAccessedAt: Timestamp,
  createdAt: Timestamp
}
```

### 8. generationQueue
Async processing queue.
```javascript
{
  id: string,
  userId: string,
  storyId: string,
  jobType: string,          // story, audio, avatar, illustration, scene_extraction
  jobData: object,
  status: string,           // pending, processing, completed, failed
  priority: number,         // Default: 5
  attempts: number,
  maxAttempts: number,      // Default: 3
  errorMessage: string,
  resultData: object,
  workerId: string,
  startedAt: Timestamp,
  completedAt: Timestamp,
  scheduledFor: Timestamp,
  createdAt: Timestamp
}
```

### 9. imageGenerationChains
Track visual consistency for image generation.
```javascript
{
  id: string,
  heroId: string,
  chainType: string,        // avatar, story_illustrations
  sequenceNumber: number,
  generationId: string,
  prompt: string,
  createdAt: Timestamp
}
```

### 10. syncMetadata
Track dual-UUID mapping and sync state.
```javascript
{
  id: string,
  userId: string,
  entityType: string,       // hero, story, custom_event, etc.
  serverId: string,         // Firestore document ID
  clientId: string,         // SwiftData UUID
  deviceId: string,
  syncVersion: number,
  syncStatus: string,       // pending, syncing, synced, conflict, failed
  conflictResolution: string,
  lastModifiedAt: Timestamp,
  lastSyncedAt: Timestamp,
  syncAttempts: number,
  errorMessage: string,
  metadata: object,
  createdAt: Timestamp
}
```

### 11. syncDeltas
Delta sync tracking for efficient incremental sync.
```javascript
{
  id: string,
  userId: string,
  entityType: string,
  entityId: string,
  operation: string,        // insert, update, delete, conflict_resolved
  deltaData: object,
  deviceId: string,
  sequenceNumber: number,
  processedAt: Timestamp,
  syncCursor: number,
  createdAt: Timestamp
}
```

### 12. syncConflicts
Sync conflicts tracking for resolution.
```javascript
{
  id: string,
  userId: string,
  entityType: string,
  entityId: string,
  clientVersion: object,
  serverVersion: object,
  deviceId: string,
  resolutionStatus: string, // pending, resolved, ignored
  resolutionStrategy: string,
  resolvedData: object,
  resolverUserId: string,
  resolvedAt: Timestamp,
  createdAt: Timestamp
}
```

### 13. devicePresence
Device presence tracking for multi-device coordination.
```javascript
{
  id: string,
  userId: string,
  deviceId: string,
  deviceName: string,
  deviceType: string,       // ios, android, web
  appVersion: string,
  onlineStatus: boolean,
  syncCursor: number,
  capabilities: object,
  pushToken: string,
  lastSeenAt: Timestamp,
  createdAt: Timestamp
}
```

### 14. syncEvents
Real-time sync events for multi-device notifications.
```javascript
{
  id: string,
  userId: string,
  sourceDeviceId: string,
  eventType: string,        // data_change, sync_request, conflict, device_online
  entityType: string,
  entityId: string,
  eventData: object,
  broadcastTo: array,       // specific device_ids or ['all']
  deliveredTo: array,
  expiresAt: Timestamp,
  createdAt: Timestamp
}
```

## Key Design Decisions

### 1. NoSQL Denormalization
- Unlike the relational PostgreSQL schema, some data is denormalized for better query performance
- Subcollections are used for related data (scenes, illustrations) to maintain structure
- User data is embedded where needed to avoid joins

### 2. Sync Architecture
- Dual UUID system maintained (server ID vs client ID)
- Sync metadata stored separately for conflict resolution
- Delta tracking enables efficient incremental sync

### 3. Security Model
- Row-level security implemented through Firestore Security Rules
- User isolation enforced at the rule level
- Backend-only collections protected from client writes

### 4. Indexing Strategy
- Composite indexes created for common query patterns
- Collection group queries enabled for subcollections
- Optimized for user-centric queries

### 5. Data Types Mapping
- PostgreSQL UUID → Firestore document ID (string)
- PostgreSQL TIMESTAMPTZ → Firestore Timestamp
- PostgreSQL JSONB → Firestore map/object
- PostgreSQL arrays → Firestore arrays
- PostgreSQL INTERVAL → number (seconds/milliseconds)

## Migration Notes

1. **Storage References**: Media files (audio, images) are stored in Firebase Storage with URLs stored in Firestore
2. **User Authentication**: Firebase Auth UIDs replace Supabase auth.users references
3. **Triggers**: Cloud Functions replace PostgreSQL triggers for timestamp updates
4. **Functions**: Cloud Functions replace PostgreSQL functions for business logic
5. **Caching**: Application-level caching in Firestore replaces database-level caching