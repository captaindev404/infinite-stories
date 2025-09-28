-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_net";

-- Heroes table - stores character information for stories
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
    avatar_generation_id TEXT, -- GPT-Image-1 generation ID for consistency
    visual_profile JSONB, -- Detailed visual characteristics
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Custom Events table - user-created story events
CREATE TABLE custom_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    prompt_seed TEXT NOT NULL,
    category TEXT,
    age_range TEXT,
    tone TEXT,
    keywords TEXT[],
    pictogram_url TEXT,
    usage_count INTEGER DEFAULT 0,
    is_favorite BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stories table - generated stories
CREATE TABLE stories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    hero_id UUID REFERENCES heroes(id) ON DELETE SET NULL,
    custom_event_id UUID REFERENCES custom_events(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'built_in' or 'custom'
    event_data JSONB NOT NULL, -- Event details and configuration
    audio_url TEXT,
    audio_duration INTERVAL,
    audio_voice TEXT,
    language TEXT DEFAULT 'en',
    estimated_duration INTERVAL,
    word_count INTEGER,
    generation_metadata JSONB, -- OpenAI API response details
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_favorite BOOLEAN DEFAULT false,
    play_count INTEGER DEFAULT 0,
    last_played_at TIMESTAMPTZ
);

-- Story Scenes table - extracted scenes from stories for illustrations
CREATE TABLE story_scenes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
    scene_number INTEGER NOT NULL,
    text_segment TEXT NOT NULL,
    illustration_prompt TEXT NOT NULL,
    sanitized_prompt TEXT, -- After content filtering
    timestamp_seconds DECIMAL NOT NULL, -- Seconds into audio
    emotion TEXT, -- joyful, peaceful, exciting, mysterious, etc.
    importance TEXT, -- key, major, minor
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(story_id, scene_number)
);

-- Story Illustrations table - generated scene images
CREATE TABLE story_illustrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scene_id UUID REFERENCES story_scenes(id) ON DELETE CASCADE,
    story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
    image_url TEXT,
    generation_id TEXT, -- GPT-Image-1 generation ID
    previous_generation_id TEXT, -- For consistency chaining
    revised_prompt TEXT, -- OpenAI's revised prompt
    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    generation_metadata JSONB, -- Full OpenAI response
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- API Usage Tracking table - monitor OpenAI API usage and costs
CREATE TABLE api_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    story_id UUID REFERENCES stories(id) ON DELETE SET NULL,
    function_name TEXT NOT NULL,
    request_id TEXT UNIQUE,
    model_used TEXT, -- gpt-4o, tts-1-hd, dall-e-3
    tokens_used INTEGER,
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    cost_estimate DECIMAL(10, 6),
    status TEXT, -- success, failed, rate_limited
    error_message TEXT,
    response_time_ms INTEGER,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rate Limits table - track API rate limiting per user
CREATE TABLE rate_limits (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    function_name TEXT NOT NULL,
    window_start TIMESTAMPTZ NOT NULL,
    request_count INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, function_name, window_start)
);

-- API Cache table - cache OpenAI responses
CREATE TABLE api_cache (
    cache_key TEXT PRIMARY KEY,
    response JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    hit_count INTEGER DEFAULT 0,
    last_accessed TIMESTAMPTZ DEFAULT NOW()
);

-- Generation Queue table - async processing queue
CREATE TABLE generation_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL, -- story, audio, avatar, illustration, scene_extraction
    job_data JSONB NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    priority INTEGER DEFAULT 5,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    error_message TEXT,
    result_data JSONB,
    worker_id TEXT, -- Track which worker is processing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    scheduled_for TIMESTAMPTZ DEFAULT NOW() -- For delayed jobs
);

-- Image Generation Chains table - track visual consistency
CREATE TABLE image_generation_chains (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hero_id UUID REFERENCES heroes(id) ON DELETE CASCADE,
    chain_type TEXT NOT NULL, -- avatar, story_illustrations
    sequence_number INTEGER NOT NULL,
    generation_id TEXT NOT NULL,
    prompt TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(hero_id, chain_type, sequence_number)
);

-- Storage buckets for media files
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('story-assets', 'story-assets', true),
    ('hero-avatars', 'hero-avatars', true),
    ('story-audio', 'story-audio', true),
    ('story-illustrations', 'story-illustrations', true)
ON CONFLICT (id) DO NOTHING;

-- Indexes for performance
CREATE INDEX idx_heroes_user_id ON heroes(user_id) WHERE is_active = true;
CREATE INDEX idx_heroes_name ON heroes(name) WHERE is_active = true;

CREATE INDEX idx_stories_user_id ON stories(user_id);
CREATE INDEX idx_stories_hero_id ON stories(hero_id);
CREATE INDEX idx_stories_created_at ON stories(created_at DESC);
CREATE INDEX idx_stories_language ON stories(language);
CREATE INDEX idx_stories_is_favorite ON stories(is_favorite) WHERE is_favorite = true;

CREATE INDEX idx_story_scenes_story_id ON story_scenes(story_id);
CREATE INDEX idx_story_scenes_number ON story_scenes(story_id, scene_number);

