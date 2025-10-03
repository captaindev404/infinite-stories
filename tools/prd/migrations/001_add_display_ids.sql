-- Migration 001: Add auto-increment display IDs
-- This migration adds human-readable display IDs while preserving UUIDs

-- Step 1: Add display_id columns
ALTER TABLE tasks ADD COLUMN display_id INTEGER;
ALTER TABLE agents ADD COLUMN display_id INTEGER;

-- Step 2: Populate display IDs based on creation order
-- For tasks: assign sequential IDs
UPDATE tasks SET display_id = (
    SELECT COUNT(*) FROM (SELECT 1 FROM tasks t2 WHERE t2.created_at < tasks.created_at OR (t2.created_at = tasks.created_at AND t2.id <= tasks.id))
);

-- For agents: assign sequential IDs
UPDATE agents SET display_id = (
    SELECT COUNT(*) FROM (SELECT 1 FROM agents a2 WHERE a2.created_at < agents.created_at OR (a2.created_at = agents.created_at AND a2.id <= agents.id))
);

-- Step 3: Create unique indexes on display_id
CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_display_id ON tasks(display_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_agents_display_id ON agents(display_id);

-- Step 4: Add epic_name column for task grouping
ALTER TABLE tasks ADD COLUMN epic_name TEXT;
CREATE INDEX IF NOT EXISTS idx_tasks_epic ON tasks(epic_name);
