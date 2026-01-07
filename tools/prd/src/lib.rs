pub mod dashboard;
pub mod db;
pub mod errors;
pub mod git;
pub mod hooks;
pub mod notifications;
pub mod resolver;
pub mod suggestions;
pub mod sync;
pub mod vectors;
pub mod visualization;
pub mod watcher;

pub use db::{
    Agent, AgentMetrics, AgentProgress, AgentStatus, Database, Priority, Task, TaskLog, TaskStats,
    TaskStatus,
};
pub use suggestions::{AgentMatcher, AgentRecommendation};
pub use vectors::{
    ContentIndexer, ContentType, Embedder, EmbeddingRecord, IndexStats, SearchResult, VectorSearch,
    VectorStore, EMBEDDING_DIM,
};

use anyhow::Result;

/// PRD Client for programmatic access
pub struct PRDClient {
    db: Database,
}

impl PRDClient {
    /// Create a new client connected to the specified database
    pub fn new(db_path: &str) -> Result<Self> {
        let db = Database::new(db_path)?;
        Ok(PRDClient { db })
    }

    /// Create a new client with the default database path
    pub fn with_default_db() -> Result<Self> {
        Self::new("tools/prd.db")
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
        self.db
            .create_task(title, description, priority, parent_id, epic_name)
    }

    pub fn get_task(&self, id: &str) -> Result<Option<Task>> {
        self.db.get_task(id)
    }

    pub fn list_tasks(&self, status_filter: Option<TaskStatus>) -> Result<Vec<Task>> {
        self.db.list_tasks(status_filter)
    }

    pub fn get_subtasks(&self, parent_id: &str) -> Result<Vec<Task>> {
        self.db.get_subtasks(parent_id)
    }

    pub fn update_task_status(
        &self,
        id: &str,
        status: TaskStatus,
        agent_id: Option<&str>,
    ) -> Result<()> {
        self.db.update_task_status(id, status, agent_id)
    }

    pub fn assign_task(&self, task_id: &str, agent_id: &str) -> Result<()> {
        self.db.assign_task(task_id, agent_id)
    }

    pub fn update_task_duration(
        &self,
        task_id: &str,
        estimated: Option<i32>,
        actual: Option<i32>,
    ) -> Result<()> {
        self.db.update_task_duration(task_id, estimated, actual)
    }

    // Agent operations
    pub fn create_agent(&self, name: String) -> Result<Agent> {
        self.db.create_agent(name)
    }

    pub fn get_agent(&self, id: &str) -> Result<Option<Agent>> {
        self.db.get_agent(id)
    }

    pub fn get_agent_by_name(&self, name: &str) -> Result<Option<Agent>> {
        self.db.get_agent_by_name(name)
    }

    pub fn list_agents(&self) -> Result<Vec<Agent>> {
        self.db.list_agents()
    }

    pub fn update_agent_status(
        &self,
        id: &str,
        status: AgentStatus,
        current_task_id: Option<&str>,
    ) -> Result<()> {
        self.db.update_agent_status(id, status, current_task_id)
    }

    // Logging
    pub fn log_task_action(
        &self,
        task_id: &str,
        agent_id: Option<&str>,
        action: &str,
        details: Option<&str>,
    ) -> Result<()> {
        self.db.log_task_action(task_id, agent_id, action, details)
    }

    pub fn get_task_logs(&self, task_id: &str) -> Result<Vec<TaskLog>> {
        self.db.get_task_logs(task_id)
    }

    // Statistics
    pub fn get_stats(&self) -> Result<TaskStats> {
        self.db.get_stats()
    }

    // Helper methods for agents

    /// Sync an agent with a task (start working)
    /// This will:
    /// - Update agent status to Working
    /// - Set the task as the agent's current task
    /// - Update task status to InProgress
    /// - Assign the task to the agent if not already assigned
    pub fn sync_agent(&self, agent_name: &str, task_id: &str) -> Result<()> {
        // Get or create agent
        let agent = match self.db.get_agent_by_name(agent_name)? {
            Some(a) => a,
            None => self.db.create_agent(agent_name.to_string())?,
        };

        // Update agent status
        self.db
            .update_agent_status(&agent.id, AgentStatus::Working, Some(task_id))?;

        // Update task status
        self.db
            .update_task_status(task_id, TaskStatus::InProgress, Some(&agent.id))?;

        // Assign task if not already assigned
        self.db.assign_task(task_id, &agent.id)?;

        Ok(())
    }

