# Firebase Migration Orchestration Plan

## Status
- **Migration Phase**: Infrastructure Setup
- **Progress Tracking**: SQLite database at `migration-progress.db`
- **Agent Coordination**: Redis on localhost:6379 (Docker container `redis-migration`)
- **Start Time**: 2025-10-02T01:32:00Z

## Architecture Overview

### Current State (Supabase)
- **Backend**: `infinite-stories-backend/` with Edge Functions
  - story-generation (GPT-4o integration)
  - audio-synthesis (TTS with gpt-4o-mini-tts)
  - avatar-generation (DALL-E-3 with visual consistency)
  - scene-illustration (batch image generation)
  - extract-scenes (story scene analysis)
  - sync-orchestrator (coordination service)
  - _shared (utilities and helpers)

- **iOS App**: SwiftUI app using Supabase SDK
  - SupabaseConfig.swift (configuration)
  - Direct API calls to Edge Functions
  - PostgreSQL data models
  - Supabase Storage integration

### Target State (Firebase)
- **Backend**: `backend/` with Cloud Functions
  - All Edge Functions ported to Cloud Functions
  - Firestore replacing PostgreSQL
  - Firebase Storage replacing Supabase Storage
  - Firebase Auth replacing Supabase Auth
  - Content safety system ported

- **iOS App**: SwiftUI app using Firebase SDK
  - Firebase SDK integration
  - Firebase Auth implementation
  - Firestore data models
  - Firebase Storage integration
  - Cloud Functions calling via Firebase SDK

## Agent Coordination System

### Redis Communication Pattern

All agents use Redis for coordination following these patterns:

#### Task Queue Pattern
```bash
# Agents pop tasks from queue
RPOP migration:tasks:queue

# Results stored in hash
HSET migration:results:[task_name] "status" "completed"
HSET migration:results:[task_name] "agent" "[agent_name]"
HSET migration:results:[task_name] "timestamp" "[iso_timestamp]"
```

#### Status Tracking Pattern
```bash
# Agents register status
HSET agents:status "[agent_name]" "active"

# Increment counters
INCR agents:total
INCR tasks:completed
```

#### Error Reporting Pattern
```bash
# Report errors
LPUSH migration:errors:list "[agent_name]: [error_message]"
HSET migration:errors:[task_name] "error" "[error_details]"
```

#### Progress Monitoring Pattern
```bash
# Check progress
GET tasks:completed
GET tasks:failed
LLEN migration:errors:list
```

### SQLite Tracking Integration

All agents must log to SQLite:

```bash
# Update task status
sqlite3 migration-progress.db "UPDATE migration_tasks SET status='in_progress', agent_assigned='[agent_name]', started_at=CURRENT_TIMESTAMP WHERE id=[task_id]"

# Log activity
sqlite3 migration-progress.db "INSERT INTO agent_activities (agent_name, activity_type, task_id, details, redis_key) VALUES ('[agent]', '[type]', [id], '[details]', '[redis_key]')"

# Log completion
sqlite3 migration-progress.db "UPDATE migration_tasks SET status='completed', completed_at=CURRENT_TIMESTAMP WHERE id=[task_id]"
```

## Migration Phases

### Phase 1: Infrastructure (CURRENT)
**Status**: In Progress

**Tasks**:
1. ✅ Firebase project configuration
2. ✅ Redis coordination setup
3. ✅ SQLite progress tracking
4. 🔄 Firestore database setup
5. 🔄 Firebase Storage setup
6. 🔄 Environment secrets configuration

**Agents Needed**:
- `firebase-engineer`: Setup Firebase infrastructure
- `general-purpose`: Configuration and coordination

### Phase 2: Backend Migration
**Status**: Pending

**Tasks**:
1. Migrate `story-generation` Edge Function → Cloud Function
2. Migrate `audio-synthesis` Edge Function → Cloud Function
3. Migrate `avatar-generation` Edge Function → Cloud Function
4. Migrate `scene-illustration` Edge Function → Cloud Function
5. Migrate `extract-scenes` Edge Function → Cloud Function
6. Migrate `sync-orchestrator` Edge Function → Cloud Function
7. Port `_shared` utilities to Cloud Functions
8. Implement content safety system
9. Create Firestore security rules
10. Create Storage security rules

