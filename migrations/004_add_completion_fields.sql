-- Migration 004: Add completion tracking fields
-- Timestamp: 2025-10-13
-- Description: Add fields to track auto-completion from documentation

-- Add new columns to tasks table
ALTER TABLE tasks ADD COLUMN completion_doc_path TEXT;
ALTER TABLE tasks ADD COLUMN auto_completed BOOLEAN DEFAULT FALSE;
ALTER TABLE tasks ADD COLUMN git_commit_hash TEXT;

-- Create index for performance on auto-completed tasks
CREATE INDEX IF NOT EXISTS idx_tasks_auto_completed
ON tasks(auto_completed) WHERE auto_completed = TRUE;
