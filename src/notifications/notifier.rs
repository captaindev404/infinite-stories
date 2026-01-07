use super::config::NotificationConfig;
use crate::db::{Agent, Task};
use anyhow::Result;
use notify_rust::{Notification, Timeout};
use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Desktop notification manager
pub struct Notifier {
    config: NotificationConfig,
    /// Track last notification time per agent ID to enforce rate limiting
    last_notification: HashMap<String, Instant>,
    /// Track which milestones have been triggered to prevent duplicates
    milestone_triggered: HashMap<u8, bool>,
}

impl Notifier {
    /// Create a new notifier with the given configuration
    pub fn new(config: NotificationConfig) -> Self {
        Self {
            config,
            last_notification: HashMap::new(),
            milestone_triggered: HashMap::new(),
        }
    }

    /// Create a notifier with default configuration
    pub fn with_default_config() -> Result<Self> {
        let config = NotificationConfig::load()?;
        Ok(Self::new(config))
    }

    /// Notify about a completed task
    pub fn notify_task_complete(&mut self, task: &Task, agent: &Agent) -> Result<()> {
        if !self.should_notify("complete", &agent.id) {
            return Ok(());
        }

        let title = "🎉 Task Complete!";
        let body = format!(
            "Agent {} finished task #{}: {}",
            agent.name,
            task.display_id.unwrap_or(0),
            task.title
        );

        self.send_notification(title, &body)?;
        self.update_last_notification(&agent.id);
        Ok(())
    }

    /// Notify about an agent error
    pub fn notify_agent_error(&mut self, task: &Task, agent: &Agent, error: &str) -> Result<()> {
        if !self.should_notify("error", &agent.id) {
            return Ok(());
        }

        let title = "⚠️ Agent Error!";
        let body = format!(
            "Agent {} failed on task #{}: {}",
            agent.name,
            task.display_id.unwrap_or(0),
            error
        );

        self.send_notification(title, &body)?;
        self.update_last_notification(&agent.id);
        Ok(())
    }

    /// Notify about a milestone reached
    pub fn notify_milestone(&mut self, percentage: u8, completed: i32, total: i32) -> Result<()> {
        if !self.config.is_event_enabled("milestone") {
            return Ok(());
        }

        // Check if this milestone was already triggered
        if self
            .milestone_triggered
            .get(&percentage)
            .copied()
            .unwrap_or(false)
        {
            return Ok(());
        }

        let title = "🎯 Milestone Reached!";
        let body = format!(
            "{}% Complete! {}/{} tasks done",
            percentage, completed, total
        );

        self.send_notification(title, &body)?;
        self.milestone_triggered.insert(percentage, true);
        Ok(())
    }

    /// Check if we should send a notification for this event type and agent
    fn should_notify(&self, event_type: &str, agent_id: &str) -> bool {
        // Check if notifications are enabled
        if !self.config.enabled {
            return false;
        }

        // Check if this event type is enabled
        if !self.config.events.contains(&event_type.to_string()) {
            return false;
        }

        // Check rate limit for this agent
        if let Some(last_time) = self.last_notification.get(agent_id) {
            let elapsed = last_time.elapsed().as_secs();
            if elapsed < self.config.rate_limit_seconds {
                return false; // Rate limited
            }
        }

        true
    }

    /// Send a desktop notification
    fn send_notification(&self, title: &str, body: &str) -> Result<()> {
        // Try to send notification, but don't fail if notification system is unavailable
        match self.try_send_notification(title, body) {
            Ok(_) => Ok(()),
            Err(e) => {
                // Log error but don't propagate it
                eprintln!("Warning: Failed to send notification: {}", e);
                Ok(())
            }
        }
    }

    /// Actually try to send the notification (may fail on some systems)
    fn try_send_notification(&self, title: &str, body: &str) -> Result<()> {
        let mut notification = Notification::new();
        notification
            .summary(title)
            .body(body)
            .timeout(Timeout::Milliseconds(5000))
            .appname("PRD Tool");

        if self.config.sound {
            notification.sound_name("default");
        }

        notification.show()?;
        Ok(())
    }

    /// Update the last notification time for an agent
    fn update_last_notification(&mut self, agent_id: &str) {
        self.last_notification
            .insert(agent_id.to_string(), Instant::now());
    }

    /// Get the configuration
    pub fn config(&self) -> &NotificationConfig {
        &self.config
    }

    /// Reset milestone triggers (useful for testing)
    #[allow(dead_code)]
    pub fn reset_milestones(&mut self) {
        self.milestone_triggered.clear();
    }

