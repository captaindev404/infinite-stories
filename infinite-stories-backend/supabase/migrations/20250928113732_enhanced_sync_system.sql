-- Enhanced Sync System for Hybrid SwiftData + Supabase Architecture
-- This migration adds comprehensive sync capabilities, conflict resolution,
-- and event sourcing patterns for reliable offline-first functionality

-- =============================================================================
-- 1. SYNC METADATA TABLES
-- =============================================================================

-- Sync metadata for tracking dual-UUID mapping and sync state
CREATE TABLE sync_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL, -- 'hero', 'story', 'custom_event', 'story_scene', 'story_illustration'
    server_id UUID NOT NULL,   -- Supabase UUID (primary key in entity table)
    client_id UUID NOT NULL,   -- SwiftData UUID (iOS local ID)
    device_id TEXT NOT NULL,   -- Unique device identifier
    sync_version BIGINT NOT NULL DEFAULT 1,
    sync_status TEXT NOT NULL DEFAULT 'pending', -- pending, syncing, synced, conflict, failed
    conflict_resolution TEXT, -- 'client_wins', 'server_wins', 'merged', 'manual'
    last_modified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_synced_at TIMESTAMPTZ,
    sync_attempts INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB, -- Additional sync-related data
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, entity_type, client_id, device_id)
);

-- Delta sync tracking for efficient incremental sync
CREATE TABLE sync_deltas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL, -- Either server_id or client_id
    operation TEXT NOT NULL, -- insert, update, delete, conflict_resolved
    delta_data JSONB NOT NULL, -- Changed fields and their values
    device_id TEXT NOT NULL,
    sequence_number BIGSERIAL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    sync_cursor BIGINT -- For delta sync tracking
);

-- Sync conflicts tracking for resolution
CREATE TABLE sync_conflicts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    client_version JSONB NOT NULL,
    server_version JSONB NOT NULL,
    device_id TEXT NOT NULL,
    resolution_status TEXT DEFAULT 'pending', -- pending, resolved, ignored
    resolution_strategy TEXT, -- auto_merge, client_wins, server_wins, manual
    resolved_data JSONB,
    resolver_user_id UUID, -- Who resolved the conflict
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Device presence tracking for multi-device coordination
CREATE TABLE device_presence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_type TEXT DEFAULT 'ios', -- ios, android, web
    app_version TEXT,
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    online_status BOOLEAN DEFAULT true,
    sync_cursor BIGINT DEFAULT 0,
    capabilities JSONB, -- device-specific capabilities
    push_token TEXT, -- For notifications
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- Real-time sync events for multi-device notifications
CREATE TABLE sync_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    source_device_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- data_change, sync_request, conflict, device_online
    entity_type TEXT,
    entity_id UUID,
    event_data JSONB,
    broadcast_to TEXT[], -- specific device_ids or ['all']
    delivered_to TEXT[] DEFAULT '{}', -- track delivery
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);

-- =============================================================================
-- 2. ADD SYNC METADATA TO EXISTING TABLES
-- =============================================================================

-- Add sync metadata columns to heroes table
ALTER TABLE heroes
ADD COLUMN client_id UUID,
ADD COLUMN sync_status TEXT DEFAULT 'synced',
ADD COLUMN sync_version BIGINT DEFAULT 1,
ADD COLUMN last_synced_at TIMESTAMPTZ,
ADD COLUMN device_id TEXT;

-- Add sync metadata columns to stories table
ALTER TABLE stories
ADD COLUMN client_id UUID,
ADD COLUMN sync_status TEXT DEFAULT 'synced',
ADD COLUMN sync_version BIGINT DEFAULT 1,
ADD COLUMN last_synced_at TIMESTAMPTZ,
ADD COLUMN device_id TEXT;

-- Add sync metadata columns to custom_events table
ALTER TABLE custom_events
ADD COLUMN client_id UUID,
ADD COLUMN sync_status TEXT DEFAULT 'synced',
ADD COLUMN sync_version BIGINT DEFAULT 1,
ADD COLUMN last_synced_at TIMESTAMPTZ,
ADD COLUMN device_id TEXT;

-- Add sync metadata columns to story_scenes table
ALTER TABLE story_scenes
ADD COLUMN client_id UUID,
ADD COLUMN sync_status TEXT DEFAULT 'synced',
ADD COLUMN sync_version BIGINT DEFAULT 1,
ADD COLUMN last_synced_at TIMESTAMPTZ,
ADD COLUMN device_id TEXT;

-- Add sync metadata columns to story_illustrations table
ALTER TABLE story_illustrations
ADD COLUMN client_id UUID,
ADD COLUMN sync_status TEXT DEFAULT 'synced',
ADD COLUMN sync_version BIGINT DEFAULT 1,
ADD COLUMN last_synced_at TIMESTAMPTZ,
ADD COLUMN device_id TEXT;

