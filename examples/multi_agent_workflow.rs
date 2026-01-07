/// Multi-Agent Workflow Example
///
/// This example demonstrates a complete workflow with multiple agents
/// working on a parent task broken down into subtasks.
///
/// To run:
/// ```bash
/// cargo run --example multi_agent_workflow
/// ```
use anyhow::Result;
use prd_tool::{AgentStatus, PRDClient, Priority, TaskStatus};
use std::thread;
use std::time::Duration;

struct Agent<'a> {
    name: &'a str,
    client: &'a PRDClient,
}

impl<'a> Agent<'a> {
    fn new(name: &'a str, client: &'a PRDClient) -> Result<Self> {
        // Create agent if doesn't exist
        match client.create_agent(name.to_string()) {
            Ok(_) => println!("  ✓ Agent '{}' registered", name),
            Err(_) => println!("  ✓ Agent '{}' already exists", name),
        }
        Ok(Agent { name, client })
    }

    fn work_on_task(&self, task_id: &str, duration_secs: u64) -> Result<()> {
        println!("  🔄 {} starting task {}", self.name, &task_id[..8]);

        // Start work
        self.client.sync_agent(self.name, task_id)?;

        // Simulate work
        thread::sleep(Duration::from_secs(duration_secs));

        // Complete
        self.client.complete_task(task_id, self.name)?;
        println!("  ✅ {} completed task {}", self.name, &task_id[..8]);

        Ok(())
    }

    fn work_on_next_task(&self, duration_secs: u64) -> Result<bool> {
        if let Some(task) = self.client.get_next_task(None)? {
            self.work_on_task(&task.id, duration_secs)?;
            Ok(true)
        } else {
            println!("  ⚠️  {} found no tasks to work on", self.name);
            Ok(false)
        }
    }
}

fn main() -> Result<()> {
    println!("🤖 Multi-Agent Workflow Example");
    println!("================================\n");

    // Initialize client
    let client = PRDClient::new("tools/prd.db")?;

    // 1. Create main task
    println!("1️⃣ Creating main task...");
    let main_task = client.create_task(
        "Migrate backend to Firebase".to_string(),
        Some("Complete migration from Supabase to Firebase".to_string()),
        Priority::Critical,
        None,
    )?;
    println!("  Created: {} - {}\n", &main_task.id[..8], main_task.title);

    // 2. Break down into subtasks
    println!("2️⃣ Creating subtasks...");
    let subtasks = vec![
        ("Setup Firebase project", Priority::Critical),
        ("Migrate authentication", Priority::High),
        ("Migrate database schema", Priority::High),
        ("Update client SDKs", Priority::Medium),
        ("Deploy and test", Priority::Critical),
    ];

    let mut subtask_ids = Vec::new();
    for (title, priority) in subtasks {
        let subtask = client.create_task(
            title.to_string(),
            None,
            priority,
            Some(main_task.id.clone()),
        )?;
        println!("  ✓ Subtask: {}", title);
        subtask_ids.push(subtask.id);
    }
    println!();

    // 3. Create agents
    println!("3️⃣ Registering agents...");
    let agent1 = Agent::new("firebase-setup-agent", &client)?;
    let agent2 = Agent::new("migration-agent", &client)?;
    let agent3 = Agent::new("qa-agent", &client)?;
    println!();

    // 4. Agents work on tasks
    println!("4️⃣ Agents working on tasks...\n");

    // Agent 1 works on first task
    agent1.work_on_task(&subtask_ids[0], 1)?;

    // Agent 2 and Agent 1 work in "parallel" (sequentially for demo)
    agent2.work_on_task(&subtask_ids[1], 1)?;
    agent1.work_on_task(&subtask_ids[2], 1)?;

    // Agent 2 picks up next available task
    println!("\n  Agent 2 looking for next task...");
    agent2.work_on_next_task(1)?;

    // QA agent picks up final task
    println!("\n  QA agent looking for critical tasks...");
    if let Some(task) = client.get_next_task(Some(Priority::Critical))? {
        agent3.work_on_task(&task.id, 2)?;
    }

    println!();

    // 5. Mark main task as completed
    println!("5️⃣ Finalizing...");
    client.update_task_status(&main_task.id, TaskStatus::Completed, None)?;
    println!("  ✅ Main task completed!\n");

    // 6. Show results
    println!("6️⃣ Final Statistics:");
    let stats = client.get_stats()?;
    println!("  Total tasks: {}", stats.total);
    println!("  Pending: {}", stats.pending);
    println!("  In progress: {}", stats.in_progress);
    println!("  Completed: {}", stats.completed);

    if stats.total > 0 {
        let progress = (stats.completed as f32 / stats.total as f32) * 100.0;
        println!("  Progress: {:.1}%", progress);
    }

    println!("\n  Subtask breakdown:");
    let subtasks = client.get_subtasks(&main_task.id)?;
    for subtask in subtasks {
        let status = match subtask.status {
            TaskStatus::Completed => "✅",
            TaskStatus::InProgress => "🔄",
            TaskStatus::Pending => "⏳",
            TaskStatus::Blocked => "🚫",
            _ => "❓",
        };
        println!("    {} {} - {:?}", status, subtask.title, subtask.status);
    }

    // 7. Show agent status
    println!("\n  Agent status:");
    let agents = client.list_agents()?;
    for agent in agents.iter().filter(|a| {
        a.name == "firebase-setup-agent" || a.name == "migration-agent" || a.name == "qa-agent"
    }) {
        let status_icon = match agent.status {
            AgentStatus::Idle => "💤",
            AgentStatus::Working => "⚡",
            AgentStatus::Blocked => "🚫",
            AgentStatus::Offline => "📴",
        };
        println!("    {} {} - {:?}", status_icon, agent.name, agent.status);
    }

    println!("\n✅ Multi-agent workflow complete!");
    println!("\nTo see the dashboard, run:");
    println!("  cargo run --bin prd-dashboard\n");

    Ok(())
}
