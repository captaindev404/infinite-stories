# Database Documentation

Comprehensive documentation for the InfiniteStories PostgreSQL database schema, including table structures, relationships, indexes, RLS policies, and migration strategies.

## Database Overview

The InfiniteStories database is designed with scalability, security, and performance in mind. It uses PostgreSQL with Row Level Security (RLS) to ensure data isolation and implements comprehensive indexing for optimal query performance.

### Design Principles

1. **Data Isolation**: Every user can only access their own data through RLS policies
2. **Referential Integrity**: Foreign key constraints maintain data consistency
3. **Performance Optimization**: Strategic indexes on frequently queried columns
4. **Audit Trail**: Timestamps and metadata for all records
5. **Scalability**: Partitioning-ready design for large tables

## Schema Diagram

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     users       │────<│     heroes      │────<│    stories      │
│  (auth.users)   │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │                         │
                               │                         ├────<┌──────────────┐
                               │                         │     │story_scenes  │
                               │                         │     └──────────────┘
                               │                         │              │
                               │                         │              ├────<┌───────────────────┐
                               │                         │              │     │story_illustrations│
                               │                         │              │     └───────────────────┘
                               │                         │
                               │                         └────<┌──────────────┐
                               │                               │custom_events │
                               │                               └──────────────┘
                               │
                               └────<┌─────────────────┐
                                     │  hero_gallery   │
                                     └─────────────────┘

Supporting Tables:
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  api_usage   │  │ rate_limits  │  │cache_entries │  │content_flags │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

## Core Tables

### heroes

Stores character information for personalized story generation.

```sql
CREATE TABLE heroes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    primary_trait TEXT NOT NULL,
    secondary_trait TEXT NOT NULL,
    appearance TEXT,
    special_ability TEXT,
    avatar_prompt TEXT,
    avatar_url TEXT,
    avatar_generation_id TEXT, -- DALL-E generation ID for consistency
    visual_profile JSONB, -- Detailed visual characteristics
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,

    -- Indexes
    INDEX idx_heroes_user_id (user_id),
    INDEX idx_heroes_user_active (user_id, is_active),

    -- Constraints
    CONSTRAINT hero_name_length CHECK (LENGTH(name) BETWEEN 1 AND 50),
    CONSTRAINT valid_traits CHECK (primary_trait != secondary_trait)
);
```

**JSONB visual_profile structure:**
```json
{
  "hair_color": "brown",
  "hair_style": "curly",
  "eye_color": "green",
  "skin_tone": "medium",
  "clothing_style": "adventurer",
  "distinctive_features": ["freckles", "glasses"],
  "color_palette": ["blue", "green", "yellow"]
}
```

### stories

Generated story content with comprehensive metadata.

```sql
CREATE TABLE stories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    hero_id UUID REFERENCES heroes(id) ON DELETE SET NULL,
    custom_event_id UUID REFERENCES custom_events(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    event_type TEXT NOT NULL CHECK (event_type IN ('built_in', 'custom')),
    event_data JSONB NOT NULL,
    audio_url TEXT,
    audio_duration INTERVAL,
    audio_voice TEXT,
    language TEXT DEFAULT 'en' CHECK (language IN ('en', 'es', 'fr', 'de', 'it')),
    estimated_duration INTERVAL,
    word_count INTEGER CHECK (word_count > 0),
    generation_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_favorite BOOLEAN DEFAULT false,
    play_count INTEGER DEFAULT 0 CHECK (play_count >= 0),
    last_played_at TIMESTAMPTZ,

    -- Indexes
    INDEX idx_stories_user_created (user_id, created_at DESC),
    INDEX idx_stories_hero (hero_id),
    INDEX idx_stories_favorite (user_id, is_favorite),
    INDEX idx_stories_language (language)
);
```

**JSONB generation_metadata structure:**
```json
{
  "model": "gpt-4o",
  "temperature": 0.8,
  "tokens_used": 1500,
  "processing_time_ms": 2500,
  "scene_count": 4,
  "filter_changes": 3,
  "cache_hit": false,
  "request_id": "req_123"
}
```

### story_scenes

Extracted scenes for illustration generation with synchronization data.