-- =============================================================================
-- 3. PERFORMANCE INDEXES
-- =============================================================================

-- Sync metadata indexes
CREATE INDEX idx_sync_metadata_user_device ON sync_metadata(user_id, device_id);
CREATE INDEX idx_sync_metadata_client_lookup ON sync_metadata(client_id, device_id);
CREATE INDEX idx_sync_metadata_status ON sync_metadata(sync_status) WHERE sync_status != 'synced';
CREATE INDEX idx_sync_metadata_entity ON sync_metadata(entity_type, server_id);

-- Delta sync indexes
CREATE INDEX idx_sync_deltas_user_sequence ON sync_deltas(user_id, sequence_number DESC);
CREATE INDEX idx_sync_deltas_device_cursor ON sync_deltas(device_id, sync_cursor);
CREATE INDEX idx_sync_deltas_entity ON sync_deltas(entity_type, entity_id);

-- Conflict tracking indexes
CREATE INDEX idx_sync_conflicts_pending ON sync_conflicts(user_id, resolution_status) WHERE resolution_status = 'pending';
CREATE INDEX idx_sync_conflicts_entity ON sync_conflicts(entity_type, entity_id);

-- Device presence indexes
CREATE INDEX idx_device_presence_user ON device_presence(user_id, online_status);
CREATE INDEX idx_device_presence_online ON device_presence(online_status, last_seen_at) WHERE online_status = true;

-- Sync events indexes
CREATE INDEX idx_sync_events_user_type ON sync_events(user_id, event_type, created_at DESC);
CREATE INDEX idx_sync_events_broadcast ON sync_events(broadcast_to) WHERE broadcast_to IS NOT NULL;
CREATE INDEX idx_sync_events_expires ON sync_events(expires_at);

-- Entity table sync indexes
CREATE INDEX idx_heroes_sync_status ON heroes(user_id, sync_status) WHERE sync_status != 'synced';
CREATE INDEX idx_stories_sync_status ON stories(user_id, sync_status) WHERE sync_status != 'synced';
CREATE INDEX idx_custom_events_sync_status ON custom_events(user_id, sync_status) WHERE sync_status != 'synced';

-- =============================================================================
-- 4. SYNC FUNCTIONS
-- =============================================================================

-- Function for optimistic locking with version check
CREATE OR REPLACE FUNCTION update_with_version_check(
    p_table_name TEXT,
    p_id UUID,
    p_user_id UUID,
    p_expected_version BIGINT,
    p_updates JSONB,
    p_device_id TEXT DEFAULT NULL
) RETURNS TABLE(
    success BOOLEAN,
    new_version BIGINT,
    conflict_data JSONB
) AS $$
DECLARE
    current_version BIGINT;
    new_version_num BIGINT;
    update_sql TEXT;
    key_value_pairs TEXT[];
    key TEXT;
    value TEXT;
BEGIN
    -- Get current version with user check for security
    EXECUTE format('SELECT sync_version FROM %I WHERE id = $1 AND user_id = $2', p_table_name)
    INTO current_version
    USING p_id, p_user_id;

    IF current_version IS NULL THEN
        RETURN QUERY SELECT false, 0::BIGINT,
            jsonb_build_object('reason', 'not_found', 'id', p_id);
        RETURN;
    END IF;

    IF current_version != p_expected_version THEN
        -- Conflict detected - return current state
        RETURN QUERY SELECT false, current_version,
            jsonb_build_object('reason', 'version_mismatch',
                             'expected', p_expected_version,
                             'actual', current_version);
        RETURN;
    END IF;

    -- Build dynamic update query
    new_version_num := current_version + 1;

    -- Convert JSONB to SET clause
    FOR key, value IN SELECT * FROM jsonb_each_text(p_updates) LOOP
        key_value_pairs := array_append(key_value_pairs,
            format('%I = %L', key, value));
    END LOOP;

    -- Add sync metadata updates
    key_value_pairs := array_append(key_value_pairs,
        format('sync_version = %L', new_version_num));
    key_value_pairs := array_append(key_value_pairs,
        'updated_at = NOW()');

    IF p_device_id IS NOT NULL THEN
        key_value_pairs := array_append(key_value_pairs,
            format('device_id = %L', p_device_id));
    END IF;

    update_sql := format('UPDATE %I SET %s WHERE id = $1 AND user_id = $2',
                        p_table_name,
                        array_to_string(key_value_pairs, ', '));

    EXECUTE update_sql USING p_id, p_user_id;

    RETURN QUERY SELECT true, new_version_num, NULL::JSONB;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get sync cursor for delta sync
