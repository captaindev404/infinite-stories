pub mod config;
pub mod executor;

#[cfg(test)]
mod tests;

pub use config::HookConfig;
pub use executor::HookExecutor;

// Helper functions for CLI integration
use anyhow::Result;

/// Initialize hooks configuration with default examples
pub fn init_hooks_config() -> Result<()> {
    HookConfig::init_default()
}

/// List all configured hooks
pub fn list_hooks() -> Result<()> {
    let config = HookConfig::load()?;
    let hooks = config.list_hooks();

    println!("Configured hooks:\n");

    for (name, command, enabled) in hooks {
        let status = if enabled {
            "✓ Enabled"
        } else {
            "✗ Disabled"
        };
        let cmd_preview = command
            .map(|c| {
                if c.len() > 60 {
                    format!("{}...", &c[..57])
                } else {
                    c.clone()
                }
            })
            .unwrap_or_else(|| "<not configured>".to_string());

        println!("{}", name);
        println!("  Status: {}", status);
        println!("  Command: {}", cmd_preview);
        println!();
    }

    let config_path = HookConfig::get_config_path()?;
    println!("Configuration file: {}", config_path.display());

    Ok(())
}

/// Test a hook without side effects
pub fn test_hook(hook_name: &str, _task_id: Option<&str>, _agent_id: Option<&str>) -> Result<()> {
    let config = HookConfig::load()?;

    println!("Testing hook: {}\n", hook_name);

    // Note: Actual test implementation would use the database to get real tasks/agents
    // For now, just verify the hook is configured
    if let Some(cmd) = config.get_hook_command(hook_name) {
        println!("Hook command: {}", cmd);
        println!("\nThis would execute with mock data.");
        println!("Use `prd complete` or other commands to trigger hooks on real events.");
    } else {
        return Err(anyhow::anyhow!("Hook '{}' is not configured", hook_name));
    }

    Ok(())
}

/// Enable a hook
pub fn enable_hook(hook_name: &str) -> Result<()> {
    let mut config = HookConfig::load()?;

    // Validate hook name
    if config.get_hook_command(hook_name).is_none() {
        return Err(anyhow::anyhow!("Unknown hook: {}", hook_name));
    }

    config.enabled.insert(hook_name.to_string(), true);
    config.save()?;

    println!("✓ Enabled hook: {}", hook_name);
    Ok(())
}

/// Disable a hook
pub fn disable_hook(hook_name: &str) -> Result<()> {
    let mut config = HookConfig::load()?;
    config.enabled.insert(hook_name.to_string(), false);
    config.save()?;

    println!("✓ Disabled hook: {}", hook_name);
    Ok(())
}
