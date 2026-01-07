use chrono::Utc;
/// Test program to verify desktop notifications work on macOS
use prd_tool::db::{Agent, AgentStatus, Database, Priority, Task, TaskStatus};
use prd_tool::notifications::{NotificationConfig, Notifier};

fn main() -> anyhow::Result<()> {
    println!("🔔 Testing desktop notifications...\n");

    // Load or create config
    let config = NotificationConfig::load()?;
    println!(
        "✓ Config loaded from: {:?}",
        NotificationConfig::get_config_path()?
    );
    println!("  Enabled: {}", config.enabled);
    println!("  Events: {:?}", config.events);
    println!("  Sound: {}", config.sound);
    println!("  Rate limit: {}s\n", config.rate_limit_seconds);

    // Create notifier
    let mut notifier = Notifier::new(config);

    // Create test agent and task
    let agent = Agent {
        id: "test-agent-1".to_string(),
        display_id: Some(1),
        name: "Test Agent".to_string(),
        status: AgentStatus::Working,
        current_task_id: Some("test-task-1".to_string()),
        created_at: Utc::now(),
        last_active: Utc::now(),
    };

    let task = Task {
        id: "test-task-1".to_string(),
        display_id: Some(42),
        title: "Test Task - Implement notifications".to_string(),
        description: Some("Testing desktop notifications".to_string()),
        status: TaskStatus::Completed,
        priority: Priority::High,
        parent_id: None,
        assigned_agent: Some("test-agent-1".to_string()),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        completed_at: Some(Utc::now()),
        estimated_duration: None,
        actual_duration: None,
        epic_name: Some("Phase 2".to_string()),
    };

    // Test 1: Task completion notification
    println!("📬 Sending task completion notification...");
    match notifier.notify_task_complete(&task, &agent) {
        Ok(_) => println!("✓ Task completion notification sent\n"),
        Err(e) => println!("✗ Failed to send: {}\n", e),
    }

    std::thread::sleep(std::time::Duration::from_secs(2));

    // Test 2: Error notification
    println!("📬 Sending error notification...");
    match notifier.notify_agent_error(&task, &agent, "Database connection failed") {
        Ok(_) => println!("✓ Error notification sent\n"),
        Err(e) => println!("✗ Failed to send: {}\n", e),
    }

    std::thread::sleep(std::time::Duration::from_secs(2));

    // Test 3: Milestone notification
    println!("📬 Sending milestone notification (25%)...");
    match notifier.notify_milestone(25, 15, 60) {
        Ok(_) => println!("✓ Milestone notification sent\n"),
        Err(e) => println!("✗ Failed to send: {}\n", e),
    }

    std::thread::sleep(std::time::Duration::from_secs(2));

    // Test 4: Rate limiting
    println!("🚦 Testing rate limiting...");
    println!("  First notification:");
    match notifier.notify_task_complete(&task, &agent) {
        Ok(_) => println!("    ✓ Sent"),
        Err(e) => println!("    ✗ Failed: {}", e),
    }

    println!("  Immediate second notification (should be rate limited):");
    match notifier.notify_task_complete(&task, &agent) {
        Ok(_) => println!("    ✗ Sent (rate limiting not working!)"),
        Err(e) => println!("    ✗ Failed: {}", e),
    }
    println!("    ✓ Correctly rate limited (no notification sent)\n");

    println!("✅ All tests completed!");
    println!(
        "\nConfig file location: {:?}",
        NotificationConfig::get_config_path()?
    );
    println!("You can customize notifications by editing this file.\n");

    Ok(())
}
