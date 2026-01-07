use anyhow::Result;
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection, OptionalExtension, Row};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    pub display_id: Option<i32>,
    pub title: String,
    pub description: Option<String>,
    pub status: TaskStatus,
    pub priority: Priority,
    pub parent_id: Option<String>,
    pub assigned_agent: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub estimated_duration: Option<i32>, // in minutes
    pub actual_duration: Option<i32>,    // in minutes
    pub epic_name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TaskStatus {
    Pending,
    InProgress,
    Blocked,
    Review,
    Completed,
    Cancelled,
}

impl TaskStatus {
    pub fn from_str(s: &str) -> Self {
        match s {
            "pending" => TaskStatus::Pending,
            "in_progress" => TaskStatus::InProgress,
            "blocked" => TaskStatus::Blocked,
            "review" => TaskStatus::Review,
            "completed" => TaskStatus::Completed,
            "cancelled" => TaskStatus::Cancelled,
            _ => TaskStatus::Pending,
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            TaskStatus::Pending => "pending",
            TaskStatus::InProgress => "in_progress",
            TaskStatus::Blocked => "blocked",
            TaskStatus::Review => "review",
            TaskStatus::Completed => "completed",
            TaskStatus::Cancelled => "cancelled",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Priority {
    Low,
    Medium,
    High,
    Critical,
}

impl Priority {
    pub fn from_str(s: &str) -> Self {
        match s {
            "low" => Priority::Low,
            "medium" => Priority::Medium,
            "high" => Priority::High,
            "critical" => Priority::Critical,
            _ => Priority::Medium,
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            Priority::Low => "low",
            Priority::Medium => "medium",
            Priority::High => "high",
            Priority::Critical => "critical",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub id: String,
    pub display_id: Option<i32>,
    pub name: String,
    pub status: AgentStatus,
    pub current_task_id: Option<String>,
    pub created_at: DateTime<Utc>,
    pub last_active: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AgentStatus {
    Idle,
    Working,
    Blocked,
    Offline,
}

impl AgentStatus {
    pub fn from_str(s: &str) -> Self {
        match s {
            "idle" => AgentStatus::Idle,
            "working" => AgentStatus::Working,
            "blocked" => AgentStatus::Blocked,
            "offline" => AgentStatus::Offline,
            _ => AgentStatus::Idle,
        }
    }

    pub fn as_str(&self) -> &str {
        match self {
            AgentStatus::Idle => "idle",
            AgentStatus::Working => "working",
            AgentStatus::Blocked => "blocked",
            AgentStatus::Offline => "offline",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskLog {
    pub id: String,
    pub task_id: String,
    pub agent_id: Option<String>,
    pub action: String,
    pub details: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentProgress {
    pub id: i32,
    pub agent_id: String,
    pub task_id: i32,
    pub progress: u8, // 0-100
    pub message: Option<String>,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentMetrics {
    pub total_tasks: i32,
    pub completed_tasks: i32,
    pub failed_tasks: i32,
    pub avg_completion_time_hours: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sprint {
    pub id: i32,
    pub number: i32,
    pub start_date: String, // YYYY-MM-DD format
    pub end_date: String,
    pub goal: Option<String>,
}

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let db = Database { conn };
        db.init_schema()?;
        Ok(db)
    }

    pub fn get_connection(&self) -> &Connection {
        &self.conn
    }

    fn init_schema(&self) -> Result<()> {
        self.conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                display_id INTEGER UNIQUE,
                title TEXT NOT NULL,
                description TEXT,
                status TEXT NOT NULL,
                priority TEXT NOT NULL,
                parent_id TEXT,
                assigned_agent TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                completed_at TEXT,
                estimated_duration INTEGER,
                actual_duration INTEGER,
                epic_name TEXT,
                FOREIGN KEY(parent_id) REFERENCES tasks(id),
                FOREIGN KEY(assigned_agent) REFERENCES agents(id)
            );

            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY,
                display_id INTEGER UNIQUE,
                name TEXT NOT NULL UNIQUE,
                status TEXT NOT NULL,
                current_task_id TEXT,
                created_at TEXT NOT NULL,
                last_active TEXT NOT NULL,
                FOREIGN KEY(current_task_id) REFERENCES tasks(id)
            );

            CREATE TABLE IF NOT EXISTS task_logs (
                id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                agent_id TEXT,
                action TEXT NOT NULL,
                details TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(task_id) REFERENCES tasks(id),
                FOREIGN KEY(agent_id) REFERENCES agents(id)
            );

            CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
            CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_id);
            CREATE INDEX IF NOT EXISTS idx_tasks_agent ON tasks(assigned_agent);
            CREATE INDEX IF NOT EXISTS idx_logs_task ON task_logs(task_id);
            "#,
        )?;

        // For in-memory databases used in tests, also create the agent_progress table
        // This is safe because CREATE TABLE IF NOT EXISTS won't fail if it already exists
        self.conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS agent_progress (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent_id TEXT NOT NULL,
                task_id INTEGER NOT NULL,
                progress INTEGER NOT NULL CHECK(progress >= 0 AND progress <= 100),
                message TEXT,
                timestamp DATETIME NOT NULL,
                FOREIGN KEY (agent_id) REFERENCES agents(id)
            );

            CREATE INDEX IF NOT EXISTS idx_agent_progress_agent ON agent_progress(agent_id, timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_agent_progress_task ON agent_progress(task_id, timestamp DESC);
            CREATE INDEX IF NOT EXISTS idx_agent_progress_timestamp ON agent_progress(timestamp);

            CREATE TABLE IF NOT EXISTS agent_specializations (
                agent_id TEXT NOT NULL,
                specialization TEXT NOT NULL,
                PRIMARY KEY (agent_id, specialization),
                FOREIGN KEY (agent_id) REFERENCES agents(id)
            );

            CREATE TABLE IF NOT EXISTS agent_metrics (
                agent_id TEXT PRIMARY KEY,
                total_tasks INTEGER DEFAULT 0,
                completed_tasks INTEGER DEFAULT 0,
                failed_tasks INTEGER DEFAULT 0,
                avg_completion_time_hours REAL DEFAULT 0.0,
                last_updated TEXT,
                FOREIGN KEY (agent_id) REFERENCES agents(id)
            );

            CREATE TABLE IF NOT EXISTS sprints (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                number INTEGER NOT NULL UNIQUE,
                start_date DATE NOT NULL,
                end_date DATE NOT NULL,
                goal TEXT
            );

            CREATE TABLE IF NOT EXISTS sprint_tasks (
                sprint_id INTEGER NOT NULL,
                task_id INTEGER NOT NULL,
                PRIMARY KEY (sprint_id, task_id),
                FOREIGN KEY (sprint_id) REFERENCES sprints(id),
                FOREIGN KEY (task_id) REFERENCES tasks(display_id)
            );

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
            "#,
        )?;

        Ok(())
    }

    // Task operations
    pub fn create_task(
        &self,
        title: String,
        description: Option<String>,
        priority: Priority,
        parent_id: Option<String>,
        epic_name: Option<String>,
    ) -> Result<Task> {
        // Get next display_id
        let next_display_id: i32 = self.conn.query_row(
            "SELECT COALESCE(MAX(display_id), 0) + 1 FROM tasks",
            [],
            |row| row.get(0),
        )?;

        let task = Task {
            id: Uuid::new_v4().to_string(),
            display_id: Some(next_display_id),
            title,
            description,
            status: TaskStatus::Pending,
            priority,
            parent_id,
            assigned_agent: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            completed_at: None,
            estimated_duration: None,
            actual_duration: None,
            epic_name,
        };

        self.conn.execute(
            "INSERT INTO tasks (id, display_id, title, description, status, priority, parent_id, assigned_agent, created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
            params![
                &task.id,
                &task.display_id,
                &task.title,
                &task.description,
                task.status.as_str(),
                task.priority.as_str(),
                &task.parent_id,
                &task.assigned_agent,
                task.created_at.to_rfc3339(),
                task.updated_at.to_rfc3339(),
                task.completed_at.map(|dt| dt.to_rfc3339()),
                &task.estimated_duration,
                &task.actual_duration,
                &task.epic_name,
            ],
        )?;

        self.log_task_action(&task.id, None, "created", None)?;
        Ok(task)
    }

    pub fn get_task(&self, id: &str) -> Result<Option<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, title, description, status, priority, parent_id, assigned_agent,
                    created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name
             FROM tasks WHERE id = ?1",
        )?;

        let task = stmt.query_row(params![id], Self::row_to_task).optional()?;
        Ok(task)
    }

    pub fn list_tasks(&self, status_filter: Option<TaskStatus>) -> Result<Vec<Task>> {
        let query = if let Some(status) = status_filter {
            format!(
                "SELECT id, display_id, title, description, status, priority, parent_id, assigned_agent,
                        created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name
                 FROM tasks WHERE status = '{}' ORDER BY priority DESC, created_at DESC",
                status.as_str()
            )
        } else {
            "SELECT id, display_id, title, description, status, priority, parent_id, assigned_agent,
                    created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name
             FROM tasks ORDER BY priority DESC, created_at DESC"
                .to_string()
        };

        let mut stmt = self.conn.prepare(&query)?;
        let tasks = stmt
            .query_map([], Self::row_to_task)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(tasks)
    }

    pub fn get_subtasks(&self, parent_id: &str) -> Result<Vec<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, title, description, status, priority, parent_id, assigned_agent,
                    created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name
             FROM tasks WHERE parent_id = ?1 ORDER BY created_at ASC",
        )?;

        let tasks = stmt
            .query_map(params![parent_id], Self::row_to_task)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(tasks)
    }

    pub fn update_task_status(
        &self,
        id: &str,
        status: TaskStatus,
        agent_id: Option<&str>,
    ) -> Result<()> {
        let completed_at = if status == TaskStatus::Completed {
            Some(Utc::now().to_rfc3339())
        } else {
            None
        };

        self.conn.execute(
            "UPDATE tasks SET status = ?1, updated_at = ?2, completed_at = ?3 WHERE id = ?4",
            params![status.as_str(), Utc::now().to_rfc3339(), completed_at, id],
        )?;

        self.log_task_action(
            id,
            agent_id,
            "status_changed",
            Some(&format!("Changed to {}", status.as_str())),
        )?;
        Ok(())
    }

    pub fn assign_task(&self, task_id: &str, agent_id: &str) -> Result<()> {
        self.conn.execute(
            "UPDATE tasks SET assigned_agent = ?1, updated_at = ?2 WHERE id = ?3",
            params![agent_id, Utc::now().to_rfc3339(), task_id],
        )?;

        self.log_task_action(
            task_id,
            Some(agent_id),
            "assigned",
            Some(&format!("Assigned to agent {}", agent_id)),
        )?;
        Ok(())
    }

    pub fn update_task_duration(
        &self,
        task_id: &str,
        estimated: Option<i32>,
        actual: Option<i32>,
    ) -> Result<()> {
        self.conn.execute(
            "UPDATE tasks SET estimated_duration = ?1, actual_duration = ?2, updated_at = ?3 WHERE id = ?4",
            params![estimated, actual, Utc::now().to_rfc3339(), task_id],
        )?;
        Ok(())
    }

    // Agent operations
    pub fn create_agent(&self, name: String) -> Result<Agent> {
        // Get next display_id
        let next_display_id: i32 = self.conn.query_row(
            "SELECT COALESCE(MAX(display_id), 0) + 1 FROM agents",
            [],
            |row| row.get(0),
        )?;

        let agent = Agent {
            id: Uuid::new_v4().to_string(),
            display_id: Some(next_display_id),
            name,
            status: AgentStatus::Idle,
            current_task_id: None,
            created_at: Utc::now(),
            last_active: Utc::now(),
        };

        self.conn.execute(
            "INSERT INTO agents (id, display_id, name, status, current_task_id, created_at, last_active)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                &agent.id,
                &agent.display_id,
                &agent.name,
                agent.status.as_str(),
                &agent.current_task_id,
                agent.created_at.to_rfc3339(),
                agent.last_active.to_rfc3339(),
            ],
        )?;

        Ok(agent)
    }

    pub fn get_agent(&self, id: &str) -> Result<Option<Agent>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, name, status, current_task_id, created_at, last_active
             FROM agents WHERE id = ?1",
        )?;

