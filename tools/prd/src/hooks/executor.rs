use super::config::HookConfig;
use crate::db::{Agent, Task};
use anyhow::Result;
use chrono::Utc;
use std::collections::HashMap;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

pub struct HookExecutor {
    config: HookConfig,
}

impl HookExecutor {
    /// Create a new hook executor with the given configuration
    pub fn new(config: HookConfig) -> Self {
        Self { config }
    }

    /// Create a hook executor with default configuration loaded from disk
    pub fn from_default() -> Result<Self> {
        let config = HookConfig::load()?;
        Ok(Self::new(config))
    }

    /// Trigger the on_task_complete hook
    pub fn trigger_task_complete(&self, task: &Task, agent: &Agent) -> Result<()> {
        if !self.config.is_enabled("on_task_complete") {
            return Ok(());
        }

        if let Some(hook_cmd) = self.config.get_hook_command("on_task_complete") {
            let vars = HashMap::from([
                ("task_id".to_string(), format_task_id(task)),
                ("agent_id".to_string(), format_agent_id(agent)),
                ("task_title".to_string(), task.title.clone()),
                ("status".to_string(), task.status.as_str().to_string()),
                ("timestamp".to_string(), Utc::now().to_rfc3339()),
            ]);

            self.execute_hook("on_task_complete", hook_cmd, vars)?;
        }

        Ok(())
    }

    /// Trigger the on_task_start hook
    pub fn trigger_task_start(&self, task: &Task, agent: &Agent) -> Result<()> {
        if !self.config.is_enabled("on_task_start") {
            return Ok(());
        }

        if let Some(hook_cmd) = self.config.get_hook_command("on_task_start") {
            let vars = HashMap::from([
                ("task_id".to_string(), format_task_id(task)),
                ("agent_id".to_string(), format_agent_id(agent)),
                ("task_title".to_string(), task.title.clone()),
                ("timestamp".to_string(), Utc::now().to_rfc3339()),
            ]);

            self.execute_hook("on_task_start", hook_cmd, vars)?;
        }

        Ok(())
    }

    /// Trigger the on_sync hook
    pub fn trigger_sync(&self, count: usize) -> Result<()> {
        if !self.config.is_enabled("on_sync") {
            return Ok(());
        }

        if let Some(hook_cmd) = self.config.get_hook_command("on_sync") {
            let vars = HashMap::from([
                ("count".to_string(), count.to_string()),
                ("timestamp".to_string(), Utc::now().to_rfc3339()),
            ]);

            self.execute_hook("on_sync", hook_cmd, vars)?;
        }

        Ok(())
    }

    /// Trigger the on_agent_error hook
    pub fn trigger_agent_error(&self, agent: &Agent, task: &Task, error: &str) -> Result<()> {
        if !self.config.is_enabled("on_agent_error") {
            return Ok(());
        }

        if let Some(hook_cmd) = self.config.get_hook_command("on_agent_error") {
            let vars = HashMap::from([
                ("agent_id".to_string(), format_agent_id(agent)),
                ("task_id".to_string(), format_task_id(task)),
                ("error".to_string(), error.to_string()),
                ("timestamp".to_string(), Utc::now().to_rfc3339()),
            ]);

            self.execute_hook("on_agent_error", hook_cmd, vars)?;
        }

        Ok(())
    }

    /// Trigger the on_milestone hook
    pub fn trigger_milestone(&self, percent: u8, completed: i32, total: i32) -> Result<()> {
        if !self.config.is_enabled("on_milestone") {
            return Ok(());
        }

        if let Some(hook_cmd) = self.config.get_hook_command("on_milestone") {
            let vars = HashMap::from([
                ("percent".to_string(), percent.to_string()),
                ("completed".to_string(), completed.to_string()),
                ("total".to_string(), total.to_string()),
                ("timestamp".to_string(), Utc::now().to_rfc3339()),
            ]);

            self.execute_hook("on_milestone", hook_cmd, vars)?;
        }

        Ok(())
    }

    /// Execute a hook command asynchronously with variable substitution
    fn execute_hook(
        &self,
        hook_name: &str,
        hook_cmd: &str,
        vars: HashMap<String, String>,
    ) -> Result<()> {
        // Substitute variables
        let mut cmd = hook_cmd.to_string();
        for (key, value) in &vars {
            cmd = cmd.replace(&format!("{{{}}}", key), value);
        }

        // Execute asynchronously with timeout
        let cmd_clone = cmd.clone();
        let hook_name_clone = hook_name.to_string();

        thread::spawn(move || {
            if let Err(e) = execute_with_timeout(&cmd_clone, Duration::from_secs(30)) {
                eprintln!("❌ Hook '{}' failed: {}", hook_name_clone, e);
            }
        });

        Ok(())
    }
}

