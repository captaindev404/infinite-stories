use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct HookConfig {
    #[serde(default)]
    pub on_task_complete: Option<String>,

    #[serde(default)]
    pub on_task_start: Option<String>,

    #[serde(default)]
    pub on_sync: Option<String>,

    #[serde(default)]
    pub on_agent_error: Option<String>,

    #[serde(default)]
    pub on_milestone: Option<String>,

    #[serde(default = "default_enabled")]
    pub enabled: HashMap<String, bool>,
}

fn default_enabled() -> HashMap<String, bool> {
    HashMap::new()
}

impl Default for HookConfig {
    fn default() -> Self {
        Self {
            on_task_complete: None,
            on_task_start: None,
            on_sync: None,
            on_agent_error: None,
            on_milestone: None,
            enabled: default_enabled(),
        }
    }
}

impl HookConfig {
    /// Load hook configuration from the default location
    pub fn load() -> Result<Self> {
        let config_path = Self::get_config_path()?;

        if !config_path.exists() {
            return Ok(Self::default());
        }

        let content = fs::read_to_string(&config_path)?;
        let config: HookConfig = toml::from_str(&content)
            .map_err(|e| anyhow::anyhow!("Failed to parse hooks config: {}", e))?;

        Ok(config)
    }

    /// Save hook configuration to the default location
    pub fn save(&self) -> Result<()> {
        let config_path = Self::get_config_path()?;

        // Ensure directory exists
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)?;
        }

        let content = toml::to_string_pretty(self)?;
        fs::write(config_path, content)?;

        Ok(())
    }

    /// Initialize default hook configuration with examples
    pub fn init_default() -> Result<()> {
        let config = Self {
            on_task_complete: Some("echo 'Task {task_id} completed by {agent_id}'".to_string()),
            on_task_start: Some("echo 'Task {task_id} started by {agent_id}'".to_string()),
            on_sync: Some("echo 'Sync completed: {count} tasks'".to_string()),
            on_agent_error: Some("echo 'Agent {agent_id} error: {error}'".to_string()),
            on_milestone: Some(
                "echo 'Milestone: {percent}% complete ({completed}/{total} tasks)'".to_string(),
            ),
            enabled: HashMap::from([
                ("on_task_complete".to_string(), false),
                ("on_task_start".to_string(), false),
                ("on_sync".to_string(), false),
                ("on_agent_error".to_string(), false),
                ("on_milestone".to_string(), false),
            ]),
        };

        config.save()?;

        let config_path = Self::get_config_path()?;
        println!("✓ Created hook configuration at {}", config_path.display());
        println!("\nExample hooks have been configured (all disabled by default).");
        println!("\nTo enable a hook:");
        println!("  prd hooks enable on_task_complete");
        println!("\nTo customize hooks, edit: {}", config_path.display());
        println!("\nAvailable variables:");
        println!("  on_task_complete: {{task_id}}, {{agent_id}}, {{task_title}}, {{status}}, {{timestamp}}");
        println!("  on_task_start: {{task_id}}, {{agent_id}}, {{task_title}}, {{timestamp}}");
        println!("  on_sync: {{count}}, {{timestamp}}");
        println!("  on_agent_error: {{agent_id}}, {{task_id}}, {{error}}, {{timestamp}}");
        println!("  on_milestone: {{percent}}, {{completed}}, {{total}}, {{timestamp}}");

        Ok(())
    }

    /// Check if a hook is enabled
    pub fn is_enabled(&self, hook_name: &str) -> bool {
        self.enabled.get(hook_name).copied().unwrap_or(false)
    }

    /// Get the command for a specific hook
    pub fn get_hook_command(&self, hook_name: &str) -> Option<&String> {
        match hook_name {
            "on_task_complete" => self.on_task_complete.as_ref(),
            "on_task_start" => self.on_task_start.as_ref(),
            "on_sync" => self.on_sync.as_ref(),
            "on_agent_error" => self.on_agent_error.as_ref(),
            "on_milestone" => self.on_milestone.as_ref(),
            _ => None,
        }
    }

    /// List all hooks with their commands and enabled status
    pub fn list_hooks(&self) -> Vec<(&'static str, Option<&String>, bool)> {
        vec![
            (
                "on_task_complete",
                self.on_task_complete.as_ref(),
                self.is_enabled("on_task_complete"),
            ),
            (
                "on_task_start",
                self.on_task_start.as_ref(),
                self.is_enabled("on_task_start"),
            ),
            ("on_sync", self.on_sync.as_ref(), self.is_enabled("on_sync")),
            (
                "on_agent_error",
                self.on_agent_error.as_ref(),
                self.is_enabled("on_agent_error"),
            ),
            (
                "on_milestone",
                self.on_milestone.as_ref(),
                self.is_enabled("on_milestone"),
            ),
        ]
    }

    /// Get the configuration file path
    pub fn get_config_path() -> Result<PathBuf> {
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .map_err(|_| anyhow::anyhow!("Could not determine home directory"))?;
        Ok(PathBuf::from(home).join(".prd").join("hooks.toml"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = HookConfig::default();
        assert!(config.on_task_complete.is_none());
        assert!(!config.is_enabled("on_task_complete"));
    }

    #[test]
    fn test_is_enabled() {
        let mut config = HookConfig::default();
        config.enabled.insert("on_task_complete".to_string(), true);

        assert!(config.is_enabled("on_task_complete"));
        assert!(!config.is_enabled("on_task_start"));
    }

    #[test]
    fn test_list_hooks() {
        let config = HookConfig::default();
        let hooks = config.list_hooks();

        assert_eq!(hooks.len(), 5);
        assert_eq!(hooks[0].0, "on_task_complete");
        assert_eq!(hooks[1].0, "on_task_start");
    }

    #[test]
    fn test_get_hook_command() {
        let mut config = HookConfig::default();
        config.on_task_complete = Some("echo test".to_string());

        assert!(config.get_hook_command("on_task_complete").is_some());
        assert!(config.get_hook_command("on_task_start").is_none());
        assert!(config.get_hook_command("invalid").is_none());
    }
}
