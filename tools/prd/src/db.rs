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
                FOREIGN KEY(parent_id) REFERENCES tasks(id),
                FOREIGN KEY(assigned_agent) REFERENCES agents(id)
            );

            CREATE TABLE IF NOT EXISTS agents (
                id TEXT PRIMARY KEY,
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
        let next_display_id: i32 = self
            .conn
            .query_row(
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

    pub fn update_task_duration(&self, task_id: &str, estimated: Option<i32>, actual: Option<i32>) -> Result<()> {
        self.conn.execute(
            "UPDATE tasks SET estimated_duration = ?1, actual_duration = ?2, updated_at = ?3 WHERE id = ?4",
            params![estimated, actual, Utc::now().to_rfc3339(), task_id],
        )?;
        Ok(())
    }

    // Agent operations
    pub fn create_agent(&self, name: String) -> Result<Agent> {
        // Get next display_id
        let next_display_id: i32 = self
            .conn
            .query_row(
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

        let agent = stmt.query_row(params![name], Self::row_to_agent).optional()?;
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

    pub fn update_agent_status(&self, id: &str, status: AgentStatus, current_task_id: Option<&str>) -> Result<()> {
        self.conn.execute(
            "UPDATE agents SET status = ?1, current_task_id = ?2, last_active = ?3 WHERE id = ?4",
            params![status.as_str(), current_task_id, Utc::now().to_rfc3339(), id],
        )?;
        Ok(())
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
        let mut stmt = self.conn.prepare(
            "SELECT status, COUNT(*) as count FROM tasks GROUP BY status"
        )?;

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

        stats.total = stats.pending + stats.in_progress + stats.blocked + stats.review + stats.completed + stats.cancelled;
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
            completed_at: row
                .get::<_, Option<String>>(10)?
                .map(|s| DateTime::parse_from_rfc3339(&s).unwrap().with_timezone(&Utc)),
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