CREATE OR REPLACE FUNCTION get_sync_cursor(
    p_user_id UUID,
    p_device_id TEXT,
    p_entity_types TEXT[] DEFAULT NULL
) RETURNS TABLE(
    entity_type TEXT,
    last_sequence BIGINT,
    pending_changes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        sd.entity_type,
        COALESCE(MAX(sd.sequence_number), 0) as last_sequence,
        COUNT(*)::INTEGER as pending_changes
    FROM sync_deltas sd
    WHERE sd.user_id = p_user_id
      AND (p_entity_types IS NULL OR sd.entity_type = ANY(p_entity_types))
      AND (p_device_id IS NULL OR sd.device_id != p_device_id) -- Exclude own changes
      AND sd.processed_at IS NULL
    GROUP BY sd.entity_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create sync delta entry
CREATE OR REPLACE FUNCTION create_sync_delta(
    p_user_id UUID,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_operation TEXT,
    p_delta_data JSONB,
    p_device_id TEXT
) RETURNS BIGINT AS $$
DECLARE
    new_sequence BIGINT;
BEGIN
    INSERT INTO sync_deltas (
        user_id, entity_type, entity_id, operation,
        delta_data, device_id
    ) VALUES (
        p_user_id, p_entity_type, p_entity_id, p_operation,
        p_delta_data, p_device_id
    ) RETURNING sequence_number INTO new_sequence;

    RETURN new_sequence;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update device presence
CREATE OR REPLACE FUNCTION update_device_presence(
    p_user_id UUID,
    p_device_id TEXT,
    p_device_name TEXT DEFAULT NULL,
    p_device_type TEXT DEFAULT 'ios',
    p_app_version TEXT DEFAULT NULL,
    p_capabilities JSONB DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO device_presence (
        user_id, device_id, device_name, device_type,
        app_version, capabilities, last_seen_at, online_status
    ) VALUES (
        p_user_id, p_device_id, p_device_name, p_device_type,
        p_app_version, p_capabilities, NOW(), true
    )
    ON CONFLICT (user_id, device_id)
    DO UPDATE SET
        device_name = COALESCE(EXCLUDED.device_name, device_presence.device_name),
        device_type = COALESCE(EXCLUDED.device_type, device_presence.device_type),
        app_version = COALESCE(EXCLUDED.app_version, device_presence.app_version),
        capabilities = COALESCE(EXCLUDED.capabilities, device_presence.capabilities),
        last_seen_at = NOW(),
        online_status = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cleanup expired data
CREATE OR REPLACE FUNCTION cleanup_sync_data()
RETURNS void AS $$
BEGIN
    -- Clean up expired sync events
    DELETE FROM sync_events WHERE expires_at < NOW();

    -- Mark devices as offline if not seen in 15 minutes
    UPDATE device_presence
    SET online_status = false
    WHERE last_seen_at < NOW() - INTERVAL '15 minutes'
      AND online_status = true;

    -- Clean up old sync deltas (keep 7 days)
    DELETE FROM sync_deltas
    WHERE created_at < NOW() - INTERVAL '7 days'
      AND processed_at IS NOT NULL;

    -- Clean up resolved conflicts older than 30 days
    DELETE FROM sync_conflicts
    WHERE resolved_at < NOW() - INTERVAL '30 days'
      AND resolution_status = 'resolved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 5. TRIGGERS FOR AUTOMATIC SYNC TRACKING
-- =============================================================================

-- Function to track changes for sync
CREATE OR REPLACE FUNCTION track_sync_changes()
RETURNS TRIGGER AS $$
DECLARE
    operation_type TEXT;
    delta_data JSONB;
    entity_type TEXT;
BEGIN
    -- Determine operation type
    IF TG_OP = 'INSERT' THEN
        operation_type := 'insert';
        delta_data := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        operation_type := 'update';
        delta_data := jsonb_build_object(
            'old', to_jsonb(OLD),
            'new', to_jsonb(NEW)
        );
    ELSIF TG_OP = 'DELETE' THEN
        operation_type := 'delete';
        delta_data := to_jsonb(OLD);
    END IF;

    -- Get entity type from table name
    entity_type := TG_TABLE_NAME;

    -- Create sync delta (use NEW for INSERT/UPDATE, OLD for DELETE)
    IF TG_OP = 'DELETE' THEN
        PERFORM create_sync_delta(
            OLD.user_id,
            entity_type,
            OLD.id,
            operation_type,
            delta_data,
            COALESCE(OLD.device_id, 'server')
        );
        RETURN OLD;
    ELSE
        PERFORM create_sync_delta(
            NEW.user_id,
            entity_type,
            NEW.id,
            operation_type,
            delta_data,
            COALESCE(NEW.device_id, 'server')
        );
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all syncable tables
CREATE TRIGGER heroes_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON heroes
    FOR EACH ROW EXECUTE FUNCTION track_sync_changes();

CREATE TRIGGER stories_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON stories
    FOR EACH ROW EXECUTE FUNCTION track_sync_changes();

CREATE TRIGGER custom_events_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON custom_events
    FOR EACH ROW EXECUTE FUNCTION track_sync_changes();

CREATE TRIGGER story_scenes_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON story_scenes
    FOR EACH ROW EXECUTE FUNCTION track_sync_changes();

CREATE TRIGGER story_illustrations_sync_trigger
    AFTER INSERT OR UPDATE OR DELETE ON story_illustrations
    FOR EACH ROW EXECUTE FUNCTION track_sync_changes();

-- =============================================================================
-- 6. ROW LEVEL SECURITY FOR NEW TABLES
-- =============================================================================

-- Enable RLS on all new sync tables
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_deltas ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_events ENABLE ROW LEVEL SECURITY;

-- Sync metadata policies
CREATE POLICY "Users can manage their own sync metadata"
    ON sync_metadata FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Sync deltas policies
CREATE POLICY "Users can view their own sync deltas"
    ON sync_deltas FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert sync deltas"
    ON sync_deltas FOR INSERT
    WITH CHECK (true); -- Allow system to create deltas

-- Sync conflicts policies
CREATE POLICY "Users can manage their own sync conflicts"
    ON sync_conflicts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Device presence policies
CREATE POLICY "Users can manage their own device presence"
    ON device_presence FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Sync events policies
CREATE POLICY "Users can view their own sync events"
    ON sync_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create sync events"
    ON sync_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- 7. MATERIALIZED VIEWS FOR PERFORMANCE
-- =============================================================================

-- Sync status summary view
CREATE MATERIALIZED VIEW sync_status_summary AS
SELECT
    user_id,
    device_id,
    entity_type,
    COUNT(*) as total_entities,
    COUNT(*) FILTER (WHERE sync_status = 'synced') as synced_count,
    COUNT(*) FILTER (WHERE sync_status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE sync_status = 'conflict') as conflict_count,
    COUNT(*) FILTER (WHERE sync_status = 'failed') as failed_count,
    MAX(last_synced_at) as last_sync_time
FROM sync_metadata
GROUP BY user_id, device_id, entity_type;

-- Index for the materialized view
CREATE UNIQUE INDEX idx_sync_status_summary ON sync_status_summary(user_id, device_id, entity_type);

-- Function to refresh sync status summary
CREATE OR REPLACE FUNCTION refresh_sync_status_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY sync_status_summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 8. INITIAL DATA SETUP
-- =============================================================================

-- Create sync metadata entries for existing data
INSERT INTO sync_metadata (user_id, entity_type, server_id, client_id, device_id, sync_status, sync_version)
SELECT
    user_id,
    'heroes',
    id,
    id, -- Use server ID as initial client ID
    'server', -- Mark as server-originated
    'synced',
    1
FROM heroes;

INSERT INTO sync_metadata (user_id, entity_type, server_id, client_id, device_id, sync_status, sync_version)
SELECT
    user_id,
    'stories',
    id,
    id, -- Use server ID as initial client ID
    'server', -- Mark as server-originated
    'synced',
    1
FROM stories;

INSERT INTO sync_metadata (user_id, entity_type, server_id, client_id, device_id, sync_status, sync_version)
SELECT
    user_id,
    'custom_events',
    id,
    id, -- Use server ID as initial client ID
    'server', -- Mark as server-originated
    'synced',
    1
FROM custom_events;

-- Update existing entities with sync metadata
UPDATE heroes SET
    client_id = id,
    sync_status = 'synced',
    sync_version = 1,
    last_synced_at = NOW(),
    device_id = 'server';

UPDATE stories SET
    client_id = id,
    sync_status = 'synced',
    sync_version = 1,
    last_synced_at = NOW(),
    device_id = 'server';

UPDATE custom_events SET
    client_id = id,
    sync_status = 'synced',
    sync_version = 1,
    last_synced_at = NOW(),
    device_id = 'server';

-- =============================================================================
-- 9. COMMENTS AND DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE sync_metadata IS 'Tracks dual-UUID mapping between iOS SwiftData and Supabase for hybrid sync';
COMMENT ON TABLE sync_deltas IS 'Event log for incremental sync with sequence numbers for ordering';
COMMENT ON TABLE sync_conflicts IS 'Tracks and manages sync conflicts for resolution';
COMMENT ON TABLE device_presence IS 'Multi-device presence and capability tracking';
COMMENT ON TABLE sync_events IS 'Real-time sync events for multi-device coordination';

COMMENT ON FUNCTION update_with_version_check IS 'Optimistic locking for conflict-free updates';
COMMENT ON FUNCTION get_sync_cursor IS 'Returns sync cursor position for delta sync';
COMMENT ON FUNCTION create_sync_delta IS 'Creates delta entries for change tracking';
COMMENT ON FUNCTION cleanup_sync_data IS 'Maintenance function for cleaning up old sync data';