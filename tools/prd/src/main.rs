mod batch;
mod db;
mod db_extensions;
mod migrations;
mod resolver;
mod sync;
mod vectors;

use anyhow::Result;
use chrono::{DateTime, NaiveDate, Utc};
use clap::{Parser, Subcommand};
use colored::*;
use db::{AgentStatus, Database, Priority, TaskStatus};
use db_extensions::{AcceptanceCriteriaOps, DependencyOps};
use migrations::MigrationRunner;
use resolver::{format_agent_id, format_task_id, resolve_agent_id, resolve_task_id};
use std::path::PathBuf;
use tabled::{settings::Style, Table, Tabled};

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
    #[command(alias = "ls", alias = "tasks")]
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
        /// Filter by agent (ID or name)
        #[arg(short = 'A', long)]
        agent: Option<String>,
        /// Limit number of results
        #[arg(short = 'L', long)]
        limit: Option<usize>,
        /// Offset for pagination
        #[arg(short = 'O', long)]
        offset: Option<usize>,
        /// Output as JSON
        #[arg(long)]
        json: bool,
    },

    /// Show task details
    Show {
        /// Task ID
        id: String,
        /// Show logs
        #[arg(short, long)]
        logs: bool,
        /// Show progress history
        #[arg(short, long)]
        progress: bool,
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
    #[command(alias = "create-agent")]
    AgentCreate {
        /// Agent name
        name: String,
    },

    /// List all agents
    #[command(alias = "agents", alias = "list-agents")]
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
    Stats {
        /// Show visual progress timelines
        #[arg(short, long)]
        visual: bool,
        /// Output as JSON
        #[arg(long)]
        json: bool,
    },

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

    /// Complete a task (shortcut for update completed + agent sync)
    Complete {
        /// Task ID
        task_id: String,
        /// Agent completing the task (optional, uses assigned agent)
        #[arg(short, long)]
        agent: Option<String>,
    },

    /// Cancel a task (shortcut for update cancelled)
    Cancel {
        /// Task ID
        task_id: String,
        /// Reason for cancellation (optional)
        #[arg(short, long)]
        reason: Option<String>,
    },

    /// Get the next task to work on (smart selection)
    Next {
        /// Filter by priority
        #[arg(short, long)]
        priority: Option<String>,
        /// Filter by epic
        #[arg(short, long)]
        epic: Option<String>,
        /// Auto-assign to agent
        #[arg(short, long)]
        agent: Option<String>,
        /// Auto-sync agent to task
        #[arg(long)]
        sync: bool,
    },

    /// Update multiple tasks at once
    BatchUpdate {
        /// Comma-separated task IDs (e.g., "#1,#2,#3")
        task_ids: String,
        /// New status
        status: String,
        #[arg(short, long)]
        agent: Option<String>,
    },

    /// Assign multiple tasks to an agent
    BatchAssign {
        /// Comma-separated task IDs (e.g., "#1,#2,#3")
        task_ids: String,
        /// Agent ID or name
        agent: String,
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

    /// Complete multiple tasks at once (batch operation)
    CompleteBatch {
        /// Comma-separated task IDs (e.g., "33,34,35")
        #[arg(long, conflicts_with_all = ["from_file", "from_csv"])]
        tasks: Option<String>,

        /// Agent mapping (e.g., "33:A11,34:A11,35:A12")
        #[arg(long, requires = "tasks")]
        agent_map: Option<String>,

        /// JSON file path
        #[arg(long, conflicts_with = "from_csv")]
        from_file: Option<PathBuf>,

        /// CSV file path
        #[arg(long, conflicts_with = "from_file")]
        from_csv: Option<PathBuf>,
    },

    /// Automatically sync task completions from documentation
    SyncDocs {
        /// Sync from git commit history instead of files
        #[arg(long)]
        from_git: bool,

        /// Only sync commits since this date (ISO 8601: 2025-10-01)
        #[arg(long, requires = "from_git")]
        since: Option<String>,

        /// Only sync commits until this date (ISO 8601: 2025-10-13)
        #[arg(long, requires = "from_git")]
        until: Option<String>,

        /// Sync from specific branch
        #[arg(long, requires = "from_git")]
        branch: Option<String>,

        /// Preview changes without applying them
        #[arg(long)]
        dry_run: bool,

        /// Custom docs directory (default: docs/tasks)
        #[arg(short, long, default_value = "docs/tasks")]
        docs_dir: PathBuf,
    },

    /// Reconcile database with filesystem (detect and fix inconsistencies)
    Reconcile {
        /// Apply fixes without confirmation
        #[arg(long)]
        auto_fix: bool,

        /// Custom docs directory (default: docs/tasks)
        #[arg(short, long, default_value = "docs/tasks")]
        docs_dir: PathBuf,

        /// Create backup before applying fixes
        #[arg(long)]
        backup: bool,
    },

    /// Report agent progress on a task
    ReportProgress {
        /// Agent ID or name (e.g., "A12" or "agent-name")
        agent: String,
        /// Task display ID (e.g., "37" or "#37")
        task_id: String,
        /// Progress percentage (0-100)
        progress: u8,
        /// Optional progress message
        message: Option<String>,
    },

    /// Live dashboard with real-time agent progress
    #[command(alias = "dashboard")]
    Watch {
        /// Refresh interval in seconds
        #[arg(long, default_value = "2")]
        refresh_interval: u64,
    },

    /// Install or uninstall git hook for auto-completion
    InstallGitHook {
        /// Uninstall the hook
        #[arg(long)]
        uninstall: bool,

        /// Show hook status
        #[arg(long)]
        status: bool,
    },

    /// Manage hook system
    Hooks {
        #[command(subcommand)]
        subcommand: HooksSubcommand,
    },

    /// Watch docs/tasks directory for completion documents
    WatchFiles {
        /// Run as background daemon
        #[arg(long)]
        daemon: bool,

        /// Show daemon status
        #[arg(long)]
        status: bool,

        /// Stop daemon
        #[arg(long)]
        stop: bool,

        /// Path to docs directory
        #[arg(long, default_value = "docs/tasks")]
        docs_path: PathBuf,

        /// Run in daemon mode (internal flag)
        #[arg(long, hide = true)]
        daemon_mode: bool,
    },

    /// Semantic vector search and indexing
    #[command(alias = "vec")]
    Vector {
        #[command(subcommand)]
        action: VectorCommands,
    },
}

#[derive(Subcommand)]
enum VectorCommands {
    /// Index content for semantic search
    Index {
        /// What to index: tasks, code, docs, all
        #[arg(default_value = "all")]
        content: String,
        /// Directory to index (for code/docs)
        #[arg(short, long)]
        path: Option<PathBuf>,
        /// File patterns to include (e.g., "*.rs", "*.ts")
        #[arg(short = 'i', long = "include")]
        patterns: Vec<String>,
        /// Force re-index everything
        #[arg(long)]
        force: bool,
    },

    /// Semantic search across indexed content
    Search {
        /// Search query
        query: String,
        /// Filter by type: tasks, code, docs
        #[arg(short, long)]
        r#type: Option<String>,
        /// Number of results
        #[arg(short, long, default_value = "10")]
        limit: usize,
        /// Minimum similarity threshold (0.0-1.0)
        #[arg(long, default_value = "0.5")]
        threshold: f32,
    },

    /// Find similar content to a task
    Similar {
        /// Task ID to find similar content for
        task_id: String,
        /// Include code matches
        #[arg(long)]
        code: bool,
        /// Include doc matches
        #[arg(long)]
        docs: bool,
        /// Number of results
        #[arg(short, long, default_value = "5")]
        limit: usize,
    },

    /// Show indexing statistics
    Stats,

    /// Clear all vector indexes
    Clear {
        /// Type to clear: tasks, code, docs, all
        content: Option<String>,
    },
}

#[derive(Subcommand)]
enum HooksSubcommand {
    /// Initialize hooks configuration with examples
    Init,

    /// List all configured hooks
    List,

    /// Test a hook without side effects
    Test {
        /// Hook name (e.g., on_task_complete)
        hook_name: String,

        /// Task ID for testing
        #[arg(long)]
        task_id: Option<String>,

        /// Agent ID for testing
        #[arg(long)]
        agent_id: Option<String>,
    },

    /// Enable a hook
    Enable {
        /// Hook name
        hook_name: String,
    },

    /// Disable a hook
    Disable {
        /// Hook name
        hook_name: String,
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
    // Ignore SIGPIPE to handle broken pipes gracefully (e.g., when piping to head)
    #[cfg(unix)]
    {
        use std::io::{Error, ErrorKind};
        unsafe {
            // Set SIGPIPE handler to default (terminate silently)
            libc::signal(libc::SIGPIPE, libc::SIG_DFL);
        }
    }

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

            // Mark migrations that are already in base schema as applied
            let conn = new_db.get_connection();
            let runner = MigrationRunner::new(conn);
            runner.init()?;

            // Mark all migrations 001-007 as applied (base schema includes all features)
            let base_schema_migrations = vec![1, 2, 3, 4, 5, 6, 7];
            for version in base_schema_migrations {
                conn.execute(
                    "INSERT OR IGNORE INTO schema_migrations (version, applied_at) VALUES (?1, datetime('now'))",
                    [version],
                )?;
            }

            // Check for and run any new migrations beyond 007
            println!("{} Running migrations...", "✓".green());
            let applied = runner.migrate_to_latest()?;
            println!(
                "{} Applied {} migration(s)",
                "✓".green().bold(),
                applied.len()
            );

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
            let display_id = task
                .display_id
                .map(|id| format!("#{}", id))
                .unwrap_or_else(|| task.id[..8].to_string());
            println!("ID: {}", display_id.cyan());
            println!("Title: {}", task.title);
            println!("Priority: {}", priority.as_str().yellow());
            if let Some(epic_name) = &task.epic_name {
                println!("Epic: {}", epic_name.cyan());
            }
        }

        Commands::List {
            status,
            subtasks,
            epic,
            no_agent,
            priority,
            agent,
            limit,
            offset,
            json,
        } => {
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
            if let Some(agent_filter) = agent {
                // Try to resolve agent ID
                let agent_uuid_result = resolve_agent_id(db.get_connection(), &agent_filter);
                if let Ok(agent_uuid) = agent_uuid_result {
                    tasks.retain(|t| {
                        t.assigned_agent
                            .as_ref()
                            .map_or(false, |a| a == &agent_uuid)
                    });
                } else {
                    // If resolution fails, no matches
                    tasks.clear();
                }
            }

            // Apply pagination
            let total_count = tasks.len();
            let offset_val = offset.unwrap_or(0);
            if offset_val > 0 && offset_val < tasks.len() {
                tasks = tasks.into_iter().skip(offset_val).collect();
            } else if offset_val >= tasks.len() {
                tasks.clear();
            }
            if let Some(limit_val) = limit {
                tasks.truncate(limit_val);
            }

            if tasks.is_empty() {
                if !json {
                    println!("{}", "No tasks found.".yellow());
                } else {
                    println!("[]");
                }
                return Ok(());
            }

            // JSON output
            if json {
                #[derive(serde::Serialize)]
                struct TaskJson {
                    id: String,
                    uuid: String,
                    title: String,
                    description: Option<String>,
                    status: String,
                    priority: String,
                    agent: Option<String>,
                    epic: Option<String>,
                    created_at: String,
                    updated_at: String,
                    completed_at: Option<String>,
                }

                let json_tasks: Vec<TaskJson> = tasks
                    .iter()
                    .filter(|t| !subtasks || t.parent_id.is_none())
                    .map(|t| TaskJson {
                        id: t
                            .display_id
                            .map(|id| format!("#{}", id))
                            .unwrap_or_else(|| t.id[..8].to_string()),
                        uuid: t.id.clone(),
                        title: t.title.clone(),
                        description: t.description.clone(),
                        status: t.status.as_str().to_string(),
                        priority: t.priority.as_str().to_string(),
                        agent: t.assigned_agent.as_ref().and_then(|uuid| {
                            db.get_agent(uuid)
                                .ok()
                                .flatten()
                                .and_then(|a| a.display_id.map(|id| format!("A{}", id)))
                        }),
                        epic: t.epic_name.clone(),
                        created_at: t.created_at.to_rfc3339(),
                        updated_at: t.updated_at.to_rfc3339(),
                        completed_at: t.completed_at.map(|dt| dt.to_rfc3339()),
                    })
                    .collect();

                println!("{}", serde_json::to_string_pretty(&json_tasks)?);
                return Ok(());
            }

            let rows: Vec<TaskRow> = tasks
                .iter()
                .filter(|t| !subtasks || t.parent_id.is_none())
                .map(|t| TaskRow {
                    id: t
                        .display_id
                        .map(|id| format!("#{}", id))
                        .unwrap_or_else(|| t.id[..8].to_string()),
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
                            db.get_agent(uuid)
                                .ok()
                                .flatten()
                                .and_then(|a| a.display_id.map(|id| format!("A{}", id)))
                        })
                        .unwrap_or_else(|| "-".to_string()),
                    created: t.created_at.format("%Y-%m-%d %H:%M").to_string(),
                })
                .collect();

            let mut table = Table::new(rows);
            table.with(Style::modern());
            println!("{}", table);

            if limit.is_some() || offset.is_some() {
                println!(
                    "\n{} of {} tasks total",
                    tasks.len().to_string().cyan().bold(),
                    total_count.to_string().cyan().bold()
                );
            } else {
                println!("\n{} tasks total", tasks.len().to_string().cyan().bold());
            }
        }

        Commands::Show { id, logs, progress } => {
            // Resolve ID (supports #42, 42, or UUID)
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            let task = db.get_task(&task_uuid)?;
            match task {
                Some(t) => {
                    println!("\n{}", "Task Details".bold().underline());
                    let display_id = t
                        .display_id
                        .map(|id| format!("#{}", id))
                        .unwrap_or_else(|| t.id[..8].to_string());
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
                        let agent_display = db
                            .get_agent(agent_uuid)
                            .ok()
                            .flatten()
                            .and_then(|a| a.display_id.map(|id| format!("A{} ({})", id, a.name)))
                            .unwrap_or_else(|| agent_uuid[..8].to_string());
                        println!("Assigned to: {}", agent_display.cyan());
                    }
                    if let Some(parent) = &t.parent_id {
                        let parent_display = db
                            .get_task(parent)
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
                        println!(
                            "Completed: {}",
                            completed.format("%Y-%m-%d %H:%M:%S").to_string().green()
                        );
                    }

                    // Show subtasks
                    let subtasks = db.get_subtasks(&t.id)?;
                    if !subtasks.is_empty() {
                        println!("\n{}", "Subtasks:".bold());
                        for (i, st) in subtasks.iter().enumerate() {
                            let st_id = st
                                .display_id
                                .map(|id| format!("#{}", id))
                                .unwrap_or_else(|| st.id[..8].to_string());
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
                                    log.created_at
                                        .format("%Y-%m-%d %H:%M:%S")
                                        .to_string()
                                        .dimmed(),
                                    log.action.cyan(),
                                    log.details.unwrap_or_default()
                                );
                            }
                        }
                    }

                    // Show progress if requested
                    if progress {
                        if let Some(task_display_id) = t.display_id {
                            let progress_records = db.get_task_progress(task_display_id)?;
                            if !progress_records.is_empty() {
                                println!("\n{}", "Progress History:".bold());
                                for prog in progress_records {
                                    let agent_display = db
                                        .get_agent(&prog.agent_id)
                                        .ok()
                                        .flatten()
                                        .and_then(|a| a.display_id.map(|id| format!("A{}", id)))
                                        .unwrap_or_else(|| prog.agent_id[..8].to_string());
                                    let msg = prog
                                        .message
                                        .map(|m| format!(" - {}", m))
                                        .unwrap_or_default();
                                    println!(
                                        "  {} - {} @ {}%{}",
                                        prog.timestamp
                                            .format("%Y-%m-%d %H:%M:%S")
                                            .to_string()
                                            .dimmed(),
                                        agent_display.cyan(),
                                        prog.progress.to_string().cyan(),
                                        msg
                                    );
                                }
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
            println!(
                "{} Task {} updated to {}",
                "✓".green().bold(),
                display_id.cyan(),
                status_enum.as_str()
            );
        }

        Commands::Breakdown { id, interactive } => {
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            let task = db.get_task(&task_uuid)?;
            match task {
                Some(t) => {
                    println!("Breaking down task: {}", t.title.bold());

                    if interactive {
                        use dialoguer::{Confirm, Input};

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
                            let desc = if description.is_empty() {
                                None
                            } else {
                                Some(description)
                            };

                            let subtask = db.create_task(
                                subtask_title,
                                desc,
                                priority,
                                Some(task_uuid.clone()),
                                None,
                            )?;
                            let subtask_display = subtask
                                .display_id
                                .map(|id| format!("#{}", id))
                                .unwrap_or_else(|| subtask.id[..8].to_string());
                            println!(
                                "{} Created subtask: {}",
                                "✓".green(),
                                subtask_display.cyan()
                            );

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
                    println!(
                        "\n{} {} subtasks created",
                        "✓".green().bold(),
                        subtasks.len()
                    );
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
                    println!(
                        "{} Task {} assigned to {} ({})",
                        "✓".green().bold(),
                        task_display.cyan(),
                        agent_display.cyan(),
                        a.name
                    );
                }
                None => {
                    println!("{} Agent not found. Creating new agent...", "⚠".yellow());
                    let new_agent = db.create_agent(agent.clone())?;
                    db.assign_task(&task_uuid, &new_agent.id)?;
                    let task_display = format_task_id(db.get_connection(), &task_uuid);
                    let agent_display = format_agent_id(db.get_connection(), &new_agent.id);
                    println!(
                        "{} Task {} assigned to new agent {} ({})",
                        "✓".green().bold(),
                        task_display.cyan(),
                        agent_display.cyan(),
                        new_agent.name
                    );
                }
            }
        }

        Commands::AgentCreate { name } => {
            let agent = db.create_agent(name)?;
            println!("{}", "✓ Agent created successfully!".green().bold());
            let display_id = agent
                .display_id
                .map(|id| format!("A{}", id))
                .unwrap_or_else(|| agent.id[..8].to_string());
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
                    id: a
                        .display_id
                        .map(|id| format!("A{}", id))
                        .unwrap_or_else(|| a.id[..8].to_string()),
                    name: a.name.clone(),
                    status: format_agent_status(&a.status),
                    current_task: a
                        .current_task_id
                        .as_ref()
                        .and_then(|uuid| {
                            db.get_task(uuid)
                                .ok()
                                .flatten()
                                .and_then(|t| t.display_id.map(|id| format!("#{}", id)))
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

        Commands::AgentStatus {
            agent,
            status,
            task,
        } => {
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
                    println!(
                        "{} Agent {} status updated!",
                        "✓".green().bold(),
                        agent_display.cyan()
                    );
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
                    println!(
                        "Agent {} ({}) is now working on task {}",
                        agent_display.cyan(),
                        a.name,
                        task_display.cyan()
                    );
                }
                None => {
                    println!("{}", "Agent not found.".red());
                }
            }
        }

        Commands::Complete { task_id, agent } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db
                .get_task(&task_uuid)?
                .ok_or_else(|| anyhow::anyhow!("Task not found"))?;

            let agent_id = if let Some(agent_name) = agent {
                resolve_agent_id(db.get_connection(), &agent_name)?
            } else if let Some(assigned) = task.assigned_agent {
                assigned
            } else {
                return Err(anyhow::anyhow!("No agent specified and task not assigned"));
            };

            db.update_task_status(&task_uuid, TaskStatus::Completed, Some(&agent_id))?;
            db.update_agent_status(&agent_id, AgentStatus::Idle, None)?;

            let task_display = format_task_id(db.get_connection(), &task_uuid);
            let agent_display = format_agent_id(db.get_connection(), &agent_id);
            println!(
                "{} Task {} completed by agent {}",
                "✓".green().bold(),
                task_display.cyan(),
                agent_display.cyan()
            );
        }

        Commands::Cancel { task_id, reason } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db
                .get_task(&task_uuid)?
                .ok_or_else(|| anyhow::anyhow!("Task not found"))?;

            // Update task status to cancelled
            db.update_task_status(&task_uuid, TaskStatus::Cancelled, None)?;

            // If task had an assigned agent, set them to idle
            if let Some(agent_id) = &task.assigned_agent {
                db.update_agent_status(agent_id, AgentStatus::Idle, None)?;
            }

            let task_display = format_task_id(db.get_connection(), &task_uuid);
            println!(
                "{} Task {} cancelled",
                "✕".yellow().bold(),
                task_display.cyan()
            );

            if let Some(reason_text) = reason {
                println!("Reason: {}", reason_text.dimmed());
            }
        }

        Commands::Next {
            priority,
            epic,
            agent,
            sync,
        } => {
            let ready_ids = db.get_connection().get_ready_tasks()?;

            if ready_ids.is_empty() {
                println!(
                    "{}",
                    "No tasks ready (all have pending dependencies).".yellow()
                );
                return Ok(());
            }

            // Get full task details and filter
            let mut ready_tasks = Vec::new();
            for task_id in &ready_ids {
                let task_result: Result<_, rusqlite::Error> = db.get_connection().query_row(
                    "SELECT id FROM tasks WHERE display_id = ?1",
                    [task_id],
                    |row| row.get::<_, String>(0),
                );
                if let Ok(uuid) = task_result {
                    if let Ok(Some(task)) = db.get_task(&uuid) {
                        ready_tasks.push(task);
                    }
                }
            }

            // Apply filters
            if let Some(prio_str) = priority {
                let prio_filter = Priority::from_str(&prio_str);
                ready_tasks.retain(|t| t.priority == prio_filter);
            }
            if let Some(epic_name) = epic {
                ready_tasks.retain(|t| t.epic_name.as_ref().map_or(false, |e| e == &epic_name));
            }

            if ready_tasks.is_empty() {
                println!("{}", "No matching tasks ready.".yellow());
                return Ok(());
            }

            // Sort by priority (critical > high > medium > low)
            ready_tasks.sort_by(|a, b| {
                let a_val = match a.priority {
                    Priority::Critical => 4,
                    Priority::High => 3,
                    Priority::Medium => 2,
                    Priority::Low => 1,
                };
                let b_val = match b.priority {
                    Priority::Critical => 4,
                    Priority::High => 3,
                    Priority::Medium => 2,
                    Priority::Low => 1,
                };
                b_val.cmp(&a_val)
            });

            let next_task = &ready_tasks[0];
            let task_display = next_task
                .display_id
                .map(|id| format!("#{}", id))
                .unwrap_or_else(|| next_task.id[..8].to_string());

            println!("\n{}", "Next task:".bold().underline());
            println!(
                "{} - {} [{}]",
                task_display.cyan(),
                next_task.title,
                format_priority(&next_task.priority)
            );
            if let Some(desc) = &next_task.description {
                println!("Description: {}", desc.dimmed());
            }

            // Auto-assign and sync if requested
            if let Some(agent_name) = agent {
                let agent_uuid = resolve_agent_id(db.get_connection(), &agent_name)?;
                let agent_obj = db
                    .get_agent(&agent_uuid)?
                    .ok_or_else(|| anyhow::anyhow!("Agent not found"))?;

                if sync {
                    // Update agent to working status
                    db.update_agent_status(
                        &agent_obj.id,
                        AgentStatus::Working,
                        Some(&next_task.id),
                    )?;
                    // Update task to in_progress
                    db.update_task_status(
                        &next_task.id,
                        TaskStatus::InProgress,
                        Some(&agent_obj.id),
                    )?;
                    // Assign task if not already assigned
                    db.assign_task(&next_task.id, &agent_obj.id)?;

                    let agent_display = format_agent_id(db.get_connection(), &agent_obj.id);
                    println!("\n{}", "✓ Task assigned and synced!".green().bold());
                    println!(
                        "Agent {} ({}) is now working on {}",
                        agent_display.cyan(),
                        agent_obj.name,
                        task_display.cyan()
                    );
                } else {
                    db.assign_task(&next_task.id, &agent_obj.id)?;
                    let agent_display = format_agent_id(db.get_connection(), &agent_obj.id);
                    println!(
                        "\n{} Task assigned to {}",
                        "✓".green().bold(),
                        agent_display.cyan()
                    );
                }
            }
        }

        Commands::BatchUpdate {
            task_ids,
            status,
            agent,
        } => {
            let status_enum = TaskStatus::from_str(&status);
            let task_id_list: Vec<&str> = task_ids.split(',').map(|s| s.trim()).collect();

            let agent_uuid = if let Some(agent_name) = agent {
                Some(resolve_agent_id(db.get_connection(), &agent_name)?)
            } else {
                None
            };

            let mut updated_count = 0;
            let mut failed: Vec<String> = Vec::new();

            for task_id_str in task_id_list {
                match resolve_task_id(db.get_connection(), task_id_str) {
                    Ok(task_uuid) => {
                        match db.update_task_status(
                            &task_uuid,
                            status_enum.clone(),
                            agent_uuid.as_deref(),
                        ) {
                            Ok(_) => updated_count += 1,
                            Err(e) => failed.push(format!("{}: {}", task_id_str, e)),
                        }
                    }
                    Err(e) => failed.push(format!("{}: {}", task_id_str, e)),
                }
            }

            println!(
                "{} Updated {} task(s) to {}",
                "✓".green().bold(),
                updated_count.to_string().cyan(),
                status_enum.as_str()
            );

            if !failed.is_empty() {
                println!("\n{} Failed to update:", "⚠".yellow());
                for fail in failed {
                    println!("  {}", fail.dimmed());
                }
            }
        }

        Commands::BatchAssign { task_ids, agent } => {
            let agent_uuid = resolve_agent_id(db.get_connection(), &agent)?;
            let agent_obj = db
                .get_agent(&agent_uuid)?
                .ok_or_else(|| anyhow::anyhow!("Agent not found"))?;
            let task_id_list: Vec<&str> = task_ids.split(',').map(|s| s.trim()).collect();

            let mut assigned_count = 0;
            let mut failed: Vec<String> = Vec::new();

            for task_id_str in task_id_list {
                match resolve_task_id(db.get_connection(), task_id_str) {
                    Ok(task_uuid) => match db.assign_task(&task_uuid, &agent_obj.id) {
                        Ok(_) => assigned_count += 1,
                        Err(e) => failed.push(format!("{}: {}", task_id_str, e)),
                    },
                    Err(e) => failed.push(format!("{}: {}", task_id_str, e)),
                }
            }

            let agent_display = format_agent_id(db.get_connection(), &agent_obj.id);
            println!(
                "{} Assigned {} task(s) to {} ({})",
                "✓".green().bold(),
                assigned_count.to_string().cyan(),
                agent_display.cyan(),
                agent_obj.name
            );

            if !failed.is_empty() {
                println!("\n{} Failed to assign:", "⚠".yellow());
                for fail in failed {
                    println!("  {}", fail.dimmed());
                }
            }
        }

        Commands::Stats { visual, json } => {
            if json {
                // JSON output
                let stats = db.get_stats()?;
                println!("{}", serde_json::to_string_pretty(&stats)?);
            } else if visual {
                // Visual timeline
                use prd_tool::visualization::TimelineRenderer;
                // Create a library Database instance for visualization
                let lib_db = prd_tool::Database::new(cli.database.to_str().unwrap())?;
                let renderer = TimelineRenderer::new(lib_db);
                let output = renderer.render()?;
                println!("{}", output);
            } else {
                // Simple stats (existing)
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
        }

        Commands::Epics => {
            // Get all tasks and group by epic
            let all_tasks = db.list_tasks(None)?;
            let mut epic_counts: std::collections::HashMap<String, (i32, i32)> =
                std::collections::HashMap::new();

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

        Commands::Depends {
            task_id,
            on,
            blocks,
            list,
        } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db
                .get_task(&task_uuid)?
                .ok_or_else(|| anyhow::anyhow!("Task not found"))?;
            let task_display_id = task
                .display_id
                .ok_or_else(|| anyhow::anyhow!("Task missing display_id"))?;

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
                let depends_on_task = db
                    .get_task(&depends_on_uuid)?
                    .ok_or_else(|| anyhow::anyhow!("Dependency task not found"))?;
                let depends_on_id = depends_on_task
                    .display_id
                    .ok_or_else(|| anyhow::anyhow!("Dependency task missing display_id"))?;

                db.get_connection()
                    .add_dependency(task_display_id, depends_on_id, "blocks")?;
                println!(
                    "{} Task #{} now depends on #{}",
                    "✓".green().bold(),
                    task_display_id,
                    depends_on_id
                );
            } else if let Some(blocks_input) = blocks {
                let blocks_uuid = resolve_task_id(db.get_connection(), &blocks_input)?;
                let blocks_task = db
                    .get_task(&blocks_uuid)?
                    .ok_or_else(|| anyhow::anyhow!("Blocked task not found"))?;
                let blocks_id = blocks_task
                    .display_id
                    .ok_or_else(|| anyhow::anyhow!("Blocked task missing display_id"))?;

                db.get_connection()
                    .add_dependency(blocks_id, task_display_id, "blocks")?;
                println!(
                    "{} Task #{} now blocks #{}",
                    "✓".green().bold(),
                    task_display_id,
                    blocks_id
                );
            } else {
                println!("Use --on <task-id>, --blocks <task-id>, or --list");
            }
        }

        Commands::Ready => {
            let ready_ids = db.get_connection().get_ready_tasks()?;

            if ready_ids.is_empty() {
                println!(
                    "{}",
                    "No tasks ready (all have pending dependencies).".yellow()
                );
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
            println!(
                "\n{} tasks ready",
                ready_ids.len().to_string().cyan().bold()
            );
        }

        Commands::Ac { task_id, action } => {
            let task_uuid = resolve_task_id(db.get_connection(), &task_id)?;
            let task = db
                .get_task(&task_uuid)?
                .ok_or_else(|| anyhow::anyhow!("Task not found"))?;
            let task_display_id = task
                .display_id
                .ok_or_else(|| anyhow::anyhow!("Task missing display_id"))?;

            match action {
                AcAction::Add { criterion } => {
                    let ac_id = db
                        .get_connection()
                        .add_criterion(task_display_id, criterion.clone())?;
                    println!(
                        "{} Added acceptance criterion #{}",
                        "✓".green().bold(),
                        ac_id
                    );
                }
                AcAction::List => {
                    let criteria = db.get_connection().list_criteria(task_display_id)?;

                    if criteria.is_empty() {
                        println!("{}", "No acceptance criteria defined.".yellow());
                        return Ok(());
                    }

                    println!(
                        "\nAcceptance Criteria for #{} - {}",
                        task_display_id,
                        task.title.bold()
                    );
                    for (i, ac) in criteria.iter().enumerate() {
                        let checkbox = if ac.completed { "☑" } else { "☐" };
                        println!("  {}. {} {}", i + 1, checkbox, ac.criterion);
                    }

                    let completed_count = criteria.iter().filter(|ac| ac.completed).count();
                    println!("\n{}/{} criteria met", completed_count, criteria.len());
                }
                AcAction::Check { id } => {
                    db.get_connection().check_criterion(id)?;
                    println!(
                        "{} Criterion #{} marked as completed",
                        "✓".green().bold(),
                        id
                    );
                }
                AcAction::Uncheck { id } => {
                    db.get_connection().uncheck_criterion(id)?;
                    println!(
                        "{} Criterion #{} marked as incomplete",
                        "✓".green().bold(),
                        id
                    );
                }
            }
        }

        Commands::Duration {
            id,
            estimated,
            actual,
        } => {
            let task_uuid = resolve_task_id(db.get_connection(), &id)?;
            db.update_task_duration(&task_uuid, estimated, actual)?;
            let display_id = format_task_id(db.get_connection(), &task_uuid);
            println!(
                "{} Task {} duration updated!",
                "✓".green().bold(),
                display_id.cyan()
            );
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
                        println!(
                            "\n{} Applied {} migration(s)",
                            "✓".green().bold(),
                            applied.len()
                        );
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

        Commands::CompleteBatch {
            tasks,
            agent_map,
            from_file,
            from_csv,
        } => {
            let records = if let Some(tasks_str) = tasks {
                let map = agent_map
                    .ok_or_else(|| anyhow::anyhow!("--agent-map required with --tasks"))?;
                batch::parse_cli_args(&tasks_str, &map)?
            } else if let Some(json_path) = from_file {
                batch::parse_json_file(&json_path)?
            } else if let Some(csv_path) = from_csv {
                batch::parse_csv_file(&csv_path)?
            } else {
                anyhow::bail!("Must specify --tasks, --from-file, or --from-csv");
            };

            let result = batch::complete_batch(&db, records)?;

            if !result.failed.is_empty() {
                std::process::exit(1);
            }
        }

        Commands::SyncDocs {
            from_git,
            since,
            until,
            branch,
            dry_run,
            docs_dir,
        } => {
            if from_git {
                // Git-based sync
                use chrono::NaiveDate;
                use prd_tool::git::GitSync;

                let repo_path = std::env::current_dir()?;
                let git_sync = GitSync::new(&repo_path)?;

                // Parse dates
                let since_dt = since
                    .as_ref()
                    .map(|s| {
                        DateTime::parse_from_rfc3339(s)
                            .or_else(|_| {
                                // Try simple date format
                                NaiveDate::parse_from_str(s, "%Y-%m-%d")
                                    .map(|d| d.and_hms_opt(0, 0, 0).unwrap())
                                    .map(|dt| DateTime::<Utc>::from_naive_utc_and_offset(dt, Utc))
                                    .map(|dt| dt.fixed_offset())
                            })
                            .map_err(|_| anyhow::anyhow!("Invalid date format for --since"))
                    })
                    .transpose()?
                    .map(|dt| dt.with_timezone(&Utc));

                let until_dt = until
                    .as_ref()
                    .map(|s| {
                        DateTime::parse_from_rfc3339(s)
                            .or_else(|_| {
                                NaiveDate::parse_from_str(s, "%Y-%m-%d")
                                    .map(|d| d.and_hms_opt(23, 59, 59).unwrap())
                                    .map(|dt| DateTime::<Utc>::from_naive_utc_and_offset(dt, Utc))
                                    .map(|dt| dt.fixed_offset())
                            })
                            .map_err(|_| anyhow::anyhow!("Invalid date format for --until"))
                    })
                    .transpose()?
                    .map(|dt| dt.with_timezone(&Utc));

                let completions =
                    git_sync.scan_for_completions(since_dt, until_dt, branch.as_deref())?;

                if completions.is_empty() {
                    println!("\nNo tasks found in git history");
                    return Ok(());
                }

                if dry_run {
                    println!("\n🔍 DRY RUN: No changes will be made\n");
                    for doc in &completions {
                        println!("Would mark task #{} complete", doc.task_id);
                        if let Some(agent_id) = &doc.agent_id {
                            println!("  Agent: {}", agent_id);
                        }
                        println!("  Commit: {}", doc.git_commit_hash.as_ref().unwrap());
                        println!();
                    }
                    println!(
                        "Total: {} tasks would be marked complete",
                        completions.len()
                    );
                } else {
                    // Actually sync to database
                    println!("\n📝 Syncing {} tasks to database...\n", completions.len());

                    let mut synced = 0;
                    let mut skipped = 0;
                    let mut errors = 0;

                    for doc in completions {
                        // Check if task exists
                        let task_result: Result<Option<String>, _> = db.get_connection().query_row(
                            "SELECT id FROM tasks WHERE display_id = ?1",
                            [doc.task_id],
                            |row| row.get(0),
                        );

                        match task_result {
                            Ok(Some(task_uuid)) => {
                                // Check if already completed
                                let task = db.get_task(&task_uuid)?;
                                if let Some(t) = task {
                                    if t.status == TaskStatus::Completed {
                                        skipped += 1;
                                        println!(
                                            "⚠ Skipped task #{} (already complete)",
                                            doc.task_id
                                        );
                                        continue;
                                    }

                                    // Mark as completed
                                    let agent_id = if let Some(ref agent_str) = doc.agent_id {
                                        // Try to resolve or create agent
                                        let agent_result =
                                            resolve_agent_id(db.get_connection(), agent_str);
                                        match agent_result {
                                            Ok(id) => Some(id),
                                            Err(_) => {
                                                // Create agent
                                                match db.create_agent(agent_str.clone()) {
                                                    Ok(agent) => Some(agent.id),
                                                    Err(_) => None,
                                                }
                                            }
                                        }
                                    } else {
                                        None
                                    };

                                    match db.update_task_status(
                                        &task_uuid,
                                        TaskStatus::Completed,
                                        agent_id.as_deref(),
                                    ) {
                                        Ok(_) => {
                                            synced += 1;
                                            println!("✓ Marked task #{} complete", doc.task_id);
                                        }
                                        Err(e) => {
                                            errors += 1;
                                            println!("❌ Failed task #{}: {}", doc.task_id, e);
                                        }
                                    }
                                }
                            }
                            Ok(None) => {
                                errors += 1;
                                println!("❌ Task #{} not found in database", doc.task_id);
                            }
                            Err(e) => {
                                errors += 1;
                                println!("❌ Database error for task #{}: {}", doc.task_id, e);
                            }
                        }
                    }

                    println!("\nSummary:");
                    println!("  Newly completed: {}", synced);
                    println!("  Already synced: {}", skipped);
                    println!("  Errors: {}", errors);

                    if errors > 0 {
                        std::process::exit(1);
                    }
                }
            } else {
                // File-based sync (Phase 1 implementation)
                let result = sync::sync_tasks_from_docs(&db, &docs_dir, dry_run)?;

                if result.newly_completed == 0 && result.already_synced == 0 {
                    println!("{}", "No tasks to sync.".yellow());
                }

                if !result.failed.is_empty() {
                    std::process::exit(1);
                }
            }
        }

        Commands::Reconcile {
            auto_fix,
            docs_dir,
            backup,
        } => {
            if backup {
                // Create backup
                let backup_path = format!("tools/prd.db.backup.{}", chrono::Utc::now().timestamp());
                std::fs::copy(cli.database.clone(), &backup_path)?;
                println!("{} Created backup: {}", "✓".green(), backup_path.dimmed());
            }

            let result = sync::reconcile(&db, &docs_dir, auto_fix)?;

            if result.fixed_count == 0 && result.inconsistencies.is_empty() {
                println!("{}", "Database is healthy!".green().bold());
            }

            if !result.failed.is_empty() {
                std::process::exit(1);
            }
        }

        Commands::ReportProgress {
            agent,
            task_id,
            progress,
            message,
        } => {
            // Resolve agent ID (supports A12, 12, name, or UUID)
            let agent_uuid = resolve_agent_id(db.get_connection(), &agent)?;

            // Resolve task ID (supports #37, 37, or UUID)
            let task_display_id = if task_id.starts_with('#') {
                task_id[1..]
                    .parse::<i32>()
                    .map_err(|_| anyhow::anyhow!("Invalid task ID format"))?
            } else {
                task_id
                    .parse::<i32>()
                    .map_err(|_| anyhow::anyhow!("Invalid task ID format"))?
            };

            // Report progress
            db.report_progress(&agent_uuid, task_display_id, progress, message)?;

            // Get agent display ID for output
            let agent_display = format_agent_id(db.get_connection(), &agent_uuid);

            println!(
                "{} Progress updated: {} @ {}%",
                "✓".green().bold(),
                agent_display.cyan(),
                progress.to_string().cyan()
            );
        }

        Commands::Watch { refresh_interval } => {
            use prd_tool::dashboard::run_dashboard;
            run_dashboard(cli.database.to_str().unwrap(), refresh_interval)?;
        }

        Commands::InstallGitHook { uninstall, status } => {
            use prd_tool::git::GitHookManager;

            let repo_path = std::env::current_dir()?;
            let hook_manager = GitHookManager::new(repo_path);

            if status {
                hook_manager.status()?;
            } else if uninstall {
                hook_manager.uninstall()?;
            } else {
                hook_manager.install()?;
            }
        }

        Commands::WatchFiles {
            daemon,
            status,
            stop,
            docs_path,
            daemon_mode,
        } => {
            use prd_tool::watcher;
            use std::sync::atomic::Ordering;
            use std::sync::Arc;

            if status {
                watcher::daemon::status()?;
            } else if stop {
                watcher::daemon::stop_daemon()?;
            } else if daemon {
                let db_path = cli.database.clone();
                watcher::daemon::start_daemon(docs_path, db_path)?;
            } else if daemon_mode {
                // Internal: running as daemon
                // FileWatcher expects library Database type
                let lib_db = prd_tool::Database::new(cli.database.to_str().unwrap())?;
                let mut watcher = watcher::FileWatcher::new(docs_path, lib_db)?;

                // Setup signal handler for graceful shutdown
                let running = Arc::clone(&watcher.running);
                ctrlc::set_handler(move || {
                    running.store(false, Ordering::SeqCst);
                })
                .expect("Error setting Ctrl+C handler");

                watcher.start()?;
            } else {
                // Foreground mode
                // FileWatcher expects library Database type
                let lib_db = prd_tool::Database::new(cli.database.to_str().unwrap())?;
                let mut watcher = watcher::FileWatcher::new(docs_path, lib_db)?;

                // Setup Ctrl+C handler
                let running = Arc::clone(&watcher.running);
                ctrlc::set_handler(move || {
                    println!("\nReceived Ctrl+C, stopping...");
                    running.store(false, Ordering::SeqCst);
                })
                .expect("Error setting Ctrl+C handler");

                watcher.start()?;
            }
        }

        Commands::Hooks { subcommand } => {
            use prd_tool::hooks;

            match subcommand {
                HooksSubcommand::Init => {
                    hooks::init_hooks_config()?;
                }
                HooksSubcommand::List => {
                    hooks::list_hooks()?;
                }
                HooksSubcommand::Test {
                    hook_name,
                    task_id,
                    agent_id,
                } => {
                    hooks::test_hook(&hook_name, task_id.as_deref(), agent_id.as_deref())?;
                }
                HooksSubcommand::Enable { hook_name } => {
                    hooks::enable_hook(&hook_name)?;
                }
                HooksSubcommand::Disable { hook_name } => {
                    hooks::disable_hook(&hook_name)?;
                }
            }
        }

        Commands::Vector { action } => {
            use vectors::{ContentIndexer, ContentType, Embedder, VectorSearch, VectorStore};

            // Ensure vector schema exists (apply migration 008 inline)
            let conn = db.get_connection();
            conn.execute_batch(
                r#"
                CREATE TABLE IF NOT EXISTS embeddings (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    content_type TEXT NOT NULL,
                    content_id TEXT NOT NULL,
                    chunk_index INTEGER DEFAULT 0,
                    content_preview TEXT,
                    content_hash TEXT NOT NULL,
                    embedding BLOB NOT NULL,
                    metadata TEXT,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    UNIQUE(content_type, content_id, chunk_index)
                );
                CREATE INDEX IF NOT EXISTS idx_embeddings_type ON embeddings(content_type);
                CREATE INDEX IF NOT EXISTS idx_embeddings_content_id ON embeddings(content_id);
                CREATE INDEX IF NOT EXISTS idx_embeddings_hash ON embeddings(content_hash);
                CREATE TABLE IF NOT EXISTS vector_stats (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    content_type TEXT NOT NULL UNIQUE,
                    total_items INTEGER DEFAULT 0,
                    total_chunks INTEGER DEFAULT 0,
                    last_indexed_at TEXT,
                    index_duration_ms INTEGER
                );
                INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('task', 0, 0);
                INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('code', 0, 0);
                INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('doc', 0, 0);
                "#,
            )?;

            match action {
                VectorCommands::Index {
                    content,
                    path,
                    patterns,
                    force,
                } => {
                    let mut embedder = Embedder::new();

                    println!(
                        "{} Loading embedding model (first run may download ~100MB)...",
                        "⏳".yellow()
                    );

                    let conn = db.get_connection();
                    let mut indexer = ContentIndexer::new(&mut embedder, conn);

                    let content_lower = content.to_lowercase();
                    let mut total_items = 0;
                    let mut total_chunks = 0;
                    let mut total_errors = 0;

                    if content_lower == "all" || content_lower == "tasks" {
                        println!("{} Indexing tasks...", "📋".cyan());
                        let stats = indexer.index_tasks(force)?;
                        println!(
                            "  {} {} tasks indexed, {} skipped, {} chunks",
                            "✓".green(),
                            stats.items_indexed,
                            stats.items_skipped,
                            stats.chunks_created
                        );
                        total_items += stats.items_indexed;
                        total_chunks += stats.chunks_created;
                        total_errors += stats.errors;
                    }

                    if content_lower == "all" || content_lower == "code" {
                        let code_path = path.clone().unwrap_or_else(|| PathBuf::from("."));
                        println!(
                            "{} Indexing code in {}...",
                            "💻".cyan(),
                            code_path.display()
                        );
                        let stats =
                            indexer.index_directory(&code_path, ContentType::Code, &patterns, force)?;
                        println!(
                            "  {} {} files indexed, {} skipped, {} chunks",
                            "✓".green(),
                            stats.items_indexed,
                            stats.items_skipped,
                            stats.chunks_created
                        );
                        total_items += stats.items_indexed;
                        total_chunks += stats.chunks_created;
                        total_errors += stats.errors;
                    }

                    if content_lower == "all" || content_lower == "docs" {
                        let docs_path = path.unwrap_or_else(|| PathBuf::from("."));
                        println!(
                            "{} Indexing docs in {}...",
                            "📄".cyan(),
                            docs_path.display()
                        );
                        let stats =
                            indexer.index_directory(&docs_path, ContentType::Doc, &patterns, force)?;
                        println!(
                            "  {} {} files indexed, {} skipped, {} chunks",
                            "✓".green(),
                            stats.items_indexed,
                            stats.items_skipped,
                            stats.chunks_created
                        );
                        total_items += stats.items_indexed;
                        total_chunks += stats.chunks_created;
                        total_errors += stats.errors;
                    }

                    println!("\n{}", "Indexing complete!".green().bold());
                    println!(
                        "Total: {} items, {} chunks{}",
                        total_items.to_string().cyan().bold(),
                        total_chunks.to_string().cyan().bold(),
                        if total_errors > 0 {
                            format!(", {} errors", total_errors.to_string().red())
                        } else {
                            String::new()
                        }
                    );
                }

                VectorCommands::Search {
                    query,
                    r#type,
                    limit,
                    threshold,
                } => {
                    let mut embedder = Embedder::new();
                    let conn = db.get_connection();

                    let content_type = r#type.as_ref().and_then(|t| ContentType::from_str(t));

                    println!(
                        "{} Searching for: \"{}\"",
                        "🔍".cyan(),
                        query.bold()
                    );

                    let results = VectorSearch::search_text(
                        conn,
                        &mut embedder,
                        &query,
                        content_type,
                        limit,
                        threshold,
                    )?;

                    if results.is_empty() {
                        println!("{}", "No results found.".yellow());
                        return Ok(());
                    }

                    println!("\n{} results:\n", results.len().to_string().cyan().bold());

                    for result in results {
                        let type_icon = match result.record.content_type {
                            ContentType::Task => "📋",
                            ContentType::Code => "💻",
                            ContentType::Doc => "📄",
                        };

                        let similarity_pct = (result.similarity * 100.0) as u32;
                        let similarity_str = format!("{}%", similarity_pct);
                        let similarity_colored = if similarity_pct >= 80 {
                            similarity_str.green().bold()
                        } else if similarity_pct >= 60 {
                            similarity_str.yellow()
                        } else {
                            similarity_str.dimmed()
                        };

                        println!(
                            "{}. {} {} [{}] {}",
                            result.rank,
                            type_icon,
                            result.record.content_id.cyan(),
                            similarity_colored,
                            result.record.content_type
                        );

                        if let Some(preview) = &result.record.content_preview {
                            let preview_trimmed = if preview.len() > 80 {
                                format!("{}...", &preview[..77])
                            } else {
                                preview.clone()
                            };
                            println!("   {}", preview_trimmed.dimmed());
                        }
                        println!();
                    }
                }

                VectorCommands::Similar {
                    task_id,
                    code,
                    docs,
                    limit,
                } => {
                    let conn = db.get_connection();

                    // Resolve task ID
                    let task_uuid = resolve_task_id(conn, &task_id)?;
                    let task = db.get_task(&task_uuid)?;
                    let task = task.ok_or_else(|| anyhow::anyhow!("Task not found"))?;

                    let display_id = task
                        .display_id
                        .map(|id| format!("#{}", id))
                        .unwrap_or_else(|| task_id.clone());

                    println!(
                        "{} Finding content similar to task {} ({})",
                        "🔍".cyan(),
                        display_id.cyan().bold(),
                        task.title
                    );

                    // Determine which types to search
                    let search_types = if code || docs {
                        let mut types = vec![];
                        if code {
                            types.push(ContentType::Code);
                        }
                        if docs {
                            types.push(ContentType::Doc);
                        }
                        // Always include similar tasks
                        types.push(ContentType::Task);
                        Some(types)
                    } else {
                        None // Search all
                    };

                    let results = VectorSearch::find_similar(
                        conn,
                        ContentType::Task,
                        &display_id,
                        search_types,
                        limit,
                        0.3, // Lower threshold for similar search
                    )?;

                    if results.is_empty() {
                        println!("{}", "No similar content found. Try indexing first with: prd vector index".yellow());
                        return Ok(());
                    }

                    println!("\n{} similar items:\n", results.len().to_string().cyan().bold());

                    for result in results {
                        let type_icon = match result.record.content_type {
                            ContentType::Task => "📋",
                            ContentType::Code => "💻",
                            ContentType::Doc => "📄",
                        };

                        let similarity_pct = (result.similarity * 100.0) as u32;
                        let similarity_str = format!("{}%", similarity_pct);
                        let similarity_colored = if similarity_pct >= 70 {
                            similarity_str.green().bold()
                        } else if similarity_pct >= 50 {
                            similarity_str.yellow()
                        } else {
                            similarity_str.dimmed()
                        };

                        println!(
                            "{}. {} {} [{}]",
                            result.rank,
                            type_icon,
                            result.record.content_id.cyan(),
                            similarity_colored
                        );

                        if let Some(preview) = &result.record.content_preview {
                            let preview_trimmed = if preview.len() > 80 {
                                format!("{}...", &preview[..77])
                            } else {
                                preview.clone()
                            };
                            println!("   {}", preview_trimmed.dimmed());
                        }
                        println!();
                    }
                }

                VectorCommands::Stats => {
                    let conn = db.get_connection();
                    let stats = VectorStore::get_stats(conn)?;

                    println!("\n{}", "Vector Index Statistics".bold().underline());
                    println!();

                    for stat in stats {
                        let type_icon = match stat.content_type {
                            ContentType::Task => "📋",
                            ContentType::Code => "💻",
                            ContentType::Doc => "📄",
                        };

                        println!(
                            "{} {}: {} items, {} chunks",
                            type_icon,
                            stat.content_type.to_string().cyan().bold(),
                            stat.total_items,
                            stat.total_chunks
                        );

                        if let Some(last_indexed) = stat.last_indexed_at {
                            println!(
                                "   Last indexed: {}",
                                last_indexed.format("%Y-%m-%d %H:%M:%S").to_string().dimmed()
                            );
                        }
                        if let Some(duration) = stat.index_duration_ms {
                            println!("   Duration: {}ms", duration);
                        }
                        println!();
                    }
                }

                VectorCommands::Clear { content } => {
                    let conn = db.get_connection();

                    let content_type = content.as_ref().and_then(|c| ContentType::from_str(c));

                    match content_type {
                        Some(ct) => {
                            let deleted = VectorStore::delete_all_by_type(conn, ct)?;
                            println!(
                                "{} Cleared {} embeddings from {} index",
                                "✓".green(),
                                deleted,
                                ct
                            );
                        }
                        None => {
                            // Clear all
                            let mut total = 0;
                            for ct in [ContentType::Task, ContentType::Code, ContentType::Doc] {
                                total += VectorStore::delete_all_by_type(conn, ct)?;
                            }
                            println!(
                                "{} Cleared {} embeddings from all indexes",
                                "✓".green(),
                                total
                            );
                        }
                    }
                }
            }
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
