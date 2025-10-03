mod db;

use anyhow::Result;
use colored::*;
use db::{Database, TaskStatus, AgentStatus};
use std::io::{self, Write};
use std::path::PathBuf;
use std::thread;
use std::time::Duration;
use tabled::{Table, Tabled, settings::Style};

#[derive(Tabled)]
struct TaskSummaryRow {
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
    #[tabled(rename = "Subtasks")]
    subtasks: String,
}

#[derive(Tabled)]
struct AgentActivityRow {
    #[tabled(rename = "Agent")]
    name: String,
    #[tabled(rename = "Status")]
    status: String,
    #[tabled(rename = "Current Task")]
    task: String,
    #[tabled(rename = "Last Active")]
    last_active: String,
}

fn clear_screen() {
    print!("\x1B[2J\x1B[1;1H");
    io::stdout().flush().unwrap();
}

fn print_header() {
    println!("{}", "═══════════════════════════════════════════════════════════════".cyan().bold());
    println!("{}", "           PRD DASHBOARD - Task Management System".cyan().bold());
    println!("{}", "═══════════════════════════════════════════════════════════════".cyan().bold());
    println!();
}

fn print_stats(db: &Database) -> Result<()> {
    let stats = db.get_stats()?;

    println!("{}", "📊 OVERALL STATISTICS".bold().underline());
    println!();

    let progress = if stats.total > 0 {
        (stats.completed as f32 / stats.total as f32) * 100.0
    } else {
        0.0
    };

    println!("Total Tasks: {}  |  Completed: {}  |  Progress: {:.1}%",
        stats.total.to_string().cyan().bold(),
        stats.completed.to_string().green().bold(),
        progress
    );

    // Progress bar
    let bar_length = 50;
    let filled = ((progress / 100.0) * bar_length as f32) as usize;
    let bar = "█".repeat(filled) + &"░".repeat(bar_length - filled);
    println!("{}", bar.green());
    println!();

    // Status breakdown
    println!("{}", "Status Breakdown:".bold());
    println!("  {} Pending       : {}", "○".white(), format!("{:>3}", stats.pending).white());
    println!("  {} In Progress  : {}", "◐".blue(), format!("{:>3}", stats.in_progress).blue().bold());
    println!("  {} Blocked      : {}", "■".red(), format!("{:>3}", stats.blocked).red());
    println!("  {} Review       : {}", "◇".yellow(), format!("{:>3}", stats.review).yellow());
    println!("  {} Completed    : {}", "●".green(), format!("{:>3}", stats.completed).green().bold());
    println!("  {} Cancelled    : {}", "✕".dimmed(), format!("{:>3}", stats.cancelled).dimmed());
    println!();

    Ok(())
}

fn print_active_tasks(db: &Database) -> Result<()> {
    println!("{}", "🔥 ACTIVE TASKS".bold().underline());
    println!();

    let tasks = db.list_tasks(Some(TaskStatus::InProgress))?;

    if tasks.is_empty() {
        println!("{}", "  No tasks currently in progress.".dimmed());
        println!();
        return Ok(());
    }

    let rows: Vec<TaskSummaryRow> = tasks.iter().take(10).map(|t| {
        let subtasks = db.get_subtasks(&t.id).unwrap_or_default();
        let completed_subtasks = subtasks.iter().filter(|st| st.status == TaskStatus::Completed).count();
        let total_subtasks = subtasks.len();

        TaskSummaryRow {
            id: t.id[..8].to_string(),
            title: if t.title.len() > 35 {
                format!("{}...", &t.title[..32])
            } else {
                t.title.clone()
            },
            status: format_status(&t.status),
            priority: format_priority(&t.priority),
            agent: t.assigned_agent.as_ref()
                .and_then(|a| db.get_agent(a).ok().flatten())
                .map(|agent| agent.name.clone())
                .unwrap_or_else(|| "-".to_string()),
            subtasks: if total_subtasks > 0 {
                format!("{}/{}", completed_subtasks, total_subtasks)
            } else {
                "-".to_string()
            },
        }
    }).collect();

    let mut table = Table::new(rows);
    table.with(Style::modern());
    println!("{}", table);
    println!();

    Ok(())
}

fn print_blocked_tasks(db: &Database) -> Result<()> {
    let tasks = db.list_tasks(Some(TaskStatus::Blocked))?;

    if !tasks.is_empty() {
        println!("{}", "⚠️  BLOCKED TASKS".bold().underline().red());
        println!();

        for task in tasks.iter().take(5) {
            println!("  {} {} - {}",
                "■".red(),
                task.id[..8].to_string().dimmed(),
                task.title.yellow()
            );
            if let Some(agent_id) = &task.assigned_agent {
                if let Ok(Some(agent)) = db.get_agent(agent_id) {
                    println!("    Agent: {}", agent.name.cyan());
                }
            }
        }
        println!();
    }

    Ok(())
}