    /// Clear rate limiting state (useful for testing)
    #[allow(dead_code)]
    pub fn clear_rate_limits(&mut self) {
        self.last_notification.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::{AgentStatus, Priority, TaskStatus};
    use chrono::Utc;

    fn create_test_config() -> NotificationConfig {
        NotificationConfig {
            enabled: true,
            events: vec![
                "complete".to_string(),
                "error".to_string(),
                "milestone".to_string(),
            ],
            sound: false, // Disable sound in tests
            min_priority: "medium".to_string(),
            rate_limit_seconds: 60,
        }
    }

    fn create_test_agent() -> Agent {
        Agent {
            id: "agent-1".to_string(),
            display_id: Some(1),
            name: "Test Agent".to_string(),
            status: AgentStatus::Working,
            current_task_id: None,
            created_at: Utc::now(),
            last_active: Utc::now(),
        }
    }

    fn create_test_task() -> Task {
        Task {
            id: "task-1".to_string(),
            display_id: Some(1),
            title: "Test Task".to_string(),
            description: Some("Test description".to_string()),
            status: TaskStatus::InProgress,
            priority: Priority::Medium,
            parent_id: None,
            assigned_agent: Some("agent-1".to_string()),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            completed_at: None,
            estimated_duration: None,
            actual_duration: None,
            epic_name: None,
        }
    }

    #[test]
    fn test_notifier_creation() {
        let config = create_test_config();
        let notifier = Notifier::new(config.clone());
        assert_eq!(notifier.config.enabled, config.enabled);
        assert_eq!(notifier.last_notification.len(), 0);
        assert_eq!(notifier.milestone_triggered.len(), 0);
    }

    #[test]
    fn test_should_notify_enabled_event() {
        let config = create_test_config();
        let notifier = Notifier::new(config);

        // Should notify for enabled events
        assert!(notifier.should_notify("complete", "agent-1"));
        assert!(notifier.should_notify("error", "agent-1"));
        assert!(notifier.should_notify("milestone", "agent-1"));
    }

    #[test]
    fn test_should_notify_disabled_notifications() {
        let mut config = create_test_config();
        config.enabled = false;
        let notifier = Notifier::new(config);

        // Should not notify when disabled
        assert!(!notifier.should_notify("complete", "agent-1"));
        assert!(!notifier.should_notify("error", "agent-1"));
    }

    #[test]
    fn test_should_notify_filtered_events() {
        let mut config = create_test_config();
        config.events = vec!["complete".to_string()]; // Only complete events
        let notifier = Notifier::new(config);

        // Should only notify for complete events
        assert!(notifier.should_notify("complete", "agent-1"));
        assert!(!notifier.should_notify("error", "agent-1"));
        assert!(!notifier.should_notify("milestone", "agent-1"));
    }

    #[test]
    fn test_rate_limiting() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);
        let agent = create_test_agent();

        // First notification should be allowed
        assert!(notifier.should_notify("complete", &agent.id));

        // Update last notification time
        notifier.update_last_notification(&agent.id);

        // Immediate second notification should be blocked by rate limit
        assert!(!notifier.should_notify("complete", &agent.id));
    }

    #[test]
    fn test_rate_limiting_different_agents() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);

        // Rate limiting should be per-agent
        assert!(notifier.should_notify("complete", "agent-1"));
        notifier.update_last_notification("agent-1");

        // Different agent should not be rate limited
        assert!(notifier.should_notify("complete", "agent-2"));
    }

    #[test]
    fn test_milestone_triggering_once() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);

        // First milestone trigger should succeed
        let result = notifier.notify_milestone(50, 25, 50);
        assert!(result.is_ok());

        // Second trigger of same milestone should be no-op
        let result = notifier.notify_milestone(50, 25, 50);
        assert!(result.is_ok());

        // Verify milestone was marked as triggered
        assert_eq!(notifier.milestone_triggered.get(&50), Some(&true));
    }

    #[test]
    fn test_milestone_different_percentages() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);

        // Different milestones should trigger independently
        notifier.notify_milestone(25, 10, 40).unwrap();
        notifier.notify_milestone(50, 20, 40).unwrap();
        notifier.notify_milestone(75, 30, 40).unwrap();
        notifier.notify_milestone(100, 40, 40).unwrap();

        assert_eq!(notifier.milestone_triggered.get(&25), Some(&true));
        assert_eq!(notifier.milestone_triggered.get(&50), Some(&true));
        assert_eq!(notifier.milestone_triggered.get(&75), Some(&true));
        assert_eq!(notifier.milestone_triggered.get(&100), Some(&true));
    }

    #[test]
    fn test_milestone_disabled_event() {
        let mut config = create_test_config();
        config.events = vec!["complete".to_string()]; // No milestone events
        let mut notifier = Notifier::new(config);

        // Milestone notification should be no-op
        let result = notifier.notify_milestone(50, 25, 50);
        assert!(result.is_ok());

        // Milestone should not be marked as triggered
        assert_eq!(notifier.milestone_triggered.get(&50), None);
    }

    #[test]
    fn test_notify_task_complete() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);
        let agent = create_test_agent();
        let task = create_test_task();

        // Note: This will try to send a real notification but gracefully fail in CI
        let result = notifier.notify_task_complete(&task, &agent);
        assert!(result.is_ok());

        // Verify last notification was updated
        assert!(notifier.last_notification.contains_key(&agent.id));
    }

    #[test]
    fn test_notify_agent_error() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);
        let agent = create_test_agent();
        let task = create_test_task();

        // Note: This will try to send a real notification but gracefully fail in CI
        let result = notifier.notify_agent_error(&task, &agent, "Test error message");
        assert!(result.is_ok());

        // Verify last notification was updated
        assert!(notifier.last_notification.contains_key(&agent.id));
    }

    #[test]
    fn test_clear_rate_limits() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);

        // Add some rate limit entries
        notifier.update_last_notification("agent-1");
        notifier.update_last_notification("agent-2");
        assert_eq!(notifier.last_notification.len(), 2);

        // Clear rate limits
        notifier.clear_rate_limits();
        assert_eq!(notifier.last_notification.len(), 0);
    }

    #[test]
    fn test_reset_milestones() {
        let config = create_test_config();
        let mut notifier = Notifier::new(config);

        // Trigger some milestones
        notifier.notify_milestone(25, 10, 40).unwrap();
        notifier.notify_milestone(50, 20, 40).unwrap();
        assert_eq!(notifier.milestone_triggered.len(), 2);

        // Reset milestones
        notifier.reset_milestones();
        assert_eq!(notifier.milestone_triggered.len(), 0);
    }
}