CREATE INDEX idx_story_illustrations_scene_id ON story_illustrations(scene_id);
CREATE INDEX idx_story_illustrations_story_id ON story_illustrations(story_id);
CREATE INDEX idx_story_illustrations_status ON story_illustrations(status);

CREATE INDEX idx_api_usage_user_id ON api_usage(user_id);
CREATE INDEX idx_api_usage_created_at ON api_usage(created_at DESC);
CREATE INDEX idx_api_usage_function_name ON api_usage(function_name);
CREATE INDEX idx_api_usage_status ON api_usage(status);

CREATE INDEX idx_rate_limits_user_function ON rate_limits(user_id, function_name, window_start DESC);

CREATE INDEX idx_api_cache_expires ON api_cache(expires_at);
CREATE INDEX idx_api_cache_accessed ON api_cache(last_accessed DESC);

CREATE INDEX idx_generation_queue_status ON generation_queue(status, priority DESC, created_at ASC);
CREATE INDEX idx_generation_queue_user_id ON generation_queue(user_id);
CREATE INDEX idx_generation_queue_scheduled ON generation_queue(scheduled_for) WHERE status = 'pending';

CREATE INDEX idx_image_chains_hero_type ON image_generation_chains(hero_id, chain_type, sequence_number);

-- Custom types for enum values
CREATE TYPE story_event_type AS ENUM ('built_in', 'custom');
CREATE TYPE generation_status AS ENUM ('pending', 'processing', 'completed', 'failed');
CREATE TYPE scene_emotion AS ENUM ('joyful', 'peaceful', 'exciting', 'mysterious', 'heartwarming', 'adventurous', 'contemplative');
CREATE TYPE scene_importance AS ENUM ('key', 'major', 'minor');

-- Add constraints using the custom types
ALTER TABLE stories
    ADD CONSTRAINT stories_event_type_check
    CHECK (event_type IN ('built_in', 'custom'));

ALTER TABLE story_illustrations
    ADD CONSTRAINT illustrations_status_check
    CHECK (status IN ('pending', 'processing', 'completed', 'failed'));

ALTER TABLE generation_queue
    ADD CONSTRAINT queue_status_check
    CHECK (status IN ('pending', 'processing', 'completed', 'failed'));

ALTER TABLE story_scenes
    ADD CONSTRAINT scenes_emotion_check
    CHECK (emotion IN ('joyful', 'peaceful', 'exciting', 'mysterious', 'heartwarming', 'adventurous', 'contemplative'));

ALTER TABLE story_scenes
    ADD CONSTRAINT scenes_importance_check
    CHECK (importance IN ('key', 'major', 'minor'));

-- Functions to automatically update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for auto-updating timestamps
CREATE TRIGGER update_heroes_updated_at BEFORE UPDATE ON heroes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_custom_events_updated_at BEFORE UPDATE ON custom_events FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stories_updated_at BEFORE UPDATE ON stories FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_story_illustrations_updated_at BEFORE UPDATE ON story_illustrations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to clean up expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM api_cache WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to get rate limit status
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_user_id UUID,
    p_function_name TEXT,
    p_limit INTEGER,
    p_window_seconds INTEGER
)
RETURNS TABLE(allowed BOOLEAN, requests_made INTEGER, retry_after INTEGER) AS $$
DECLARE
    window_start TIMESTAMPTZ;
    current_requests INTEGER;
    seconds_until_reset INTEGER;
BEGIN
    -- Calculate the current window start (rounded down to the nearest window)
    window_start := date_trunc('hour', NOW()) +
                   (EXTRACT(epoch FROM (NOW() - date_trunc('hour', NOW())))::INTEGER / p_window_seconds) *
                   (p_window_seconds || ' seconds')::INTERVAL;

    -- Get current request count for this window
    SELECT COALESCE(SUM(request_count), 0) INTO current_requests
    FROM rate_limits
    WHERE user_id = p_user_id
      AND function_name = p_function_name
      AND window_start >= window_start;

    -- Calculate seconds until window resets
    seconds_until_reset := p_window_seconds - EXTRACT(epoch FROM (NOW() - window_start))::INTEGER;

    -- Return result
    IF current_requests >= p_limit THEN
        RETURN QUERY SELECT false, current_requests, seconds_until_reset;
    ELSE
        RETURN QUERY SELECT true, current_requests, 0;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment rate limit counter
CREATE OR REPLACE FUNCTION increment_rate_limit(
    p_user_id UUID,
    p_function_name TEXT,
    p_window_seconds INTEGER
)
RETURNS void AS $$
DECLARE
    window_start TIMESTAMPTZ;
BEGIN
    -- Calculate the current window start
    window_start := date_trunc('hour', NOW()) +
                   (EXTRACT(epoch FROM (NOW() - date_trunc('hour', NOW())))::INTEGER / p_window_seconds) *
                   (p_window_seconds || ' seconds')::INTERVAL;

    -- Insert or update rate limit counter
    INSERT INTO rate_limits (user_id, function_name, window_start, request_count)
    VALUES (p_user_id, p_function_name, window_start, 1)
    ON CONFLICT (user_id, function_name, window_start)
    DO UPDATE SET request_count = rate_limits.request_count + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;