**Agents Needed**:
- `firebase-engineer` (multiple instances): Each handling different functions
- `senior-software-architect`: Design patterns and architecture

**Coordination**:
```bash
# Tasks queued in Redis
LPUSH migration:tasks:queue "migrate_story_generation"
LPUSH migration:tasks:queue "migrate_audio_synthesis"
LPUSH migration:tasks:queue "migrate_avatar_generation"
LPUSH migration:tasks:queue "migrate_scene_illustration"
LPUSH migration:tasks:queue "migrate_extract_scenes"
LPUSH migration:tasks:queue "migrate_sync_orchestrator"
```

### Phase 3: iOS App Migration
**Status**: Pending

**Tasks**:
1. Add Firebase iOS SDK via SPM
2. Configure GoogleService-Info.plist
3. Implement Firebase Auth
4. Update data models for Firestore
5. Replace Supabase SDK calls with Firebase
6. Update Storage integration
7. Integrate AIService with Firebase Cloud Functions

**Agents Needed**:
- `ios-engineer` (multiple instances): Different aspects of iOS migration
- `firebase-engineer`: Backend integration support

**Coordination**:
```bash
# Tasks queued in Redis
LPUSH migration:tasks:queue "add_firebase_sdk"
LPUSH migration:tasks:queue "configure_firebase_ios"
LPUSH migration:tasks:queue "implement_firebase_auth"
LPUSH migration:tasks:queue "update_data_models"
LPUSH migration:tasks:queue "replace_supabase_calls"
LPUSH migration:tasks:queue "update_storage"
LPUSH migration:tasks:queue "integrate_aiservice"
```

### Phase 4: Testing & Verification
**Status**: Pending

**Tasks**:
1. Test Firebase emulator integration
2. Test authentication flows
3. Test data persistence
4. Test media uploads/downloads
5. End-to-end testing
6. Performance testing
7. Security audit

**Agents Needed**:
- `qa-test-automation-specialist`: Testing strategy and execution
- `firebase-engineer`: Firebase-specific testing
- `ios-engineer`: iOS app testing

## Agent Launch Strategy

### Parallel Execution Plan

#### Wave 1: Infrastructure Setup (Now)
Launch in parallel:
1. `firebase-engineer` → Setup Firestore
2. `firebase-engineer` → Setup Storage
3. `firebase-engineer` → Configure secrets

Coordination via Redis:
```bash
# Each agent registers
docker exec redis-migration redis-cli HSET agents:status "firebase-infra-1" "active"
docker exec redis-migration redis-cli HSET agents:status "firebase-infra-2" "active"
docker exec redis-migration redis-cli HSET agents:status "firebase-infra-3" "active"
```

#### Wave 2: Backend Migration (After Wave 1)
Launch in parallel:
1. `firebase-engineer` → story-generation migration
2. `firebase-engineer` → audio-synthesis migration
3. `firebase-engineer` → avatar-generation migration
4. `firebase-engineer` → scene-illustration migration
5. `firebase-engineer` → extract-scenes migration
6. `firebase-engineer` → sync-orchestrator migration

Coordination via Redis:
```bash
# Each agent pops task
docker exec redis-migration redis-cli RPOP migration:tasks:queue
# Process and report completion
docker exec redis-migration redis-cli HSET migration:results:[task] "status" "completed"
```

#### Wave 3: iOS Migration (After Wave 2)
Launch in parallel:
1. `ios-engineer` → Firebase SDK integration
2. `ios-engineer` → Auth implementation
3. `ios-engineer` → Data model updates
4. `ios-engineer` → API call replacement

#### Wave 4: Testing (After Wave 3)
Launch sequentially:
1. `qa-test-automation-specialist` → Unit tests
2. `qa-test-automation-specialist` → Integration tests
3. `qa-test-automation-specialist` → E2E tests

## Monitoring Dashboard Commands

### Check Overall Progress
```bash
sqlite3 migration-progress.db "SELECT * FROM migration_progress_summary;"
```

### Check Agent Activity
```bash
sqlite3 migration-progress.db "SELECT * FROM agent_activity_summary;"
```

### Check Redis Queue
```bash
docker exec redis-migration redis-cli LLEN migration:tasks:queue
docker exec redis-migration redis-cli LRANGE migration:tasks:queue 0 -1
```