```sql
CREATE TABLE story_scenes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
    scene_number INTEGER NOT NULL CHECK (scene_number > 0),
    text_segment TEXT NOT NULL,
    illustration_prompt TEXT NOT NULL,
    sanitized_prompt TEXT,
    timestamp_seconds DECIMAL NOT NULL CHECK (timestamp_seconds >= 0),
    emotion TEXT CHECK (emotion IN ('joyful', 'peaceful', 'exciting', 'mysterious',
                                     'heartwarming', 'adventurous', 'contemplative')),
    importance TEXT CHECK (importance IN ('key', 'major', 'minor')),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Unique constraint
    UNIQUE(story_id, scene_number),

    -- Indexes
    INDEX idx_scenes_story (story_id),
    INDEX idx_scenes_importance (story_id, importance)
);
```

### story_illustrations

Generated images for story scenes with generation tracking.

```sql
CREATE TABLE story_illustrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scene_id UUID REFERENCES story_scenes(id) ON DELETE CASCADE,
    story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
    image_url TEXT,
    thumbnail_url TEXT,
    generation_id TEXT, -- DALL-E generation ID
    previous_generation_id TEXT, -- For visual consistency chaining
    revised_prompt TEXT, -- OpenAI's revised prompt
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing',
                                                    'completed', 'failed', 'retrying')),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0 CHECK (retry_count >= 0 AND retry_count <= 5),
    generation_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes
    INDEX idx_illustrations_story (story_id),
    INDEX idx_illustrations_status (status),
    INDEX idx_illustrations_scene (scene_id)
);
```

### custom_events

User-created story templates and scenarios.

```sql
CREATE TABLE custom_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    prompt_seed TEXT NOT NULL,
    category TEXT CHECK (category IN ('adventure', 'fantasy', 'science',
                                      'nature', 'friendship', 'mystery')),
    age_range TEXT CHECK (age_range IN ('4-6', '6-8', '8-10', 'all')),
    tone TEXT CHECK (tone IN ('calming', 'exciting', 'educational', 'humorous')),
    keywords TEXT[],
    pictogram_url TEXT,
    usage_count INTEGER DEFAULT 0 CHECK (usage_count >= 0),
    is_favorite BOOLEAN DEFAULT false,
    is_public BOOLEAN DEFAULT false, -- For sharing events
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes
    INDEX idx_events_user (user_id),
    INDEX idx_events_public (is_public, category),
    INDEX idx_events_favorite (user_id, is_favorite)
);
```

### hero_gallery

Collection of hero avatars with generation history.

```sql
CREATE TABLE hero_gallery (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hero_id UUID REFERENCES heroes(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    generation_id TEXT,
    prompt_used TEXT,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes
    INDEX idx_gallery_hero (hero_id),
    INDEX idx_gallery_primary (hero_id, is_primary)
);
```

## Supporting Tables

### api_usage

Comprehensive tracking of API calls for monitoring and billing.

```sql
CREATE TABLE api_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    function_name TEXT NOT NULL,
    request_id TEXT UNIQUE,
    status TEXT CHECK (status IN ('success', 'error', 'rate_limited')),
    response_time_ms INTEGER CHECK (response_time_ms >= 0),
    tokens_used INTEGER CHECK (tokens_used >= 0),
    cost_estimate DECIMAL(10, 6) CHECK (cost_estimate >= 0),
    error_message TEXT,
    error_code TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes for analytics
    INDEX idx_usage_user_created (user_id, created_at DESC),
    INDEX idx_usage_function_created (function_name, created_at DESC),
    INDEX idx_usage_status (status, created_at DESC),
    INDEX idx_usage_request (request_id)
);
```

### rate_limits

Per-user rate limiting with sliding windows.

```sql
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    function_name TEXT NOT NULL,
    request_count INTEGER DEFAULT 1 CHECK (request_count > 0),
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,

    -- Unique constraint for window tracking
    UNIQUE(user_id, function_name, window_start),

    -- Indexes
    INDEX idx_limits_user_function (user_id, function_name),
    INDEX idx_limits_window (window_end),

    -- Constraint
    CONSTRAINT valid_window CHECK (window_end > window_start)
);
```

### cache_entries

Database-backed caching for expensive operations.

```sql
CREATE TABLE cache_entries (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    access_count INTEGER DEFAULT 0 CHECK (access_count >= 0),
    last_accessed_at TIMESTAMPTZ DEFAULT NOW(),
    size_bytes INTEGER CHECK (size_bytes > 0),

    -- Indexes
    INDEX idx_cache_expires (expires_at),
    INDEX idx_cache_accessed (last_accessed_at)
);
```

### content_flags

Content moderation and safety tracking.

