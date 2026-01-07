-- Migration 005: Add agent progress tracking
-- Timestamp: 2025-10-13
-- Description: Add agent_progress table for real-time progress tracking

CREATE TABLE IF NOT EXISTS agent_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_id TEXT NOT NULL,
    task_id INTEGER NOT NULL,
    progress INTEGER NOT NULL CHECK(progress >= 0 AND progress <= 100),
    message TEXT,
    timestamp DATETIME NOT NULL,
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- Index for fast queries by agent
CREATE INDEX IF NOT EXISTS idx_agent_progress_agent
ON agent_progress(agent_id, timestamp DESC);

-- Index for fast queries by task
CREATE INDEX IF NOT EXISTS idx_agent_progress_task
ON agent_progress(task_id, timestamp DESC);

-- Index for cleanup of old records
CREATE INDEX IF NOT EXISTS idx_agent_progress_timestamp
ON agent_progress(timestamp);
