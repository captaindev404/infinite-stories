mod db;
mod db_extensions;
mod migrations;
mod resolver;

use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::*;
use db::{Database, Priority, TaskStatus, AgentStatus};
use db_extensions::{DependencyOps, AcceptanceCriteriaOps};
use migrations::MigrationRunner;
use resolver::{resolve_task_id, resolve_agent_id, format_task_id, format_agent_id};
use std::path::PathBuf;
use tabled::{Table, Tabled, settings::Style};

#[derive(Parser)]
#[command(name = "prd")]
#[command(about = "PRD Tool - Agent Task Management and Synchronization", long_about = None)]
struct Cli {
    #[arg(short, long, default_value = "tools/prd.db")]
    database: PathBuf,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new task
    Create {
        /// Task title
        title: String,
        /// Task description
        #[arg(short, long)]
        description: Option<String>,
        /// Priority (low, medium, high, critical)
        #[arg(short, long, default_value = "medium")]
        priority: String,
        /// Parent task ID
        #[arg(short = 'P', long)]
        parent: Option<String>,
        /// Epic name (group related tasks)
        #[arg(short, long)]
        epic: Option<String>,
    },

    /// List tasks
    List {
        /// Filter by status (pending, in_progress, blocked, review, completed, cancelled)
        #[arg(short, long)]
        status: Option<String>,
        /// Show subtasks
        #[arg(short = 'S', long)]
        subtasks: bool,
        /// Filter by epic name
        #[arg(short = 'E', long)]
        epic: Option<String>,
        /// Show only unassigned tasks
        #[arg(long)]
        no_agent: bool,
        /// Filter by priority
        #[arg(short = 'P', long)]
        priority: Option<String>,
    },

    /// Show task details
    Show {
        /// Task ID
        id: String,
        /// Show logs
        #[arg(short, long)]
        logs: bool,
    },

    /// Update task status
    Update {
        /// Task ID
        id: String,
        /// New status (pending, in_progress, blocked, review, completed, cancelled)
        status: String,
        /// Agent ID performing the update
        #[arg(short, long)]
        agent: Option<String>,
    },

    /// Break down a task into subtasks
    Breakdown {
        /// Parent task ID
        id: String,
        /// Number of subtasks to create interactively
        #[arg(short, long)]
        interactive: bool,
    },

    /// Assign a task to an agent
    Assign {
        /// Task ID
        task_id: String,
        /// Agent ID or name
        agent: String,
    },

    /// Create a new agent
    AgentCreate {
        /// Agent name
        name: String,
    },

    /// List all agents
    AgentList,

    /// Update agent status
    AgentStatus {
        /// Agent ID or name
        agent: String,
        /// New status (idle, working, blocked, offline)
        status: String,
        /// Current task ID (optional)
        #[arg(short, long)]
        task: Option<String>,
    },

    /// Sync agent work (mark current task as in progress)
    Sync {
        /// Agent ID or name
        agent: String,
        /// Task ID to work on
        task_id: String,
    },

    /// Show statistics
    Stats,

    /// List all epics with task counts
    Epics,

    /// Manage task dependencies
    Depends {
        /// Task ID
        task_id: String,
        /// Task this depends on
        #[arg(long)]
        on: Option<String>,
        /// Task this blocks
        #[arg(long)]
        blocks: Option<String>,
        /// List dependencies
        #[arg(long)]
        list: bool,
    },

    /// List tasks ready to work on (all dependencies completed)
    Ready,

    /// Manage acceptance criteria
    Ac {
        /// Task ID
        task_id: String,
        #[command(subcommand)]
        action: AcAction,
    },

    /// Set task duration estimates
    Duration {
        /// Task ID
        id: String,
        /// Estimated duration in minutes
        #[arg(short, long)]
        estimated: Option<i32>,
        /// Actual duration in minutes
        #[arg(short, long)]
        actual: Option<i32>,
    },

    /// Database migration commands
    Migrate {
        #[command(subcommand)]
        action: MigrateAction,
    },

    /// Initialize a new PRD database
    Init {
        /// Force re-initialization (drops existing data)
        #[arg(short, long)]
        force: bool,
    },
}