        let agent = stmt.query_row(params![id], Self::row_to_agent).optional()?;
        Ok(agent)
    }

    pub fn get_agent_by_name(&self, name: &str) -> Result<Option<Agent>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, name, status, current_task_id, created_at, last_active
             FROM agents WHERE name = ?1",
        )?;

        let agent = stmt
            .query_row(params![name], Self::row_to_agent)
            .optional()?;
        Ok(agent)
    }

    pub fn list_agents(&self) -> Result<Vec<Agent>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, name, status, current_task_id, created_at, last_active
             FROM agents ORDER BY name ASC",
        )?;

        let agents = stmt
            .query_map([], Self::row_to_agent)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(agents)
    }

    pub fn update_agent_status(
        &self,
        id: &str,
        status: AgentStatus,
        current_task_id: Option<&str>,
    ) -> Result<()> {
        self.conn.execute(
            "UPDATE agents SET status = ?1, current_task_id = ?2, last_active = ?3 WHERE id = ?4",
            params![
                status.as_str(),
                current_task_id,
                Utc::now().to_rfc3339(),
                id
            ],
        )?;
        Ok(())
    }

    /// Create an agent within an existing transaction
    pub fn create_agent_in_tx(tx: &rusqlite::Transaction, name: String) -> Result<String> {
        // Get next display_id
        let next_display_id: i32 = tx.query_row(
            "SELECT COALESCE(MAX(display_id), 0) + 1 FROM agents",
            [],
            |row| row.get(0),
        )?;

        let agent_id = Uuid::new_v4().to_string();

        tx.execute(
            "INSERT INTO agents (id, display_id, name, status, current_task_id, created_at, last_active)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                &agent_id,
                &next_display_id,
                &name,
                AgentStatus::Idle.as_str(),
                None::<String>,
                Utc::now().to_rfc3339(),
                Utc::now().to_rfc3339(),
            ],
        )?;

        Ok(agent_id)
    }

    // Logging
    pub fn log_task_action(
        &self,
        task_id: &str,
        agent_id: Option<&str>,
        action: &str,
        details: Option<&str>,
    ) -> Result<()> {
        let log = TaskLog {
            id: Uuid::new_v4().to_string(),
            task_id: task_id.to_string(),
            agent_id: agent_id.map(|s| s.to_string()),
            action: action.to_string(),
            details: details.map(|s| s.to_string()),
            created_at: Utc::now(),
        };

        self.conn.execute(
            "INSERT INTO task_logs (id, task_id, agent_id, action, details, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                &log.id,
                &log.task_id,
                &log.agent_id,
                &log.action,
                &log.details,
                log.created_at.to_rfc3339(),
            ],
        )?;

        Ok(())
    }

    pub fn get_task_logs(&self, task_id: &str) -> Result<Vec<TaskLog>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, task_id, agent_id, action, details, created_at
             FROM task_logs WHERE task_id = ?1 ORDER BY created_at DESC",
        )?;

        let logs = stmt
            .query_map(params![task_id], Self::row_to_log)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(logs)
    }

    // Statistics
    pub fn get_stats(&self) -> Result<TaskStats> {
        let mut stmt = self
            .conn
            .prepare("SELECT status, COUNT(*) as count FROM tasks GROUP BY status")?;

        let mut stats = TaskStats::default();
        let rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, i32>(1)?))
        })?;

        for row in rows {
            let (status, count) = row?;
            match status.as_str() {
                "pending" => stats.pending = count,
                "in_progress" => stats.in_progress = count,
                "blocked" => stats.blocked = count,
                "review" => stats.review = count,
                "completed" => stats.completed = count,
                "cancelled" => stats.cancelled = count,
                _ => {}
            }
        }

        stats.total = stats.pending
            + stats.in_progress
            + stats.blocked
            + stats.review
            + stats.completed
            + stats.cancelled;
        Ok(stats)
    }

    // Helper functions
    fn row_to_task(row: &Row) -> rusqlite::Result<Task> {
        Ok(Task {
            id: row.get(0)?,
            display_id: row.get(1)?,
            title: row.get(2)?,
            description: row.get(3)?,
            status: TaskStatus::from_str(&row.get::<_, String>(4)?),
            priority: Priority::from_str(&row.get::<_, String>(5)?),
            parent_id: row.get(6)?,
            assigned_agent: row.get(7)?,
            created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(8)?)
                .unwrap()
                .with_timezone(&Utc),
            updated_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(9)?)
                .unwrap()
                .with_timezone(&Utc),
            completed_at: row.get::<_, Option<String>>(10)?.map(|s| {
                DateTime::parse_from_rfc3339(&s)
                    .unwrap()
                    .with_timezone(&Utc)
            }),
            estimated_duration: row.get(11)?,
            actual_duration: row.get(12)?,
            epic_name: row.get(13)?,
        })
    }

    fn row_to_agent(row: &Row) -> rusqlite::Result<Agent> {
        Ok(Agent {
            id: row.get(0)?,
            display_id: row.get(1)?,
            name: row.get(2)?,
            status: AgentStatus::from_str(&row.get::<_, String>(3)?),
            current_task_id: row.get(4)?,
            created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                .unwrap()
                .with_timezone(&Utc),
            last_active: DateTime::parse_from_rfc3339(&row.get::<_, String>(6)?)
                .unwrap()
                .with_timezone(&Utc),
        })
    }

    fn row_to_log(row: &Row) -> rusqlite::Result<TaskLog> {
        Ok(TaskLog {
            id: row.get(0)?,
            task_id: row.get(1)?,
            agent_id: row.get(2)?,
            action: row.get(3)?,
            details: row.get(4)?,
            created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                .unwrap()
                .with_timezone(&Utc),
        })
    }

    // Progress tracking operations

    /// Report progress for an agent on a task
    /// Progress must be 0-100, agent and task must exist
    pub fn report_progress(
        &self,
        agent_id: &str,
        task_id: i32,
        progress: u8,
        message: Option<String>,
    ) -> Result<()> {
        // Validate progress range
        if progress > 100 {
            return Err(anyhow::anyhow!("Progress must be between 0 and 100"));
        }

        // Validate agent exists
        let agent_exists: bool = self.conn.query_row(
            "SELECT COUNT(*) FROM agents WHERE id = ?1",
            params![agent_id],
            |row| Ok(row.get::<_, i32>(0)? > 0),
        )?;

        if !agent_exists {
            return Err(anyhow::anyhow!("Agent {} does not exist", agent_id));
        }

        // Validate task exists (by display_id)
        let task_exists: bool = self.conn.query_row(
            "SELECT COUNT(*) FROM tasks WHERE display_id = ?1",
            params![task_id],
            |row| Ok(row.get::<_, i32>(0)? > 0),
        )?;

        if !task_exists {
            return Err(anyhow::anyhow!("Task #{} does not exist", task_id));
        }

        // Insert progress record
        self.conn.execute(
            "INSERT INTO agent_progress (agent_id, task_id, progress, message, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                agent_id,
                task_id,
                progress,
                message,
                Utc::now().to_rfc3339(),
            ],
        )?;

        Ok(())
    }

    /// Get the latest progress report for a specific agent
    pub fn get_latest_progress(&self, agent_id: &str) -> Result<Option<AgentProgress>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent_id, task_id, progress, message, timestamp
             FROM agent_progress
             WHERE agent_id = ?1
             ORDER BY timestamp DESC
             LIMIT 1",
        )?;

        let progress = stmt
            .query_row(params![agent_id], Self::row_to_progress)
            .optional()?;
        Ok(progress)
    }

    /// Get all progress reports for all agents (latest for each agent)
    pub fn get_all_progress(&self) -> Result<Vec<AgentProgress>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent_id, task_id, progress, message, timestamp
             FROM agent_progress
             WHERE id IN (
                 SELECT MAX(id)
                 FROM agent_progress
                 GROUP BY agent_id
             )
             ORDER BY timestamp DESC",
        )?;

        let progress_list = stmt
            .query_map([], Self::row_to_progress)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(progress_list)
    }

    /// Get all progress reports for a specific task
    pub fn get_task_progress(&self, task_id: i32) -> Result<Vec<AgentProgress>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, agent_id, task_id, progress, message, timestamp
             FROM agent_progress
             WHERE task_id = ?1
             ORDER BY timestamp DESC",
        )?;

        let progress_list = stmt
            .query_map(params![task_id], Self::row_to_progress)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(progress_list)
    }

    /// Cleanup old progress records older than specified days
    /// Returns the number of records deleted
    pub fn cleanup_old_progress(&self, days: i64) -> Result<usize> {
        let cutoff_time = Utc::now() - chrono::Duration::days(days);
        let deleted = self.conn.execute(
            "DELETE FROM agent_progress WHERE timestamp < ?1",
            params![cutoff_time.to_rfc3339()],
        )?;
        Ok(deleted)
    }

    fn row_to_progress(row: &Row) -> rusqlite::Result<AgentProgress> {
        Ok(AgentProgress {
            id: row.get(0)?,
            agent_id: row.get(1)?,
            task_id: row.get(2)?,
            progress: row.get(3)?,
            message: row.get(4)?,
            timestamp: DateTime::parse_from_rfc3339(&row.get::<_, String>(5)?)
                .unwrap()
                .with_timezone(&Utc),
        })
    }

    // Agent specialization methods
    pub fn add_agent_specialization(&self, agent_id: &str, spec: &str) -> Result<()> {
        self.conn.execute(
            "INSERT OR IGNORE INTO agent_specializations (agent_id, specialization) VALUES (?, ?)",
            params![agent_id, spec],
        )?;
        self.update_agent_metrics(agent_id)?;
        Ok(())
    }

    pub fn remove_agent_specialization(&self, agent_id: &str, spec: &str) -> Result<()> {
        self.conn.execute(
            "DELETE FROM agent_specializations WHERE agent_id = ? AND specialization = ?",
            params![agent_id, spec],
        )?;
        Ok(())
    }

    pub fn get_agent_specializations(&self, agent_id: &str) -> Result<Vec<String>> {
        let mut stmt = self.conn.prepare(
            "SELECT specialization FROM agent_specializations WHERE agent_id = ? ORDER BY specialization"
        )?;

        let specs = stmt
            .query_map(params![agent_id], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;

        Ok(specs)
    }

    // Agent metrics methods
    pub fn get_agent_metrics(&self, agent_id: &str) -> Result<AgentMetrics> {
        let metrics = self
            .conn
            .query_row(
                "SELECT total_tasks, completed_tasks, failed_tasks, avg_completion_time_hours
             FROM agent_metrics WHERE agent_id = ?",
                params![agent_id],
                |row| -> rusqlite::Result<AgentMetrics> {
                    Ok(AgentMetrics {
                        total_tasks: row.get(0)?,
                        completed_tasks: row.get(1)?,
                        failed_tasks: row.get(2)?,
                        avg_completion_time_hours: row.get(3)?,
                    })
                },
            )
            .or_else(|_: rusqlite::Error| -> Result<AgentMetrics> {
                // Return default if not found
                Ok(AgentMetrics {
                    total_tasks: 0,
                    completed_tasks: 0,
                    failed_tasks: 0,
                    avg_completion_time_hours: 0.0,
                })
            })?;

        Ok(metrics)
    }

    pub fn update_agent_metrics(&self, agent_id: &str) -> Result<()> {
        // Recalculate from task history
        let total: i32 = self
            .conn
            .query_row(
                "SELECT COUNT(*) FROM tasks WHERE assigned_agent = ?",
                params![agent_id],
                |row| row.get(0),
            )
            .unwrap_or(0);

        let completed: i32 = self
            .conn
            .query_row(
                "SELECT COUNT(*) FROM tasks WHERE assigned_agent = ? AND status = 'completed'",
                params![agent_id],
                |row| row.get(0),
            )
            .unwrap_or(0);

        let failed: i32 = self
            .conn
            .query_row(
                "SELECT COUNT(*) FROM tasks WHERE assigned_agent = ? AND status = 'cancelled'",
                params![agent_id],
                |row| row.get(0),
            )
            .unwrap_or(0);

        // Calculate average completion time for completed tasks
        let avg_time: f64 = self
            .conn
            .query_row(
                "SELECT AVG(actual_duration) FROM tasks
             WHERE assigned_agent = ? AND status = 'completed' AND actual_duration IS NOT NULL",
                params![agent_id],
                |row| row.get(0),
            )
            .unwrap_or(0.0);

        // Convert minutes to hours
        let avg_hours = avg_time / 60.0;

        self.conn.execute(
            "INSERT OR REPLACE INTO agent_metrics (agent_id, total_tasks, completed_tasks, failed_tasks, avg_completion_time_hours, last_updated)
             VALUES (?, ?, ?, ?, ?, ?)",
            params![agent_id, total, completed, failed, avg_hours, Utc::now().to_rfc3339()],
        )?;

        Ok(())
    }

    pub fn get_all_agents(&self) -> Result<Vec<Agent>> {
        self.list_agents()
    }

    // Sprint operations

    /// Get all sprints ordered by number
    pub fn get_all_sprints(&self) -> Result<Vec<Sprint>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, number, start_date, end_date, goal FROM sprints ORDER BY number",
        )?;

        let sprints = stmt
            .query_map([], |row| {
                Ok(Sprint {
                    id: row.get(0)?,
                    number: row.get(1)?,
                    start_date: row.get(2)?,
                    end_date: row.get(3)?,
                    goal: row.get(4)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(sprints)
    }

    /// Get all tasks associated with a sprint (by display_id)
    pub fn get_sprint_tasks(&self, sprint_id: i32) -> Result<Vec<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT t.id, t.display_id, t.title, t.description, t.status, t.priority,
                    t.parent_id, t.assigned_agent, t.created_at, t.updated_at, t.completed_at,
                    t.estimated_duration, t.actual_duration, t.epic_name
             FROM tasks t
             JOIN sprint_tasks st ON t.display_id = st.task_id
             WHERE st.sprint_id = ?1
             ORDER BY t.created_at ASC",
        )?;

        let tasks = stmt
            .query_map(params![sprint_id], Self::row_to_task)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(tasks)
    }

    /// Get all tasks (useful for sprint inference and burndown)
    pub fn get_all_tasks(&self) -> Result<Vec<Task>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, title, description, status, priority, parent_id, assigned_agent,
                    created_at, updated_at, completed_at, estimated_duration, actual_duration, epic_name
             FROM tasks ORDER BY created_at ASC"
        )?;

        let tasks = stmt
            .query_map([], Self::row_to_task)?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(tasks)
    }

    /// Create a new sprint
    pub fn create_sprint(
        &self,
        number: i32,
        start_date: String,
        end_date: String,
        goal: Option<String>,
    ) -> Result<Sprint> {
        self.conn.execute(
            "INSERT INTO sprints (number, start_date, end_date, goal) VALUES (?1, ?2, ?3, ?4)",
            params![number, start_date, end_date, goal],
        )?;

        let id = self.conn.last_insert_rowid() as i32;

        Ok(Sprint {
            id,
            number,
            start_date,
            end_date,
            goal,
        })
    }

    /// Assign a task to a sprint (by display_id)
    pub fn assign_task_to_sprint(&self, sprint_id: i32, task_display_id: i32) -> Result<()> {
        self.conn.execute(
            "INSERT OR IGNORE INTO sprint_tasks (sprint_id, task_id) VALUES (?1, ?2)",
            params![sprint_id, task_display_id],
        )?;
        Ok(())
    }
}

