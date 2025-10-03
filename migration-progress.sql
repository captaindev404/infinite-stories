-- Migration Progress Tracking Database
-- Created for Firebase migration from Supabase

CREATE TABLE IF NOT EXISTS migration_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'backend', 'ios', 'testing', 'infrastructure'
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'blocked', 'failed'
    agent_assigned TEXT, -- Agent handling this task
    priority INTEGER DEFAULT 0, -- Higher number = higher priority
    dependencies TEXT, -- Comma-separated list of task IDs this depends on
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT
);

CREATE TABLE IF NOT EXISTS agent_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    agent_name TEXT NOT NULL,
    activity_type TEXT NOT NULL, -- 'started', 'working', 'completed', 'error', 'message'
    task_id INTEGER,
    details TEXT,
    redis_key TEXT, -- Redis key used for coordination
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_id) REFERENCES migration_tasks(id)
);

CREATE TABLE IF NOT EXISTS migration_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value TEXT NOT NULL,
    category TEXT, -- 'backend', 'ios', 'overall'
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS migration_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    log_level TEXT NOT NULL, -- 'info', 'warning', 'error', 'debug'
    agent_name TEXT,
    task_id INTEGER,
    message TEXT NOT NULL,
    details TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_id) REFERENCES migration_tasks(id)
);

-- Insert initial migration tasks based on the migration plan

-- Infrastructure Tasks
INSERT INTO migration_tasks (task_name, category, priority, description) VALUES
('Setup Firebase project configuration', 'infrastructure', 100, 'Configure Firebase project settings, auth providers, and basic infrastructure'),
('Configure Firestore databases', 'infrastructure', 95, 'Set up Firestore collections and indexes'),
('Configure Firebase Storage', 'infrastructure', 90, 'Set up Storage buckets and security rules'),
('Setup environment variables and secrets', 'infrastructure', 85, 'Configure API keys and secrets in Firebase'),
('Setup Redis for agent communication', 'infrastructure', 100, 'Initialize Redis server for inter-agent messaging');

-- Backend Migration Tasks
INSERT INTO migration_tasks (task_name, category, priority, dependencies, description) VALUES
('Migrate story-generation function', 'backend', 80, '1,2', 'Port story-generation Edge Function to Firebase Cloud Function'),
('Migrate audio-synthesis function', 'backend', 75, '1,2', 'Port audio-synthesis Edge Function to Firebase Cloud Function'),
('Migrate avatar-generation function', 'backend', 70, '1,2,3', 'Port avatar-generation Edge Function to Firebase Cloud Function'),
('Migrate scene-illustration function', 'backend', 65, '1,2,3', 'Port scene-illustration Edge Function to Firebase Cloud Function'),
('Migrate extract-scenes function', 'backend', 60, '1,2', 'Port extract-scenes Edge Function to Firebase Cloud Function'),
('Migrate sync-orchestrator function', 'backend', 55, '1,2', 'Port sync-orchestrator Edge Function to Firebase Cloud Function'),
('Port content safety system', 'backend', 85, '1,2', 'Migrate content filtering and validation to Firebase'),
('Implement Firestore security rules', 'backend', 90, '2', 'Create production-ready security rules'),
('Implement Storage security rules', 'backend', 85, '3', 'Create production-ready storage security rules');

-- iOS App Migration Tasks
INSERT INTO migration_tasks (task_name, category, priority, dependencies, description) VALUES
('Add Firebase iOS SDK', 'ios', 80, '1', 'Install and configure Firebase iOS SDK via SPM'),
('Configure GoogleService-Info.plist', 'ios', 75, '16', 'Set up Firebase configuration file'),
('Implement Firebase Auth', 'ios', 70, '16,17', 'Replace Supabase Auth with Firebase Auth'),
('Update data models for Firestore', 'ios', 65, '16,17', 'Modify models to work with Firestore instead of PostgreSQL'),
('Replace Supabase SDK calls', 'ios', 60, '16,17,18', 'Update all API calls to use Firebase SDK'),
('Update Storage integration', 'ios', 55, '16,17,18', 'Replace Supabase Storage with Firebase Storage'),
('Update AIService for Firebase', 'ios', 70, '6,7,8,9', 'Integrate AIService with Firebase Cloud Functions');

-- Testing Tasks
INSERT INTO migration_tasks (task_name, category, priority, dependencies, description) VALUES
('Test Firebase emulator integration', 'testing', 60, '6,7,8,9,10,11', 'Verify all Cloud Functions work with emulator'),
('Test authentication flows', 'testing', 65, '18,19', 'Verify Firebase Auth integration'),
('Test data persistence', 'testing', 60, '19,20', 'Test Firestore read/write operations'),
('Test media uploads', 'testing', 55, '21', 'Verify Firebase Storage integration'),
('End-to-end testing', 'testing', 50, '24,25,26,27', 'Complete system integration test'),
('Performance testing', 'testing', 45, '28', 'Verify performance meets requirements');

-- Views for monitoring progress
CREATE VIEW IF NOT EXISTS migration_progress_summary AS
SELECT
    category,
    COUNT(*) as total_tasks,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks,
    SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as in_progress_tasks,
    SUM(CASE WHEN status = 'blocked' THEN 1 ELSE 0 END) as blocked_tasks,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_tasks,
    ROUND(CAST(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 2) as completion_percentage
FROM migration_tasks
GROUP BY category;

CREATE VIEW IF NOT EXISTS agent_activity_summary AS
SELECT
    agent_name,
    COUNT(*) as total_activities,
    MAX(timestamp) as last_activity,
    COUNT(DISTINCT task_id) as tasks_worked_on
FROM agent_activities
GROUP BY agent_name;

CREATE VIEW IF NOT EXISTS high_priority_pending_tasks AS
SELECT
    id,
    task_name,
    category,
    priority,
    dependencies,
    description
FROM migration_tasks
WHERE status = 'pending'
    AND (dependencies IS NULL OR dependencies IN (
        SELECT GROUP_CONCAT(id)
        FROM migration_tasks
        WHERE status = 'completed'
    ))
ORDER BY priority DESC;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tasks_status ON migration_tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON migration_tasks(category);
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON migration_tasks(priority);
CREATE INDEX IF NOT EXISTS idx_agent_activities_agent ON agent_activities(agent_name);
CREATE INDEX IF NOT EXISTS idx_agent_activities_task ON agent_activities(task_id);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON migration_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_logs_level ON migration_logs(log_level);
