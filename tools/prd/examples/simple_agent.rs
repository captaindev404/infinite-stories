/// Simple Agent Example
///
/// This example demonstrates how to use the PRD library as an autonomous agent.
///
/// To run:
/// ```bash
/// cargo run --example simple_agent
/// ```

use anyhow::Result;
use prd_tool::{PRDClient, Priority, TaskStatus};
use std::thread;
use std::time::Duration;

fn main() -> Result<()> {
    println!("🤖 Simple Agent Example");
    println!("=======================\n");

    // Initialize client
    let client = PRDClient::new("tools/prd.db")?;

    // Agent identification
    let agent_name = "simple-rust-agent";

    // Register agent (will succeed or already exist)
    match client.create_agent(agent_name.to_string()) {
        Ok(agent) => println!("✓ Agent registered: {}", agent.name),
        Err(_) => println!("✓ Agent already exists: {}", agent_name),
    }

    // Create a task
    println!("\n1️⃣ Creating task...");
    let task = client.create_task(
        "Process user data with Rust".to_string(),
        Some("Implement data processing pipeline using Rust".to_string()),
        Priority::High,
        None,
    )?;
    println!("   Created task: {} - {}", &task.id[..8], task.title);

    // Set estimated duration
    client.update_task_duration(&task.id, Some(60), None)?;
    println!("   Estimated: 60 minutes");

    // Start working
    println!("\n2️⃣ Starting work...");
    client.sync_agent(agent_name, &task.id)?;
    println!("   {} is now working on task {}", agent_name, &task.id[..8]);

    // Simulate work
    println!("\n3️⃣ Working...");
    for i in 1..=3 {
        thread::sleep(Duration::from_secs(1));
        println!("   Progress: {}%", i * 33);
    }

    // Set actual duration
    client.update_task_duration(&task.id, None, Some(45))?;
    println!("\n   Actual time: 45 minutes");

    // Complete task
    println!("\n4️⃣ Completing task...");
    client.complete_task(&task.id, agent_name)?;
    println!("   ✅ Task completed!");

    // Set agent to idle
    client.set_agent_idle(agent_name)?;
    println!("   Agent is now idle");

    // Show statistics
    println!("\n5️⃣ Statistics:");
    let stats = client.get_stats()?;
    println!("   Total tasks: {}", stats.total);
    println!("   Completed: {}", stats.completed);
    println!("   In progress: {}", stats.in_progress);

    if stats.total > 0 {
        let progress = (stats.completed as f32 / stats.total as f32) * 100.0;
        println!("   Progress: {:.1}%", progress);
    }

    println!("\n✅ Agent workflow complete!");
    Ok(())
}
