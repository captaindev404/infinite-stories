-- Migration 003: Add acceptance criteria

CREATE TABLE IF NOT EXISTS acceptance_criteria (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_display_id INTEGER NOT NULL,
    criterion TEXT NOT NULL,
    completed BOOLEAN DEFAULT 0,
    created_at TEXT NOT NULL,
    completed_at TEXT,
    FOREIGN KEY(task_display_id) REFERENCES tasks(display_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ac_task ON acceptance_criteria(task_display_id);
CREATE INDEX IF NOT EXISTS idx_ac_completed ON acceptance_criteria(completed);