```sql
CREATE TABLE content_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_type TEXT CHECK (content_type IN ('story', 'prompt', 'image')),
    content_id UUID NOT NULL,
    flag_type TEXT CHECK (flag_type IN ('violence', 'fear', 'inappropriate',
                                        'isolation', 'medical', 'other')),
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    action_taken TEXT CHECK (action_taken IN ('filtered', 'rejected', 'modified', 'approved')),
    original_content TEXT,
    modified_content TEXT,
    ai_confidence DECIMAL(3, 2) CHECK (ai_confidence >= 0 AND ai_confidence <= 1),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users(id),

    -- Indexes
    INDEX idx_flags_content (content_type, content_id),
    INDEX idx_flags_severity (severity, created_at DESC),
    INDEX idx_flags_unreviewed (reviewed_at NULLS FIRST)
);
```

## Row Level Security (RLS) Policies

### Enable RLS on all tables

```sql
ALTER TABLE heroes ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_scenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_illustrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE hero_gallery ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_flags ENABLE ROW LEVEL SECURITY;
```

### User Data Policies

```sql
-- Heroes: Users can only access their own heroes
CREATE POLICY "Users can view own heroes" ON heroes
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own heroes" ON heroes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own heroes" ON heroes
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own heroes" ON heroes
    FOR DELETE USING (auth.uid() = user_id);

-- Stories: Users can only access their own stories
CREATE POLICY "Users can view own stories" ON stories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own stories" ON stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Custom Events: Users can view public events or their own
CREATE POLICY "Users can view events" ON custom_events
    FOR SELECT USING (auth.uid() = user_id OR is_public = true);

CREATE POLICY "Users can manage own events" ON custom_events
    FOR ALL USING (auth.uid() = user_id);
```

### Service Role Policies

```sql
-- Allow service role full access for system operations
CREATE POLICY "Service role has full access" ON heroes
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role has full access" ON stories
    FOR ALL USING (auth.role() = 'service_role');

-- Continue for all tables...
```

## Database Functions and Triggers

### Updated Timestamp Trigger

```sql
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_heroes_updated_at BEFORE UPDATE ON heroes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stories_updated_at BEFORE UPDATE ON stories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Continue for all tables with updated_at...
```

### Usage Tracking Function

```sql
-- Function to track story plays
CREATE OR REPLACE FUNCTION increment_play_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE stories
    SET
        play_count = play_count + 1,
        last_played_at = NOW()
    WHERE id = NEW.story_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on play events (could be a separate play_events table)
```

### Cache Cleanup Function

```sql
-- Function to clean expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM cache_entries
    WHERE expires_at < NOW();

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Schedule periodic cleanup
SELECT cron.schedule('cleanup-cache', '0 * * * *', 'SELECT cleanup_expired_cache();');
```

## Indexes Strategy

### Primary Indexes

```sql
-- User content access patterns
CREATE INDEX idx_stories_user_recent ON stories(user_id, created_at DESC);
CREATE INDEX idx_heroes_user_active ON heroes(user_id, is_active);

-- Foreign key relationships
CREATE INDEX idx_stories_hero ON stories(hero_id);
CREATE INDEX idx_scenes_story ON story_scenes(story_id);
CREATE INDEX idx_illustrations_scene ON story_illustrations(scene_id);

-- Query optimization
CREATE INDEX idx_stories_favorites ON stories(user_id, is_favorite) WHERE is_favorite = true;
CREATE INDEX idx_events_public ON custom_events(is_public, category) WHERE is_public = true;

-- Time-based queries
CREATE INDEX idx_usage_recent ON api_usage(created_at DESC);
CREATE INDEX idx_cache_expiry ON cache_entries(expires_at);
```

### Composite Indexes

```sql
-- Multi-column indexes for complex queries
CREATE INDEX idx_usage_user_function_time
    ON api_usage(user_id, function_name, created_at DESC);

CREATE INDEX idx_stories_user_hero_created
    ON stories(user_id, hero_id, created_at DESC);

CREATE INDEX idx_flags_type_severity_time
    ON content_flags(content_type, severity, created_at DESC);
```

## Migration Strategy

### Version Control

All migrations are stored in `supabase/migrations/` with timestamp prefixes:

```bash
supabase/migrations/
├── 20250927230845_initial_schema.sql
├── 20250927231030_rls_policies.sql
├── 20250927231500_indexes.sql
├── 20250927232000_functions_triggers.sql
└── 20250927232500_seed_data.sql
```

### Migration Best Practices

