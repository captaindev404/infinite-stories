-- Fix event_data null constraint violation
-- This migration makes event_data nullable OR provides a default value for existing null values

-- First, update any existing rows that might have null event_data
-- (This shouldn't happen in production, but might exist in development)
UPDATE stories
SET event_data = '{}'::jsonb
WHERE event_data IS NULL;

-- Option 1: Make event_data nullable (more flexible)
ALTER TABLE stories
ALTER COLUMN event_data DROP NOT NULL;

-- Option 2: Keep it NOT NULL but add a default value
-- ALTER TABLE stories
-- ALTER COLUMN event_data SET DEFAULT '{}'::jsonb;

-- Add a comment explaining the column's purpose
COMMENT ON COLUMN stories.event_data IS 'Event details and configuration. Can be empty object {} for stories without specific event data.';

-- Ensure event_type is properly set for all stories
-- If event_type is null, set it to 'built_in' as a safe default
UPDATE stories
SET event_type = 'built_in'
WHERE event_type IS NULL;

-- Add a default value for event_type to prevent future issues
ALTER TABLE stories
ALTER COLUMN event_type SET DEFAULT 'built_in';