#[derive(Subcommand)]
enum MigrateAction {
    /// Run all pending migrations
    Latest,
    /// Show migration status
    Status,
    /// Rollback to a specific version
    Rollback {
        /// Target version to rollback to
        version: i32,
    },
}

#[derive(Subcommand)]
enum AcAction {
    /// Add acceptance criterion
    Add {
        /// Criterion text
        criterion: String,
    },
    /// List all acceptance criteria
    List,
    /// Mark criterion as completed
    Check {
        /// Criterion ID
        id: i32,
    },
    /// Mark criterion as incomplete
    Uncheck {
        /// Criterion ID
        id: i32,
    },
}

#[derive(Tabled)]
struct TaskRow {
    #[tabled(rename = "ID")]
    id: String,
    #[tabled(rename = "Title")]
    title: String,
    #[tabled(rename = "Status")]
    status: String,
    #[tabled(rename = "Priority")]
    priority: String,
    #[tabled(rename = "Agent")]
    agent: String,
    #[tabled(rename = "Created")]
    created: String,
}

#[derive(Tabled)]
struct AgentRow {
    #[tabled(rename = "ID")]
    id: String,
    #[tabled(rename = "Name")]
    name: String,
    #[tabled(rename = "Status")]
    status: String,
    #[tabled(rename = "Current Task")]
    current_task: String,
    #[tabled(rename = "Last Active")]
    last_active: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Handle Init command separately (before creating database)
    if matches!(cli.command, Commands::Init { .. }) {
        if let Commands::Init { force } = cli.command {
            use std::fs;
            use std::path::Path;

            let db_path = cli.database.to_str().unwrap();
            let path = Path::new(db_path);

            if path.exists() && !force {
                return Err(anyhow::anyhow!(
                    "Database already exists at {}. Use --force to reinitialize.",
                    db_path
                ));
            }

            if path.exists() && force {
                println!("{} Removing existing database...", "⚠".yellow());
                fs::remove_file(path)?;
            }

            println!("{} Creating new database at {}...", "✓".green(), db_path);

            // Create parent directories if needed
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }

            // Create and initialize database
            let new_db = Database::new(db_path)?;
            println!("{} Database schema initialized", "✓".green());

            // Run migrations
            let conn = new_db.get_connection();
            let runner = MigrationRunner::new(conn);
            println!("{} Running migrations...", "✓".green());
            let applied = runner.migrate_to_latest()?;
            println!("{} Applied {} migration(s)", "✓".green().bold(), applied.len());

            println!("\n{}", "Database initialized successfully!".green().bold());
            println!("You can now use:");
            println!("  prd create \"My first task\"");
            println!("  prd agent-create \"my-agent\"");

            return Ok(());
        }
    }

    let db = Database::new(cli.database.to_str().unwrap())?;

    match cli.command {
        Commands::Create {
            title,
            description,
            priority,
            parent,
            epic,
        } => {
            let priority = Priority::from_str(&priority);
            let task = db.create_task(title, description, priority.clone(), parent, epic)?;
            println!("{}", "✓ Task created successfully!".green().bold());
            let display_id = task.display_id.map(|id| format!("#{}", id)).unwrap_or_else(|| task.id[..8].to_string());
            println!("ID: {}", display_id.cyan());
            println!("Title: {}", task.title);
            println!("Priority: {}", priority.as_str().yellow());
            if let Some(epic_name) = &task.epic_name {
                println!("Epic: {}", epic_name.cyan());
            }
        }

        Commands::List { status, subtasks, epic, no_agent, priority } => {
            let status_filter = status.map(|s| TaskStatus::from_str(&s));
            let priority_filter = priority.map(|p| Priority::from_str(&p));
            let mut tasks = db.list_tasks(status_filter)?;

            // Apply additional filters
            if let Some(epic_name) = epic {
                tasks.retain(|t| t.epic_name.as_ref().map_or(false, |e| e == &epic_name));
            }
            if no_agent {
                tasks.retain(|t| t.assigned_agent.is_none());
            }
            if let Some(prio) = priority_filter {
                tasks.retain(|t| t.priority == prio);
            }

            if tasks.is_empty() {
                println!("{}", "No tasks found.".yellow());
                return Ok(());
            }

            let rows: Vec<TaskRow> = tasks
                .iter()
                .filter(|t| !subtasks || t.parent_id.is_none())
                .map(|t| TaskRow {
                    id: t.display_id.map(|id| format!("#{}", id)).unwrap_or_else(|| t.id[..8].to_string()),
                    title: if t.title.len() > 40 {
                        format!("{}...", &t.title[..37])
                    } else {
                        t.title.clone()
                    },
                    status: format_status(&t.status),
                    priority: format_priority(&t.priority),
                    agent: t
                        .assigned_agent
                        .as_ref()
                        .and_then(|uuid| {
                            // Try to get agent display_id
                            db.get_agent(uuid).ok().flatten().and_then(|a| a.display_id.map(|id| format!("A{}", id)))
                        })
                        .unwrap_or_else(|| "-".to_string()),
                    created: t.created_at.format("%Y-%m-%d %H:%M").to_string(),
                })
                .collect();

            let mut table = Table::new(rows);
            table.with(Style::modern());
            println!("{}", table);
            println!("\n{} tasks total", tasks.len().to_string().cyan().bold());
        }

        Commands::Show { id, logs } => {
            // Resolve ID (supports #42, 42, or UUID)
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            let task = db.get_task(&task_uuid)?;
            match task {
                Some(t) => {
                    println!("\n{}", "Task Details".bold().underline());
                    let display_id = t.display_id.map(|id| format!("#{}", id)).unwrap_or_else(|| t.id[..8].to_string());
                    println!("ID: {}", display_id.cyan());
                    println!("Title: {}", t.title.bold());
                    if let Some(desc) = &t.description {
                        println!("Description: {}", desc);
                    }
                    println!("Status: {}", format_status(&t.status));
                    println!("Priority: {}", format_priority(&t.priority));
                    if let Some(epic) = &t.epic_name {
                        println!("Epic: {}", epic.cyan());
                    }
                    if let Some(agent_uuid) = &t.assigned_agent {
                        let agent_display = db.get_agent(agent_uuid)
                            .ok()
                            .flatten()
                            .and_then(|a| a.display_id.map(|id| format!("A{} ({})", id, a.name)))
                            .unwrap_or_else(|| agent_uuid[..8].to_string());
                        println!("Assigned to: {}", agent_display.cyan());
                    }
                    if let Some(parent) = &t.parent_id {
                        let parent_display = db.get_task(parent)
                            .ok()
                            .flatten()
                            .and_then(|p| p.display_id.map(|id| format!("#{}", id)))
                            .unwrap_or_else(|| parent[..8].to_string());
                        println!("Parent task: {}", parent_display.cyan());
                    }
                    if let Some(est) = t.estimated_duration {
                        println!("Estimated duration: {} minutes", est);
                    }
                    if let Some(act) = t.actual_duration {
                        println!("Actual duration: {} minutes", act);
                    }
                    println!("Created: {}", t.created_at.format("%Y-%m-%d %H:%M:%S"));
                    println!("Updated: {}", t.updated_at.format("%Y-%m-%d %H:%M:%S"));
                    if let Some(completed) = t.completed_at {
                        println!("Completed: {}", completed.format("%Y-%m-%d %H:%M:%S").to_string().green());
                    }

                    // Show subtasks
                    let subtasks = db.get_subtasks(&t.id)?;
                    if !subtasks.is_empty() {
                        println!("\n{}", "Subtasks:".bold());
                        for (i, st) in subtasks.iter().enumerate() {
                            let st_id = st.display_id.map(|id| format!("#{}", id)).unwrap_or_else(|| st.id[..8].to_string());
                            println!(
                                "  {}. {} ({}) - {}",
                                i + 1,
                                st.title,
                                st_id,
                                format_status(&st.status)
                            );
                        }
                    }

                    // Show logs if requested
                    if logs {
                        let task_logs = db.get_task_logs(&t.id)?;
                        if !task_logs.is_empty() {
                            println!("\n{}", "Activity Log:".bold());
                            for log in task_logs {
                                println!(
                                    "  {} - {} {}",
                                    log.created_at.format("%Y-%m-%d %H:%M:%S").to_string().dimmed(),
                                    log.action.cyan(),
                                    log.details.unwrap_or_default()
                                );
                            }
                        }
                    }
                }
                None => {
                    println!("{}", "Task not found.".red());
                }
            }
        }

        Commands::Update { id, status, agent } => {
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            let status_enum = TaskStatus::from_str(&status);
            db.update_task_status(&task_uuid, status_enum.clone(), agent.as_deref())?;
            let display_id = format_task_id(db.get_connection(), &task_uuid);
            println!("{} Task {} updated to {}", "✓".green().bold(), display_id.cyan(), status_enum.as_str());
        }

        Commands::Breakdown { id, interactive } => {
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            let task = db.get_task(&task_uuid)?;
            match task {
                Some(t) => {
                    println!("Breaking down task: {}", t.title.bold());

                    if interactive {
                        use dialoguer::{Input, Confirm};

                        loop {
                            let subtask_title: String = Input::new()
                                .with_prompt("Subtask title (or empty to finish)")
                                .allow_empty(true)
                                .interact_text()?;

                            if subtask_title.is_empty() {
                                break;
                            }

                            let description: String = Input::new()
                                .with_prompt("Description (optional)")
                                .allow_empty(true)
                                .interact_text()?;

                            let priority_str: String = Input::new()
                                .with_prompt("Priority (low/medium/high/critical)")
                                .default("medium".to_string())
                                .interact_text()?;

                            let priority = Priority::from_str(&priority_str);
                            let desc = if description.is_empty() { None } else { Some(description) };

                            let subtask = db.create_task(subtask_title, desc, priority, Some(task_uuid.clone()), None)?;
                            let subtask_display = subtask.display_id.map(|id| format!("#{}", id)).unwrap_or_else(|| subtask.id[..8].to_string());
                            println!("{} Created subtask: {}", "✓".green(), subtask_display.cyan());

                            let continue_adding = Confirm::new()
                                .with_prompt("Add another subtask?")
                                .default(true)
                                .interact()?;

                            if !continue_adding {
                                break;
                            }
                        }
                    } else {
                        let task_display = format_task_id(db.get_connection(), &task_uuid);
                        println!("Use --interactive to add subtasks interactively");
                        println!("Or use: prd create --parent {} <title>", task_display);
                    }

                    let subtasks = db.get_subtasks(&task_uuid)?;
                    println!("\n{} {} subtasks created", "✓".green().bold(), subtasks.len());
                }
                None => {
                    println!("{}", "Task not found.".red());
                }
            }
        }

        Commands::Assign { task_id, agent } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;

            // Try to find agent by ID or name (resolver handles both)
            let agent_uuid_result = resolve_agent_id(db.get_connection(), &agent);
            let agent_obj = if let Ok(agent_uuid) = agent_uuid_result {
                db.get_agent(&agent_uuid)?
            } else {
                None
            };

            match agent_obj {
                Some(a) => {
                    db.assign_task(&task_uuid, &a.id)?;
                    let task_display = format_task_id(db.get_connection(), &task_uuid);
                    let agent_display = format_agent_id(db.get_connection(), &a.id);
                    println!("{} Task {} assigned to {} ({})", "✓".green().bold(), task_display.cyan(), agent_display.cyan(), a.name);
                }
                None => {
                    println!("{} Agent not found. Creating new agent...", "⚠".yellow());
                    let new_agent = db.create_agent(agent.clone())?;
                    db.assign_task(&task_uuid, &new_agent.id)?;
                    let task_display = format_task_id(db.get_connection(), &task_uuid);
                    let agent_display = format_agent_id(db.get_connection(), &new_agent.id);
                    println!("{} Task {} assigned to new agent {} ({})", "✓".green().bold(), task_display.cyan(), agent_display.cyan(), new_agent.name);
                }
            }
        }

        Commands::AgentCreate { name } => {
            let agent = db.create_agent(name)?;
            println!("{}", "✓ Agent created successfully!".green().bold());
            let display_id = agent.display_id.map(|id| format!("A{}", id)).unwrap_or_else(|| agent.id[..8].to_string());
            println!("ID: {}", display_id.cyan());
            println!("Name: {}", agent.name);
        }

        Commands::AgentList => {
            let agents = db.list_agents()?;

            if agents.is_empty() {
                println!("{}", "No agents found.".yellow());
                return Ok(());
            }

            let rows: Vec<AgentRow> = agents
                .iter()
                .map(|a| AgentRow {
                    id: a.display_id.map(|id| format!("A{}", id)).unwrap_or_else(|| a.id[..8].to_string()),
                    name: a.name.clone(),
                    status: format_agent_status(&a.status),
                    current_task: a
                        .current_task_id
                        .as_ref()
                        .and_then(|uuid| {
                            db.get_task(uuid).ok().flatten().and_then(|t| t.display_id.map(|id| format!("#{}", id)))
                        })
                        .unwrap_or_else(|| "-".to_string()),
                    last_active: a.last_active.format("%Y-%m-%d %H:%M").to_string(),
                })
                .collect();

            let mut table = Table::new(rows);
            table.with(Style::modern());
            println!("{}", table);
            println!("\n{} agents total", agents.len().to_string().cyan().bold());
        }

        Commands::AgentStatus { agent, status, task } => {
            let agent_uuid = resolve_agent_id(db.get_connection(), &agent)?;
            let agent_obj = db.get_agent(&agent_uuid)?;

            match agent_obj {
                Some(a) => {
                    let task_uuid = if let Some(task_id) = task {
                        Some(resolve_task_id(db.get_connection(), &task_id)?)
                    } else {
                        None
                    };
                    let status = AgentStatus::from_str(&status);
                    db.update_agent_status(&a.id, status, task_uuid.as_deref())?;
                    let agent_display = format_agent_id(db.get_connection(), &a.id);
                    println!("{} Agent {} status updated!", "✓".green().bold(), agent_display.cyan());
                }
                None => {
                    println!("{}", "Agent not found.".red());
                }
            }
        }

        Commands::Sync { agent, task_id } => {
            let agent_uuid = resolve_agent_id(db.get_connection(), &agent)?;
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let agent_obj = db.get_agent(&agent_uuid)?;

            match agent_obj {
                Some(a) => {
                    // Update agent to working status
                    db.update_agent_status(&a.id, AgentStatus::Working, Some(&task_uuid))?;
                    // Update task to in_progress
                    db.update_task_status(&task_uuid, TaskStatus::InProgress, Some(&a.id))?;
                    // Assign task if not already assigned
                    db.assign_task(&task_uuid, &a.id)?;

                    let agent_display = format_agent_id(db.get_connection(), &a.id);
                    let task_display = format_task_id(db.get_connection(), &task_uuid);
                    println!("{}", "✓ Agent synchronized!".green().bold());
                    println!("Agent {} ({}) is now working on task {}", agent_display.cyan(), a.name, task_display.cyan());
                }
                None => {
                    println!("{}", "Agent not found.".red());
                }
            }
        }

        Commands::Stats => {
            let stats = db.get_stats()?;

            println!("\n{}", "Task Statistics".bold().underline());
            println!("Total tasks: {}", stats.total.to_string().cyan().bold());
            println!("  {} Pending: {}", "○".white(), stats.pending);
            println!("  {} In Progress: {}", "◐".blue(), stats.in_progress);
            println!("  {} Blocked: {}", "■".red(), stats.blocked);
            println!("  {} Review: {}", "◇".yellow(), stats.review);
            println!("  {} Completed: {}", "●".green(), stats.completed);
            println!("  {} Cancelled: {}", "✕".dimmed(), stats.cancelled);

            if stats.total > 0 {
                let progress = (stats.completed as f32 / stats.total as f32) * 100.0;
                println!("\nProgress: {:.1}%", progress);

                // Simple progress bar
                let bar_length = 40;
                let filled = ((progress / 100.0) * bar_length as f32) as usize;
                let bar = "█".repeat(filled) + &"░".repeat(bar_length - filled);
                println!("{}", bar.green());
            }
        }

        Commands::Epics => {
            // Get all tasks and group by epic
            let all_tasks = db.list_tasks(None)?;
            let mut epic_counts: std::collections::HashMap<String, (i32, i32)> = std::collections::HashMap::new();

            for task in &all_tasks {
                if let Some(epic) = &task.epic_name {
                    let entry = epic_counts.entry(epic.clone()).or_insert((0, 0));
                    entry.0 += 1;
                    if task.status == TaskStatus::Completed {
                        entry.1 += 1;
                    }
                }
            }

            if epic_counts.is_empty() {
                println!("{}", "No epics found.".yellow());
                return Ok(());
            }

            println!("\n{}", "Epics".bold().underline());
            let mut epic_list: Vec<_> = epic_counts.iter().collect();
            epic_list.sort_by(|a, b| a.0.cmp(b.0));

            for (epic_name, (total, completed)) in epic_list {
                let progress = if *total > 0 {
                    (*completed as f32 / *total as f32) * 100.0
                } else {
                    0.0
                };
                println!(
                    "{} - {}/{} tasks ({:.0}%)",
                    epic_name.cyan().bold(),
                    completed,
                    total,
                    progress
                );
            }
        }

        Commands::Depends { task_id, on, blocks, list } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db.get_task(&task_uuid)?.ok_or_else(|| anyhow::anyhow!("Task not found"))?;
            let task_display_id = task.display_id.ok_or_else(|| anyhow::anyhow!("Task missing display_id"))?;

            if list {
                let deps = db.get_connection().get_dependencies(task_display_id)?;
                let blocking = db.get_connection().get_blocking_tasks(task_display_id)?;

                println!("\nDependencies for task #{}", task_display_id);
                println!("Title: {}", task.title.bold());

                if !deps.is_empty() {
                    println!("\nDepends on:");
                    for dep_id in deps {
                        println!("  #{}", dep_id);
                    }
                } else {
                    println!("\nNo dependencies");
                }

                if !blocking.is_empty() {
                    println!("\nBlocks:");
                    for block_id in blocking {
                        println!("  #{}", block_id);
                    }
                }
            } else if let Some(depends_on_input) = on {
                let depends_on_uuid = resolve_task_id(db.get_connection(), &depends_on_input)?;
                let depends_on_task = db.get_task(&depends_on_uuid)?.ok_or_else(|| anyhow::anyhow!("Dependency task not found"))?;
                let depends_on_id = depends_on_task.display_id.ok_or_else(|| anyhow::anyhow!("Dependency task missing display_id"))?;

                db.get_connection().add_dependency(task_display_id, depends_on_id, "blocks")?;
                println!("{} Task #{} now depends on #{}", "✓".green().bold(), task_display_id, depends_on_id);
            } else if let Some(blocks_input) = blocks {
                let blocks_uuid = resolve_task_id(db.get_connection(), &blocks_input)?;
                let blocks_task = db.get_task(&blocks_uuid)?.ok_or_else(|| anyhow::anyhow!("Blocked task not found"))?;
                let blocks_id = blocks_task.display_id.ok_or_else(|| anyhow::anyhow!("Blocked task missing display_id"))?;

                db.get_connection().add_dependency(blocks_id, task_display_id, "blocks")?;
                println!("{} Task #{} now blocks #{}", "✓".green().bold(), task_display_id, blocks_id);
            } else {
                println!("Use --on <task-id>, --blocks <task-id>, or --list");
            }
        }

        Commands::Ready => {
            let ready_ids = db.get_connection().get_ready_tasks()?;

            if ready_ids.is_empty() {
                println!("{}", "No tasks ready (all have pending dependencies).".yellow());
                return Ok(());
            }

            println!("\n{}", "Tasks Ready to Work On".bold().underline());
            for task_id in &ready_ids {
                // Get full task details
                let task_result: Result<_, rusqlite::Error> = db.get_connection().query_row(
                    "SELECT id FROM tasks WHERE display_id = ?1",
                    [task_id],
                    |row| row.get::<_, String>(0),
                );
                if let Ok(uuid) = task_result {
                    if let Ok(Some(task)) = db.get_task(&uuid) {
                        println!(
                            "#{} - {} [{}]",
                            task_id,
                            task.title,
                            format_priority(&task.priority)
                        );
                    }
                }
            }
            println!("\n{} tasks ready", ready_ids.len().to_string().cyan().bold());
        }

        Commands::Ac { task_id, action } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db.get_task(&task_uuid)?.ok_or_else(|| anyhow::anyhow!("Task not found"))?;
            let task_display_id = task.display_id.ok_or_else(|| anyhow::anyhow!("Task missing display_id"))?;

            match action {
                AcAction::Add { criterion } => {
                    let ac_id = db.get_connection().add_criterion(task_display_id, criterion.clone())?;
                    println!("{} Added acceptance criterion #{}", "✓".green().bold(), ac_id);
                }
                AcAction::List => {
                    let criteria = db.get_connection().list_criteria(task_display_id)?;

                    if criteria.is_empty() {
                        println!("{}", "No acceptance criteria defined.".yellow());
                        return Ok(());
                    }

                    println!("\nAcceptance Criteria for #{} - {}", task_display_id, task.title.bold());
                    for (i, ac) in criteria.iter().enumerate() {
                        let checkbox = if ac.completed { "☑" } else { "☐" };
                        println!("  {}. {} {}", i + 1, checkbox, ac.criterion);
                    }

                    let completed_count = criteria.iter().filter(|ac| ac.completed).count();
                    println!("\n{}/{} criteria met", completed_count, criteria.len());
                }
                AcAction::Check { id } => {
                    db.get_connection().check_criterion(id)?;
                    println!("{} Criterion #{} marked as completed", "✓".green().bold(), id);
                }
                AcAction::Uncheck { id } => {
                    db.get_connection().uncheck_criterion(id)?;
                    println!("{} Criterion #{} marked as incomplete", "✓".green().bold(), id);
                }
            }
        }

        Commands::Duration { id, estimated, actual } => {
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            db.update_task_duration(&task_uuid, estimated, actual)?;
            let display_id = format_task_id(db.get_connection(), &task_uuid);
            println!("{} Task {} duration updated!", "✓".green().bold(), display_id.cyan());
        }

        Commands::Migrate { action } => {
            let conn = db.get_connection();
            let runner = MigrationRunner::new(conn);

            match action {
                MigrateAction::Latest => {
                    println!("{}", "Running migrations...".cyan());
                    let applied = runner.migrate_to_latest()?;
                    if applied.is_empty() {
                        println!("{}", "Already up to date!".green());
                    } else {
                        println!("\n{} Applied {} migration(s)", "✓".green().bold(), applied.len());
                    }
                }
                MigrateAction::Status => {
                    runner.status()?;
                }
                MigrateAction::Rollback { version } => {
                    runner.rollback(version)?;
                }
            }
        }

        Commands::Init { .. } => {
            // Handled earlier in main() before database creation
            unreachable!("Init command should be handled before match statement")
        }
    }

    Ok(())
}

fn format_status(status: &TaskStatus) -> String {
    match status {
        TaskStatus::Pending => "○ Pending".white().to_string(),
        TaskStatus::InProgress => "◐ In Progress".blue().bold().to_string(),
        TaskStatus::Blocked => "■ Blocked".red().bold().to_string(),
        TaskStatus::Review => "◇ Review".yellow().to_string(),
        TaskStatus::Completed => "● Completed".green().bold().to_string(),
        TaskStatus::Cancelled => "✕ Cancelled".dimmed().to_string(),
    }
}

fn format_priority(priority: &Priority) -> String {
    match priority {
        Priority::Low => "Low".dimmed().to_string(),
        Priority::Medium => "Medium".normal().to_string(),
        Priority::High => "High".yellow().bold().to_string(),
        Priority::Critical => "Critical".red().bold().to_string(),
    }
}

fn format_agent_status(status: &AgentStatus) -> String {
    match status {
        AgentStatus::Idle => "Idle".dimmed().to_string(),
        AgentStatus::Working => "Working".green().bold().to_string(),
        AgentStatus::Blocked => "Blocked".red().to_string(),
        AgentStatus::Offline => "Offline".dimmed().to_string(),
    }
}