#[derive(Debug, Default, Serialize)]
pub struct TaskStats {
    pub total: i32,
    pub pending: i32,
    pub in_progress: i32,
    pub blocked: i32,
    pub review: i32,
    pub completed: i32,
    pub cancelled: i32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_report_progress_valid() -> Result<()> {
        let db = Database::new(":memory:")?;

        // Create test agent
        let agent = db.create_agent("test-agent".to_string())?;

        // Create test task
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Report progress
        db.report_progress(
            &agent.id,
            task_display_id,
            50,
            Some("Half done".to_string()),
        )?;

        // Verify progress was recorded
        let latest = db.get_latest_progress(&agent.id)?;
        assert!(latest.is_some());
        let progress = latest.unwrap();
        assert_eq!(progress.progress, 50);
        assert_eq!(progress.message, Some("Half done".to_string()));

        Ok(())
    }

    #[test]
    fn test_report_progress_invalid_range() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Try to report progress > 100
        let result = db.report_progress(&agent.id, task_display_id, 101, None);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("must be between 0 and 100"));

        Ok(())
    }

    #[test]
    fn test_report_progress_nonexistent_agent() -> Result<()> {
        let db = Database::new(":memory:")?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Try to report progress for nonexistent agent
        let result = db.report_progress("fake-uuid", task_display_id, 50, None);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("does not exist"));

        Ok(())
    }

    #[test]
    fn test_report_progress_nonexistent_task() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;

        // Try to report progress for nonexistent task
        let result = db.report_progress(&agent.id, 999, 50, None);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("does not exist"));

        Ok(())
    }

    #[test]
    fn test_get_latest_progress() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Report multiple progress updates
        db.report_progress(&agent.id, task_display_id, 25, Some("Started".to_string()))?;
        std::thread::sleep(std::time::Duration::from_millis(10));
        db.report_progress(
            &agent.id,
            task_display_id,
            50,
            Some("Half done".to_string()),
        )?;
        std::thread::sleep(std::time::Duration::from_millis(10));
        db.report_progress(
            &agent.id,
            task_display_id,
            75,
            Some("Almost done".to_string()),
        )?;

        // Get latest progress
        let latest = db.get_latest_progress(&agent.id)?;
        assert!(latest.is_some());
        let progress = latest.unwrap();
        assert_eq!(progress.progress, 75);
        assert_eq!(progress.message, Some("Almost done".to_string()));

        Ok(())
    }

    #[test]
    fn test_get_all_progress() -> Result<()> {
        let db = Database::new(":memory:")?;

        // Create multiple agents and tasks
        let agent1 = db.create_agent("agent-1".to_string())?;
        let agent2 = db.create_agent("agent-2".to_string())?;
        let task1 = db.create_task("Task 1".to_string(), None, Priority::Medium, None, None)?;
        let task2 = db.create_task("Task 2".to_string(), None, Priority::Medium, None, None)?;

        // Report progress for both agents
        db.report_progress(&agent1.id, task1.display_id.unwrap(), 30, None)?;
        db.report_progress(&agent2.id, task2.display_id.unwrap(), 60, None)?;

        // Get all progress
        let all_progress = db.get_all_progress()?;
        assert_eq!(all_progress.len(), 2);

        Ok(())
    }

    #[test]
    fn test_get_task_progress() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent1 = db.create_agent("agent-1".to_string())?;
        let agent2 = db.create_agent("agent-2".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Report progress from multiple agents on same task
        db.report_progress(&agent1.id, task_display_id, 30, Some("Agent 1".to_string()))?;
        db.report_progress(&agent2.id, task_display_id, 60, Some("Agent 2".to_string()))?;
        db.report_progress(
            &agent1.id,
            task_display_id,
            90,
            Some("Agent 1 again".to_string()),
        )?;

        // Get task progress
        let task_progress = db.get_task_progress(task_display_id)?;
        assert_eq!(task_progress.len(), 3);

        Ok(())
    }

    #[test]
    fn test_cleanup_old_progress() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Insert old progress (simulate by direct SQL with past timestamp)
        let old_timestamp = (Utc::now() - chrono::Duration::days(10)).to_rfc3339();
        db.get_connection().execute(
            "INSERT INTO agent_progress (agent_id, task_id, progress, message, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                &agent.id,
                task_display_id,
                50,
                None::<String>,
                old_timestamp
            ],
        )?;

        // Insert recent progress
        db.report_progress(&agent.id, task_display_id, 100, None)?;

        // Cleanup old progress (older than 7 days)
        let deleted = db.cleanup_old_progress(7)?;
        assert_eq!(deleted, 1);

        // Verify only recent progress remains
        let all_progress = db.get_task_progress(task_display_id)?;
        assert_eq!(all_progress.len(), 1);
        assert_eq!(all_progress[0].progress, 100);

        Ok(())
    }

    #[test]
    fn test_progress_boundary_values() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Test 0% (valid)
        db.report_progress(&agent.id, task_display_id, 0, Some("Starting".to_string()))?;

        // Test 100% (valid)
        db.report_progress(&agent.id, task_display_id, 100, Some("Done".to_string()))?;

        let latest = db.get_latest_progress(&agent.id)?;
        assert!(latest.is_some());
        assert_eq!(latest.unwrap().progress, 100);

        Ok(())
    }

    #[test]
    fn test_progress_with_no_message() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;
        let task = db.create_task("Test task".to_string(), None, Priority::Medium, None, None)?;
        let task_display_id = task.display_id.unwrap();

        // Report progress without message
        db.report_progress(&agent.id, task_display_id, 50, None)?;

        let latest = db.get_latest_progress(&agent.id)?;
        assert!(latest.is_some());
        let progress = latest.unwrap();
        assert_eq!(progress.progress, 50);
        assert_eq!(progress.message, None);

        Ok(())
    }
}