    /// Get the next pending task for an agent to work on
    pub fn get_next_task(&self, priority_filter: Option<Priority>) -> Result<Option<Task>> {
        let tasks = self.db.list_tasks(Some(TaskStatus::Pending))?;

        // Filter by priority if specified
        let mut filtered_tasks: Vec<Task> = if let Some(priority) = priority_filter {
            tasks
                .into_iter()
                .filter(|t| t.priority == priority)
                .collect()
        } else {
            tasks
        };

        // Sort by priority (highest first) then by creation date (oldest first)
        filtered_tasks.sort_by(|a, b| {
            use std::cmp::Ordering;

            let priority_cmp = match (&b.priority, &a.priority) {
                (Priority::Critical, Priority::Critical) => Ordering::Equal,
                (Priority::Critical, _) => Ordering::Greater,
                (_, Priority::Critical) => Ordering::Less,
                (Priority::High, Priority::High) => Ordering::Equal,
                (Priority::High, _) => Ordering::Greater,
                (_, Priority::High) => Ordering::Less,
                (Priority::Medium, Priority::Medium) => Ordering::Equal,
                (Priority::Medium, _) => Ordering::Greater,
                (_, Priority::Medium) => Ordering::Less,
                (Priority::Low, Priority::Low) => Ordering::Equal,
            };

            if priority_cmp == Ordering::Equal {
                a.created_at.cmp(&b.created_at)
            } else {
                priority_cmp
            }
        });

        Ok(filtered_tasks.into_iter().next())
    }

    /// Mark an agent as idle
    pub fn set_agent_idle(&self, agent_name: &str) -> Result<()> {
        if let Some(agent) = self.db.get_agent_by_name(agent_name)? {
            self.db
                .update_agent_status(&agent.id, AgentStatus::Idle, None)?;
        }
        Ok(())
    }

    /// Complete a task and set agent to idle
    pub fn complete_task(&self, task_id: &str, agent_name: &str) -> Result<()> {
        if let Some(agent) = self.db.get_agent_by_name(agent_name)? {
            self.db
                .update_task_status(task_id, TaskStatus::Completed, Some(&agent.id))?;
            self.db
                .update_agent_status(&agent.id, AgentStatus::Idle, None)?;
        }
        Ok(())
    }

    /// Block a task and set agent to blocked
    pub fn block_task(&self, task_id: &str, agent_name: &str, reason: Option<&str>) -> Result<()> {
        if let Some(agent) = self.db.get_agent_by_name(agent_name)? {
            self.db
                .update_task_status(task_id, TaskStatus::Blocked, Some(&agent.id))?;
            self.db
                .update_agent_status(&agent.id, AgentStatus::Blocked, Some(task_id))?;

            if let Some(r) = reason {
                self.db
                    .log_task_action(task_id, Some(&agent.id), "blocked", Some(r))?;
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_client_creation() {
        let client = PRDClient::new(":memory:");
        assert!(client.is_ok());
    }

    #[test]
    fn test_task_workflow() -> Result<()> {
        let client = PRDClient::new(":memory:")?;

        // Create a task
        let task = client.create_task(
            "Test task".to_string(),
            Some("Test description".to_string()),
            Priority::High,
            None,
            None,
        )?;

        assert_eq!(task.title, "Test task");
        assert_eq!(task.status, TaskStatus::Pending);

        // Create an agent
        let agent = client.create_agent("test-agent".to_string())?;

        // Sync agent with task
        client.sync_agent(&agent.name, &task.id)?;

        // Verify task status updated
        let updated_task = client.get_task(&task.id)?.unwrap();
        assert_eq!(updated_task.status, TaskStatus::InProgress);

        // Complete task
        client.complete_task(&task.id, &agent.name)?;

        // Verify completion
        let completed_task = client.get_task(&task.id)?.unwrap();
        assert_eq!(completed_task.status, TaskStatus::Completed);

        Ok(())
    }

    #[test]
    fn test_get_next_task() -> Result<()> {
        let client = PRDClient::new(":memory:")?;

        // Create tasks with different priorities
        client.create_task(
            "Low priority task".to_string(),
            None,
            Priority::Low,
            None,
            None,
        )?;

        let critical_task = client.create_task(
            "Critical task".to_string(),
            None,
            Priority::Critical,
            None,
            None,
        )?;

        client.create_task(
            "Medium priority task".to_string(),
            None,
            Priority::Medium,
            None,
            None,
        )?;

        // Get next task (should be critical)
        let next_task = client.get_next_task(None)?.unwrap();
        assert_eq!(next_task.id, critical_task.id);
        assert_eq!(next_task.priority, Priority::Critical);

        Ok(())
    }
}
