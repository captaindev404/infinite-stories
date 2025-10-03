-- Migration 002: Add task dependencies

CREATE TABLE IF NOT EXISTS task_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_display_id INTEGER NOT NULL,
    depends_on_display_id INTEGER NOT NULL,
    dependency_type TEXT DEFAULT 'blocks',
    created_at TEXT NOT NULL,
    FOREIGN KEY(task_display_id) REFERENCES tasks(display_id) ON DELETE CASCADE,
    FOREIGN KEY(depends_on_display_id) REFERENCES tasks(display_id) ON DELETE CASCADE,
    UNIQUE(task_display_id, depends_on_display_id)
);

CREATE INDEX IF NOT EXISTS idx_dep_task ON task_dependencies(task_display_id);
CREATE INDEX IF NOT EXISTS idx_dep_depends_on ON task_dependencies(depends_on_display_id);