### Check Active Agents
```bash
docker exec redis-migration redis-cli HGETALL agents:status
```

### Check Task Completion
```bash
docker exec redis-migration redis-cli GET tasks:completed
docker exec redis-migration redis-cli GET tasks:failed
```

### Check Errors
```bash
docker exec redis-migration redis-cli LRANGE migration:errors:list 0 -1
```

### View Recent Logs
```bash
sqlite3 migration-progress.db "SELECT * FROM migration_logs ORDER BY timestamp DESC LIMIT 10;"
```

### Check High Priority Pending Tasks
```bash
sqlite3 migration-progress.db "SELECT * FROM high_priority_pending_tasks LIMIT 5;"
```

## Key Integration Points

### AIService Integration
Reference: `AIService.swift.txt`

Key functions to maintain compatibility:
- `generateStory()` - Must call Firebase Cloud Function
- `generateSpeech()` - TTS via Cloud Function
- `generateAvatar()` - Image generation via Cloud Function
- `generateSceneIllustration()` - Scene images via Cloud Function
- `extractScenesFromStory()` - Scene analysis via Cloud Function

Firebase Cloud Functions must accept same request/response formats:
```typescript
// Example: story-generation Cloud Function
export const storyGeneration = onCall(async (request) => {
  const { hero_id, event, target_duration, language } = request.data;
  // Same logic as Supabase Edge Function
  // Return same response format for iOS compatibility
});
```

### OpenAI Integration
All Cloud Functions must use the same OpenAI configurations:
- Model: `gpt-4o` for story/scene generation
- Model: `gpt-4o-mini-tts` for TTS
- Model: `dall-e-3` for image generation
- Same prompt engineering and safety filters

### Firebase Emulator Testing
All agents must test against Firebase emulator:
```bash
# Check if emulator is running
curl http://localhost:5001
curl http://localhost:8080  # Firestore UI
```

## Success Criteria

### Phase 1: Infrastructure ✓
- [x] Redis running and accessible
- [x] SQLite database created and tracking tasks
- [ ] Firebase project configured
- [ ] Firestore ready
- [ ] Storage ready
- [ ] Secrets configured

### Phase 2: Backend ✓
- [ ] All 6 Cloud Functions deployed
- [ ] Content safety system working
- [ ] Security rules in place
- [ ] Functions tested with emulator

### Phase 3: iOS ✓
- [ ] Firebase SDK integrated
- [ ] Auth working
- [ ] All API calls migrated
- [ ] Storage integration working
- [ ] AIService integrated

### Phase 4: Testing ✓
- [ ] All tests passing
- [ ] Performance acceptable
- [ ] Security audit complete
- [ ] Ready for production

## Next Steps

1. **Launch Infrastructure Agents** (NOW)
   ```bash
   # Launch 3 firebase-engineer agents for infrastructure
   # Agent 1: Firestore setup
   # Agent 2: Storage setup
   # Agent 3: Secrets configuration
   ```

2. **Monitor Progress**
   ```bash
   # Watch Redis queue
   # Check SQLite progress
   # Review agent logs
   ```

3. **Proceed to Backend Migration**
   ```bash
   # Once infrastructure ready
   # Launch backend migration agents
   ```

4. **Continue with iOS Migration**
   ```bash
   # After backend complete
   # Launch iOS migration agents
   ```

5. **Final Testing**
   ```bash
   # Launch QA agents
   # Run comprehensive tests
   ```

## Emergency Procedures

### If Agent Fails
1. Check error in Redis: `LRANGE migration:errors:list 0 -1`
2. Check logs in SQLite
3. Manually complete task or reassign to new agent
4. Update task status in SQLite

### If Redis Fails
1. Restart container: `docker restart redis-migration`
2. Re-initialize keys
3. Resume from SQLite state

### If Migration Stalls
1. Check for blocked tasks with dependencies
2. Review agent status in Redis
3. Manually unblock or reassign tasks
4. Continue with independent tasks

## Reference Files
- Backend: `backend/CLAUDE.md`
- Legacy: `infinite-stories-backend/CLAUDE.md`
- iOS: `AIService.swift.txt`
- Redis Guide: `how-to-communicate-between-agents-using-redis.md`
- Progress DB: `migration-progress.db`