/// Execute a command with a timeout
fn execute_with_timeout(cmd: &str, timeout: Duration) -> Result<()> {
    // Parse command safely
    let parts =
        shell_words::split(cmd).map_err(|e| anyhow::anyhow!("Failed to parse command: {}", e))?;

    if parts.is_empty() {
        return Ok(());
    }

    // Execute with timeout
    let mut child = Command::new(&parts[0])
        .args(&parts[1..])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| anyhow::anyhow!("Failed to execute command: {}", e))?;

    // Wait with timeout
    let start = std::time::Instant::now();
    loop {
        match child.try_wait()? {
            Some(status) => {
                if !status.success() {
                    let output = child.wait_with_output()?;
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    return Err(anyhow::anyhow!(
                        "Command exited with status {}: {}",
                        status,
                        stderr
                    ));
                }
                return Ok(());
            }
            None => {
                if start.elapsed() > timeout {
                    child.kill()?;
                    return Err(anyhow::anyhow!("Command timed out after {:?}", timeout));
                }
                thread::sleep(Duration::from_millis(100));
            }
        }
    }
}

/// Format a task ID for display (e.g., "#42")
fn format_task_id(task: &Task) -> String {
    task.display_id
        .map(|id| format!("#{}", id))
        .unwrap_or_else(|| task.id[..8].to_string())
}

/// Format an agent ID for display (e.g., "A12")
fn format_agent_id(agent: &Agent) -> String {
    agent
        .display_id
        .map(|id| format!("A{}", id))
        .unwrap_or_else(|| agent.id[..8].to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::{AgentStatus, Priority, TaskStatus};
    use chrono::Utc;

    fn create_test_task() -> Task {
        Task {
            id: "test-task-uuid".to_string(),
            display_id: Some(42),
            title: "Test task".to_string(),
            description: Some("Test description".to_string()),
            status: TaskStatus::Completed,
            priority: Priority::Medium,
            parent_id: None,
            assigned_agent: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            completed_at: Some(Utc::now()),
            estimated_duration: None,
            actual_duration: None,
            epic_name: None,
        }
    }

    fn create_test_agent() -> Agent {
        Agent {
            id: "test-agent-uuid".to_string(),
            display_id: Some(10),
            name: "test-agent".to_string(),
            status: AgentStatus::Idle,
            current_task_id: None,
            created_at: Utc::now(),
            last_active: Utc::now(),
        }
    }

    #[test]
    fn test_variable_substitution() {
        let cmd = "echo 'Task {task_id} by {agent_id}'";
        let mut vars = HashMap::new();
        vars.insert("task_id".to_string(), "42".to_string());
        vars.insert("agent_id".to_string(), "A10".to_string());

        let mut result = cmd.to_string();
        for (key, value) in vars {
            result = result.replace(&format!("{{{}}}", key), &value);
        }

        assert_eq!(result, "echo 'Task 42 by A10'");
    }

    #[test]
    fn test_format_task_id() {
        let task = create_test_task();
        assert_eq!(format_task_id(&task), "#42");
    }

    #[test]
    fn test_format_agent_id() {
        let agent = create_test_agent();
        assert_eq!(format_agent_id(&agent), "A10");
    }

    #[test]
    fn test_hook_executor_disabled_hooks() {
        let config = HookConfig::default();
        let executor = HookExecutor::new(config);
        let task = create_test_task();
        let agent = create_test_agent();

        // Should not error when hooks are disabled
        assert!(executor.trigger_task_complete(&task, &agent).is_ok());
        assert!(executor.trigger_task_start(&task, &agent).is_ok());
        assert!(executor.trigger_sync(5).is_ok());
        assert!(executor
            .trigger_agent_error(&agent, &task, "test error")
            .is_ok());
        assert!(executor.trigger_milestone(50, 25, 50).is_ok());
    }

    #[test]
    fn test_execute_with_timeout_success() {
        // Simple command that should succeed
        let result = execute_with_timeout("echo hello", Duration::from_secs(5));
        assert!(result.is_ok());
    }

    #[test]
    fn test_execute_with_timeout_invalid_command() {
        // Command that doesn't exist
        let result = execute_with_timeout("nonexistent_command_12345", Duration::from_secs(1));
        assert!(result.is_err());
    }
}