fn print_agents(db: &Database) -> Result<()> {
    println!("{}", "👥 AGENT ACTIVITY".bold().underline());
    println!();

    let agents = db.list_agents()?;

    if agents.is_empty() {
        println!("{}", "  No agents registered.".dimmed());
        println!();
        return Ok(());
    }

    let rows: Vec<AgentActivityRow> = agents.iter().map(|a| {
        let task_title = a.current_task_id.as_ref()
            .and_then(|tid| db.get_task(tid).ok().flatten())
            .map(|t| {
                if t.title.len() > 30 {
                    format!("{}...", &t.title[..27])
                } else {
                    t.title.clone()
                }
            })
            .unwrap_or_else(|| "-".to_string());

        AgentActivityRow {
            name: a.name.clone(),
            status: format_agent_status(&a.status),
            task: task_title,
            last_active: a.last_active.format("%H:%M:%S").to_string(),
        }
    }).collect();

    let mut table = Table::new(rows);
    table.with(Style::modern());
    println!("{}", table);
    println!();

    Ok(())
}

fn print_recent_activity(db: &Database) -> Result<()> {
    println!("{}", "📝 RECENT ACTIVITY".bold().underline());
    println!();

    let tasks = db.list_tasks(None)?;
    let mut all_logs = vec![];

    // Collect logs from all tasks
    for task in tasks.iter().take(20) {
        if let Ok(logs) = db.get_task_logs(&task.id) {
            for log in logs.iter().take(3) {
                all_logs.push((task.title.clone(), log.clone()));
            }
        }
    }

    // Sort by timestamp
    all_logs.sort_by(|a, b| b.1.created_at.cmp(&a.1.created_at));

    for (task_title, log) in all_logs.iter().take(8) {
        let time = log.created_at.format("%H:%M:%S").to_string().dimmed();
        let action = match log.action.as_str() {
            "created" => "created".green(),
            "status_changed" => "updated".blue(),
            "assigned" => "assigned".cyan(),
            _ => log.action.normal(),
        };

        let task_short = if task_title.len() > 30 {
            format!("{}...", &task_title[..27])
        } else {
            task_title.clone()
        };

        println!("  {} {} {}",
            time,
            action,
            task_short.bold()
        );
    }
    println!();

    Ok(())
}

fn print_upcoming_tasks(db: &Database) -> Result<()> {
    println!("{}", "📋 PENDING TASKS (High Priority)".bold().underline());
    println!();

    let tasks = db.list_tasks(Some(TaskStatus::Pending))?;
    let high_priority: Vec<_> = tasks.iter()
        .filter(|t| matches!(t.priority, db::Priority::High | db::Priority::Critical))
        .take(5)
        .collect();

    if high_priority.is_empty() {
        println!("{}", "  No high-priority pending tasks.".dimmed());
        println!();
        return Ok(());
    }

    for task in high_priority {
        let priority_marker = match task.priority {
            db::Priority::Critical => "🔴",
            db::Priority::High => "🟡",
            _ => "⚪",
        };

        println!("  {} {} - {}",
            priority_marker,
            task.id[..8].to_string().dimmed(),
            task.title
        );
    }
    println!();

    Ok(())
}

fn run_dashboard(db_path: &str, refresh_rate: u64) -> Result<()> {
    loop {
        clear_screen();
        let db = Database::new(db_path)?;

        print_header();
        print_stats(&db)?;

        println!("{}", "───────────────────────────────────────────────────────────────".dimmed());
        println!();

        print_active_tasks(&db)?;
        print_blocked_tasks(&db)?;
        print_agents(&db)?;
        print_recent_activity(&db)?;
        print_upcoming_tasks(&db)?;

        println!("{}", "───────────────────────────────────────────────────────────────".dimmed());
        println!();
        println!("{}  |  Press Ctrl+C to exit",
            format!("Refreshing every {}s", refresh_rate).dimmed()
        );

        thread::sleep(Duration::from_secs(refresh_rate));
    }
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();

    let db_path = args.get(1)
        .map(|s| s.as_str())
        .unwrap_or("tools/prd.db");

    let refresh_rate = args.get(2)
        .and_then(|s| s.parse().ok())
        .unwrap_or(5);

    println!("{}", "Starting PRD Dashboard...".cyan().bold());
    println!("Database: {}", db_path);
    println!("Refresh rate: {}s", refresh_rate);
    thread::sleep(Duration::from_secs(1));

    run_dashboard(db_path, refresh_rate)
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

fn format_priority(priority: &db::Priority) -> String {
    match priority {
        db::Priority::Low => "Low".dimmed().to_string(),
        db::Priority::Medium => "Med".normal().to_string(),
        db::Priority::High => "High".yellow().bold().to_string(),
        db::Priority::Critical => "Crit".red().bold().to_string(),
    }
}

fn format_agent_status(status: &AgentStatus) -> String {
    match status {
        AgentStatus::Idle => "💤 Idle".dimmed().to_string(),
        AgentStatus::Working => "⚡ Working".green().bold().to_string(),
        AgentStatus::Blocked => "🚫 Blocked".red().to_string(),
        AgentStatus::Offline => "📴 Offline".dimmed().to_string(),
    }
}
