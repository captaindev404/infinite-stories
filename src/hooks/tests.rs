#[cfg(test)]
mod hooks_tests {
    use crate::hooks::{HookConfig, HookExecutor};
    use std::collections::HashMap;

    #[test]
    fn test_default_config() {
        let config = HookConfig::default();
        assert!(config.on_task_complete.is_none());
        assert!(!config.is_enabled("on_task_complete"));
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
    fn test_executor_from_default() {
        // This should not panic even if no config file exists
        let result = HookExecutor::from_default();
        assert!(result.is_ok());
    }

    #[test]
    fn test_get_hook_command() {
        let mut config = HookConfig::default();
        config.on_task_complete = Some("echo test".to_string());

        assert!(config.get_hook_command("on_task_complete").is_some());
        assert!(config.get_hook_command("on_task_start").is_none());
        assert!(config.get_hook_command("invalid").is_none());
    }

    #[test]
    fn test_enable_disable_hook() {
        let mut config = HookConfig::default();

        // Initially disabled
        assert!(!config.is_enabled("on_task_complete"));

        // Enable
        config.enabled.insert("on_task_complete".to_string(), true);
        assert!(config.is_enabled("on_task_complete"));

        // Disable
        config.enabled.insert("on_task_complete".to_string(), false);
        assert!(!config.is_enabled("on_task_complete"));
    }
}