```sql
-- Always use transactions for schema changes
BEGIN;

-- Add new column with default
ALTER TABLE stories
ADD COLUMN rating INTEGER DEFAULT 0 CHECK (rating >= 0 AND rating <= 5);

-- Backfill data if needed
UPDATE stories SET rating = 5 WHERE is_favorite = true;

-- Remove default after backfill
ALTER TABLE stories ALTER COLUMN rating DROP DEFAULT;

COMMIT;
```

### Rollback Strategy

```sql
-- Keep rollback scripts for each migration
-- migrations/rollback/20250927230845_initial_schema_rollback.sql

BEGIN;

-- Reverse the migration
DROP TABLE IF EXISTS story_illustrations CASCADE;
DROP TABLE IF EXISTS story_scenes CASCADE;
DROP TABLE IF EXISTS stories CASCADE;
DROP TABLE IF EXISTS custom_events CASCADE;
DROP TABLE IF EXISTS heroes CASCADE;

COMMIT;
```

## Performance Optimization

### Query Optimization

```sql
-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT s.*, h.name as hero_name
FROM stories s
JOIN heroes h ON s.hero_id = h.id
WHERE s.user_id = 'user-uuid'
ORDER BY s.created_at DESC
LIMIT 10;

-- Vacuum and analyze regularly
VACUUM ANALYZE stories;
VACUUM ANALYZE heroes;

-- Update statistics
ANALYZE stories;
```

### Partitioning Strategy

```sql
-- Partition large tables by date
CREATE TABLE api_usage_2024 PARTITION OF api_usage
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE api_usage_2025 PARTITION OF api_usage
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Create indexes on partitions
CREATE INDEX idx_api_usage_2024_user ON api_usage_2024(user_id);
```

### Connection Pooling

```sql
-- Configure connection pool settings
ALTER DATABASE infinitestories SET max_connections = 200;
ALTER DATABASE infinitestories SET shared_buffers = '256MB';
ALTER DATABASE infinitestories SET effective_cache_size = '1GB';
ALTER DATABASE infinitestories SET work_mem = '4MB';
```

## Backup and Recovery

### Backup Strategy

```bash
#!/bin/bash
# Daily backup script

# Full backup
pg_dump $DATABASE_URL --clean --if-exists --no-owner > backup_$(date +%Y%m%d).sql

# Backup specific tables
pg_dump $DATABASE_URL --table=stories --table=heroes > content_backup_$(date +%Y%m%d).sql

# Compress backups
gzip backup_$(date +%Y%m%d).sql
```

### Point-in-Time Recovery

```sql
-- Enable WAL archiving for PITR
ALTER SYSTEM SET wal_level = replica;
ALTER SYSTEM SET archive_mode = on;
ALTER SYSTEM SET archive_command = 'cp %p /backup/wal/%f';
```

## Monitoring Queries

### Health Checks

```sql
-- Database size
SELECT pg_database_size('infinitestories') / 1024 / 1024 as size_mb;

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Active connections
SELECT count(*) as connection_count
FROM pg_stat_activity
WHERE state = 'active';

-- Slow queries
SELECT
    query,
    mean_exec_time,
    calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC
LIMIT 10;
```

### Usage Analytics

```sql
-- Daily active users
SELECT COUNT(DISTINCT user_id) as dau
FROM api_usage
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Popular content
SELECT
    h.name as hero_name,
    COUNT(s.id) as story_count,
    AVG(s.play_count) as avg_plays
FROM heroes h
JOIN stories s ON h.id = s.hero_id
GROUP BY h.id, h.name
ORDER BY story_count DESC
LIMIT 10;

-- API performance
SELECT
    function_name,
    COUNT(*) as calls,
    AVG(response_time_ms) as avg_response,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) as p95_response,
    SUM(cost_estimate) as total_cost
FROM api_usage
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY function_name;
```

## Security Considerations

### Data Encryption

```sql
-- Enable encryption at rest
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt sensitive data
UPDATE heroes
SET avatar_prompt = pgp_sym_encrypt(avatar_prompt, 'encryption_key')
WHERE avatar_prompt IS NOT NULL;

-- Decrypt when needed
SELECT pgp_sym_decrypt(avatar_prompt::bytea, 'encryption_key') as avatar_prompt
FROM heroes;
```

### Audit Logging

```sql
-- Audit log table
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    user_id UUID,
    changed_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit trigger
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(table_name, operation, user_id, changed_data)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        auth.uid(),
        to_jsonb(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

This comprehensive database documentation provides everything needed to understand, maintain, and optimize the InfiniteStories database. For additional information, consult the PostgreSQL documentation or contact the database administration team.