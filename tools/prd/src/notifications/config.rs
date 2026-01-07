use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// Configuration for desktop notifications
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
pub struct NotificationConfig {
    /// Whether notifications are enabled
    pub enabled: bool,

    /// Types of events to notify about: "complete", "error", "milestone"
    pub events: Vec<String>,

    /// Whether to play sound with notifications
    pub sound: bool,

    /// Minimum priority level for notifications: "low", "medium", "high"
    pub min_priority: String,

    /// Rate limit in seconds - max 1 notification per agent per this interval
    pub rate_limit_seconds: u64,
}

impl Default for NotificationConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            events: vec![
                "complete".to_string(),
                "error".to_string(),
                "milestone".to_string(),
            ],
            sound: true,
            min_priority: "medium".to_string(),
            rate_limit_seconds: 60,
        }
    }
}

impl NotificationConfig {
    /// Load configuration from the standard location (~/.prd/config.toml)
    pub fn load() -> Result<Self> {
        let config_path = Self::get_config_path()?;

        if !config_path.exists() {
            // Create default config file
            let config = Self::default();
            config.save()?;
            Ok(config)
        } else {
            // Load from file
            let content = fs::read_to_string(&config_path)
                .context(format!("Failed to read config from {:?}", config_path))?;

            let config: Self =
                toml::from_str(&content).context("Failed to parse config file as TOML")?;

            Ok(config)
        }
    }

    /// Save configuration to the standard location
    pub fn save(&self) -> Result<()> {
        let config_path = Self::get_config_path()?;

        // Ensure parent directory exists
        if let Some(parent) = config_path.parent() {
            fs::create_dir_all(parent)
                .context(format!("Failed to create config directory {:?}", parent))?;
        }

        // Serialize to TOML
        let toml_content =
            toml::to_string_pretty(self).context("Failed to serialize config to TOML")?;

        // Write to file
        fs::write(&config_path, toml_content)
            .context(format!("Failed to write config to {:?}", config_path))?;

        Ok(())
    }

    /// Get the path to the config file (~/.prd/config.toml)
    pub fn get_config_path() -> Result<PathBuf> {
        let home = std::env::var("HOME").context("HOME environment variable not set")?;

        Ok(PathBuf::from(home).join(".prd").join("config.toml"))
    }

    /// Check if a specific event type is enabled
    pub fn is_event_enabled(&self, event_type: &str) -> bool {
        self.enabled && self.events.iter().any(|e| e == event_type)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    fn test_default_config() {
        let config = NotificationConfig::default();
        assert!(config.enabled);
        assert_eq!(config.events.len(), 3);
        assert!(config.events.contains(&"complete".to_string()));
        assert!(config.events.contains(&"error".to_string()));
        assert!(config.events.contains(&"milestone".to_string()));
        assert!(config.sound);
        assert_eq!(config.min_priority, "medium");
        assert_eq!(config.rate_limit_seconds, 60);
    }

    #[test]
    fn test_is_event_enabled() {
        let mut config = NotificationConfig::default();
        assert!(config.is_event_enabled("complete"));
        assert!(config.is_event_enabled("error"));
        assert!(config.is_event_enabled("milestone"));

        // Test with disabled notifications
        config.enabled = false;
        assert!(!config.is_event_enabled("complete"));

        // Test with filtered events
        config.enabled = true;
        config.events = vec!["complete".to_string()];
        assert!(config.is_event_enabled("complete"));
        assert!(!config.is_event_enabled("error"));
    }

    #[test]
    fn test_config_serialization() {
        let config = NotificationConfig::default();
        let toml_str = toml::to_string(&config).unwrap();
        assert!(toml_str.contains("enabled"));
        assert!(toml_str.contains("events"));
        assert!(toml_str.contains("sound"));
        assert!(toml_str.contains("min_priority"));
        assert!(toml_str.contains("rate_limit_seconds"));
    }

    #[test]
    fn test_config_deserialization() {
        let toml_str = r#"
            enabled = false
            events = ["complete"]
            sound = false
            min_priority = "high"
            rate_limit_seconds = 120
        "#;

        let config: NotificationConfig = toml::from_str(toml_str).unwrap();
        assert!(!config.enabled);
        assert_eq!(config.events.len(), 1);
        assert_eq!(config.events[0], "complete");
        assert!(!config.sound);
        assert_eq!(config.min_priority, "high");
        assert_eq!(config.rate_limit_seconds, 120);
    }

    #[test]
    fn test_config_path() {
        // This test may fail if HOME is not set, which is acceptable
        if let Ok(home) = env::var("HOME") {
            let path = NotificationConfig::get_config_path().unwrap();
            assert!(path.to_string_lossy().contains(&home));
            assert!(path.to_string_lossy().ends_with(".prd/config.toml"));
        }
    }

    #[test]
    fn test_custom_config() {
        let config = NotificationConfig {
            enabled: false,
            events: vec!["error".to_string()],
            sound: false,
            min_priority: "low".to_string(),
            rate_limit_seconds: 30,
        };

        assert!(!config.enabled);
        assert_eq!(config.events.len(), 1);
        assert!(!config.sound);
        assert_eq!(config.rate_limit_seconds, 30);
    }
}
