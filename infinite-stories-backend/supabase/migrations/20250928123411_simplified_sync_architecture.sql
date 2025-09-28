-- Simplified Sync Architecture Migration
-- This migration removes the complex sync tables and columns added in the previous migration
-- and replaces them with a simple, maintainable approach using the official Supabase Swift library

-- =============================================================================
-- 1. REMOVE COMPLEX SYNC TABLES
-- =============================================================================

-- Drop triggers first to avoid foreign key issues
DROP TRIGGER IF EXISTS heroes_sync_trigger ON heroes;
DROP TRIGGER IF EXISTS stories_sync_trigger ON stories;
DROP TRIGGER IF EXISTS custom_events_sync_trigger ON custom_events;
DROP TRIGGER IF EXISTS story_scenes_sync_trigger ON story_scenes;
DROP TRIGGER IF EXISTS story_illustrations_sync_trigger ON story_illustrations;

-- Drop sync functions
DROP FUNCTION IF EXISTS track_sync_changes();
DROP FUNCTION IF EXISTS update_with_version_check(TEXT, UUID, UUID, BIGINT, JSONB, TEXT);
DROP FUNCTION IF EXISTS get_sync_cursor(UUID, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS create_sync_delta(UUID, TEXT, UUID, TEXT, JSONB, TEXT);
DROP FUNCTION IF EXISTS update_device_presence(UUID, TEXT, TEXT, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS cleanup_sync_data();
DROP FUNCTION IF EXISTS refresh_sync_status_summary();

-- Drop materialized view
DROP MATERIALIZED VIEW IF EXISTS sync_status_summary;

-- Drop complex sync tables
DROP TABLE IF EXISTS sync_metadata CASCADE;
DROP TABLE IF EXISTS sync_deltas CASCADE;
DROP TABLE IF EXISTS sync_conflicts CASCADE;
DROP TABLE IF EXISTS device_presence CASCADE;
DROP TABLE IF EXISTS sync_events CASCADE;

-- =============================================================================
-- 2. REMOVE COMPLEX SYNC COLUMNS FROM ENTITY TABLES
-- =============================================================================

-- Remove sync metadata columns from heroes table
ALTER TABLE heroes
DROP COLUMN IF EXISTS client_id,
DROP COLUMN IF EXISTS sync_status,
DROP COLUMN IF EXISTS sync_version,
DROP COLUMN IF EXISTS last_synced_at,
DROP COLUMN IF EXISTS device_id;

-- Remove sync metadata columns from stories table
ALTER TABLE stories
DROP COLUMN IF EXISTS client_id,
DROP COLUMN IF EXISTS sync_status,
DROP COLUMN IF EXISTS sync_version,
DROP COLUMN IF EXISTS last_synced_at,
DROP COLUMN IF EXISTS device_id;

-- Remove sync metadata columns from custom_events table
ALTER TABLE custom_events
DROP COLUMN IF EXISTS client_id,
DROP COLUMN IF EXISTS sync_status,
DROP COLUMN IF EXISTS sync_version,
DROP COLUMN IF EXISTS last_synced_at,
DROP COLUMN IF EXISTS device_id;

-- Remove sync metadata columns from story_scenes table
ALTER TABLE story_scenes
DROP COLUMN IF EXISTS client_id,
DROP COLUMN IF EXISTS sync_status,
DROP COLUMN IF EXISTS sync_version,
DROP COLUMN IF EXISTS last_synced_at,
DROP COLUMN IF EXISTS device_id;

-- Remove sync metadata columns from story_illustrations table
ALTER TABLE story_illustrations
DROP COLUMN IF EXISTS client_id,
DROP COLUMN IF EXISTS sync_status,
DROP COLUMN IF EXISTS sync_version,
DROP COLUMN IF EXISTS last_synced_at,
DROP COLUMN IF EXISTS device_id;

-- =============================================================================
-- 3. ADD SIMPLE SYNC TRACKING (OPTIONAL)
-- =============================================================================

-- Simple offline queue for operations that need to be synced when back online
-- This is much simpler than the complex event sourcing we had before
CREATE TABLE IF NOT EXISTS offline_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL, -- 'hero', 'story', 'custom_event'
    entity_id UUID NOT NULL,
    operation TEXT NOT NULL, -- 'insert', 'update', 'delete'
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    synced_at TIMESTAMPTZ,
    error_count INTEGER DEFAULT 0,
    last_error TEXT
);

-- Enable RLS on offline queue
ALTER TABLE offline_queue ENABLE ROW LEVEL SECURITY;

-- RLS policy for offline queue
CREATE POLICY "Users can manage their own offline operations"
    ON offline_queue FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Index for efficient querying
CREATE INDEX idx_offline_queue_user_pending ON offline_queue(user_id, synced_at) WHERE synced_at IS NULL;
CREATE INDEX idx_offline_queue_cleanup ON offline_queue(synced_at, created_at) WHERE synced_at IS NOT NULL;

-- =============================================================================
-- 4. SIMPLE SYNC UTILITIES
-- =============================================================================

-- Function to add operation to offline queue
CREATE OR REPLACE FUNCTION queue_offline_operation(
    p_user_id UUID,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_operation TEXT,
    p_payload JSONB
) RETURNS UUID AS $$
DECLARE
    operation_id UUID;
BEGIN
    INSERT INTO offline_queue (user_id, entity_type, entity_id, operation, payload)
    VALUES (p_user_id, p_entity_type, p_entity_id, p_operation, p_payload)
    RETURNING id INTO operation_id;

    RETURN operation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark operation as synced
CREATE OR REPLACE FUNCTION mark_operation_synced(p_operation_id UUID) RETURNS void AS $$
BEGIN
    UPDATE offline_queue
    SET synced_at = NOW()
    WHERE id = p_operation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to clean up old synced operations
CREATE OR REPLACE FUNCTION cleanup_synced_operations() RETURNS void AS $$
BEGIN
    -- Keep synced operations for 7 days, then delete
    DELETE FROM offline_queue
    WHERE synced_at IS NOT NULL
      AND synced_at < NOW() - INTERVAL '7 days';

    -- Delete failed operations older than 30 days
    DELETE FROM offline_queue
    WHERE error_count > 5
      AND created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. COMMENTS AND DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE offline_queue IS 'Simple queue for offline operations to be synced when back online';
COMMENT ON FUNCTION queue_offline_operation IS 'Add operation to offline sync queue';
COMMENT ON FUNCTION mark_operation_synced IS 'Mark offline operation as successfully synced';
COMMENT ON FUNCTION cleanup_synced_operations IS 'Clean up old synced and failed operations';

-- =============================================================================
-- 6. SETUP AUTOMATIC CLEANUP
-- =============================================================================

-- Run cleanup function daily (requires pg_cron extension in production)
-- For local development, this would be called manually or via a scheduled job