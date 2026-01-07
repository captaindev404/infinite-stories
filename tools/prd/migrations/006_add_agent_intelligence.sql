-- Agent Intelligence: Specializations and Performance Metrics
-- Migration 006: Add agent specializations and metrics tracking

-- Agent specializations table
CREATE TABLE IF NOT EXISTS agent_specializations (
    agent_id TEXT NOT NULL,
    specialization TEXT NOT NULL,
    PRIMARY KEY (agent_id, specialization),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_agent_spec_agent ON agent_specializations(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_spec_spec ON agent_specializations(specialization);

-- Agent performance metrics (computed from task history)
CREATE TABLE IF NOT EXISTS agent_metrics (
    agent_id TEXT PRIMARY KEY,
    total_tasks INTEGER DEFAULT 0,
    completed_tasks INTEGER DEFAULT 0,
    failed_tasks INTEGER DEFAULT 0,
    avg_completion_time_hours REAL DEFAULT 0.0,
    last_updated TEXT NOT NULL,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

-- Insert initial metrics for existing agents
INSERT OR IGNORE INTO agent_metrics (agent_id, total_tasks, completed_tasks, failed_tasks, avg_completion_time_hours, last_updated)
SELECT id, 0, 0, 0, 0.0, datetime('now')
FROM agents;
