use crate::db::{Agent, AgentProgress, AgentStatus, Database};
use anyhow::Result;
use chrono::{DateTime, Utc};
use std::collections::VecDeque;
use std::time::Duration;

/// Represents an agent's display information for the dashboard
#[derive(Debug, Clone)]
pub struct AgentDisplay {
    pub id: String,
    pub name: String,
    pub status: AgentStatus,
    pub current_task: Option<i32>,
    pub progress: u8,
    pub elapsed: Duration,
    pub last_active: DateTime<Utc>,
}

/// Represents an activity event in the dashboard log
#[derive(Debug, Clone)]
pub struct ActivityEvent {
    pub timestamp: DateTime<Utc>,
    pub message: String,
}

/// Dashboard state containing all live data
pub struct DashboardState {
    pub agents: Vec<AgentDisplay>,
    pub overall_progress: f64,
    pub recent_activity: VecDeque<ActivityEvent>,
    pub last_refresh: DateTime<Utc>,
    pub completed_count: i32,
    pub total_count: i32,
}

impl DashboardState {
    /// Create a new dashboard state
    pub fn new() -> Self {
        Self {
            agents: Vec::new(),
            overall_progress: 0.0,
            recent_activity: VecDeque::with_capacity(10),
            last_refresh: Utc::now(),
            completed_count: 0,
            total_count: 0,
        }
    }

    /// Refresh dashboard state from database
    pub fn refresh(&mut self, db: &Database) -> Result<()> {
        self.last_refresh = Utc::now();

        // Get all agents
        let agents = db.list_agents()?;

        // Get statistics
        let stats = db.get_stats()?;
        self.completed_count = stats.completed;
        self.total_count = stats.total;
        self.overall_progress = if stats.total > 0 {
            (stats.completed as f64 / stats.total as f64) * 100.0
        } else {
            0.0
        };

        // Build agent displays
        self.agents.clear();
        for agent in &agents {
            let elapsed = self.calculate_elapsed(&agent);
            let current_task = self.extract_task_id(&agent);
            let progress = self.get_agent_progress(db, &agent.id)?;

            self.agents.push(AgentDisplay {
                id: agent.id.clone(),
                name: agent.name.clone(),
                status: agent.status.clone(),
                current_task,
                progress,
                elapsed,
                last_active: agent.last_active,
            });
        }

        // Sort agents by status (working first, then idle, then others)
        self.agents.sort_by(|a, b| {
            use AgentStatus::*;
            let a_priority = match a.status {
                Working => 0,
                Blocked => 1,
                Idle => 2,
                Offline => 3,
            };
            let b_priority = match b.status {
                Working => 0,
                Blocked => 1,
                Idle => 2,
                Offline => 3,
            };
            a_priority
                .cmp(&b_priority)
                .then_with(|| a.name.cmp(&b.name))
        });

        // Update recent activity
        self.update_activity(&agents);

        Ok(())
    }

    /// Calculate elapsed time for an agent's current task
    fn calculate_elapsed(&self, agent: &Agent) -> Duration {
        if agent.status == AgentStatus::Working {
            let now = Utc::now();
            let duration = now.signed_duration_since(agent.last_active);
            Duration::from_secs(duration.num_seconds().max(0) as u64)
        } else {
            Duration::from_secs(0)
        }
    }

    /// Extract task ID from agent's current task
    fn extract_task_id(&self, agent: &Agent) -> Option<i32> {
        agent.current_task_id.as_ref().and_then(|task_uuid| {
            // We'd need to look up the display_id from the task UUID
            // For now, return None if no current task
            None
        })
    }

    /// Get agent's latest progress percentage
    fn get_agent_progress(&self, db: &Database, agent_id: &str) -> Result<u8> {
        match db.get_latest_progress(agent_id)? {
            Some(progress) => Ok(progress.progress),
            None => Ok(0),
        }
    }

    /// Update recent activity log
    fn update_activity(&mut self, agents: &[Agent]) {
        // Add new activities (e.g., status changes, completions)
        for agent in agents {
            if agent.status == AgentStatus::Working {
                let progress = self
                    .agents
                    .iter()
                    .find(|a| a.id == agent.id)
                    .map(|a| a.progress)
                    .unwrap_or(0);

                if progress > 0 && progress < 100 {
                    let message = if let Some(task) = agent.current_task_id.as_ref() {
                        format!("{} working on task: {}%", agent.name, progress)
                    } else {
                        format!("{} is working", agent.name)
                    };

                    self.add_activity(message);
                }
            }
        }

        // Keep only last 10 activities
        while self.recent_activity.len() > 10 {
            self.recent_activity.pop_back();
        }
    }

    /// Add an activity event to the log
    pub fn add_activity(&mut self, message: String) {
        // Check if this message already exists recently
        let exists = self.recent_activity.iter().any(|e| {
            e.message == message
                && self
                    .last_refresh
                    .signed_duration_since(e.timestamp)
                    .num_seconds()
                    < 10
        });

        if !exists {
            self.recent_activity.push_front(ActivityEvent {
                timestamp: Utc::now(),
                message,
            });

            // Keep only last 10
            while self.recent_activity.len() > 10 {
                self.recent_activity.pop_back();
            }
        }
    }

    /// Get formatted elapsed time string
    pub fn format_elapsed(elapsed: Duration) -> String {
        let total_secs = elapsed.as_secs();
        let hours = total_secs / 3600;
        let minutes = (total_secs % 3600) / 60;
        let seconds = total_secs % 60;

        if hours > 0 {
            format!("{}h {}m", hours, minutes)
        } else if minutes > 0 {
            format!("{}m {}s", minutes, seconds)
        } else {
            format!("{}s", seconds)
        }
    }
}

impl Default for DashboardState {
    fn default() -> Self {
        Self::new()
    }
}
