use super::state::{AgentDisplay, DashboardState};
use crate::db::{AgentStatus, Database, TaskStatus};
use crate::notifications::{NotificationConfig, Notifier};
use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Cell, Gauge, Paragraph, Row, Table},
    Frame, Terminal,
};
use std::collections::HashSet;
use std::io;
use std::time::{Duration, Instant};

/// Run the live dashboard in the terminal
pub fn run_dashboard(db_path: &str, refresh_interval: u64) -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create database and state
    let db = Database::new(db_path)?;
    let mut state = DashboardState::new();
    state.refresh(&db)?;

    // Initialize notification system
    let notif_config = NotificationConfig::load().unwrap_or_default();
    let mut notifier = Notifier::new(notif_config);

    // Track state for change detection
    let mut completed_tasks: HashSet<String> = HashSet::new();
    let mut blocked_agents: HashSet<String> = HashSet::new();
    let mut last_overall_progress = 0.0;

    // Initialize with current state
    for task in db.list_tasks(Some(TaskStatus::Completed))? {
        completed_tasks.insert(task.id.clone());
    }

    let refresh_duration = Duration::from_secs(refresh_interval);
    let mut last_refresh = Instant::now();

    // Main loop
    let result = loop {
        // Draw UI
        terminal.draw(|f| ui(f, &state))?;

        // Handle events
        let timeout = refresh_duration
            .checked_sub(last_refresh.elapsed())
            .unwrap_or(Duration::from_secs(0));

        if event::poll(timeout)? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => break Ok(()),
                    KeyCode::Char('r') => {
                        state.refresh(&db)?;
                        last_refresh = Instant::now();
                    }
                    KeyCode::Char('s') => {
                        // Trigger sync - placeholder for now
                        state.add_activity("Manual sync triggered".to_string());
                    }
                    KeyCode::Char('h') | KeyCode::Char('?') => {
                        state.add_activity("Help: q=quit, r=refresh, s=sync".to_string());
                    }
                    _ => {}
                }
            }
        }

        // Auto refresh
        if last_refresh.elapsed() >= refresh_duration {
            state.refresh(&db)?;
            last_refresh = Instant::now();

            // Check for newly completed tasks
            if let Ok(newly_completed) = detect_newly_completed_tasks(&db, &mut completed_tasks) {
                for (task, agent) in newly_completed {
                    if let Err(e) = notifier.notify_task_complete(&task, &agent) {
                        eprintln!("Failed to send completion notification: {}", e);
                    }
                }
            }

            // Check for blocked agents
            if let Ok(errors) = detect_agent_errors(&db, &mut blocked_agents) {
                for (task, agent, error) in errors {
                    if let Err(e) = notifier.notify_agent_error(&task, &agent, &error) {
                        eprintln!("Failed to send error notification: {}", e);
                    }
                }
            }

            // Check milestones
            let current_progress = state.overall_progress;
            if current_progress != last_overall_progress {
                check_and_notify_milestones(
                    &mut notifier,
                    current_progress,
                    state.completed_count,
                    state.total_count,
                );
                last_overall_progress = current_progress;
            }
        }
    };

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    result
}

/// Render the UI
fn ui(f: &mut Frame, state: &DashboardState) {
    let size = f.size();

    // Create layout
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(5), // Header with progress
            Constraint::Min(10),   // Agent table
            Constraint::Length(8), // Activity log
            Constraint::Length(1), // Footer
        ])
        .split(size);

    // Render header
    render_header(f, state, chunks[0]);

    // Render agent table
    render_agent_table(f, state, chunks[1]);

    // Render activity log
    render_activity_log(f, state, chunks[2]);

    // Render footer
    render_footer(f, chunks[3]);
}

/// Render header with overall progress
fn render_header(f: &mut Frame, state: &DashboardState, area: Rect) {
    let block = Block::default()
        .title(" PRD Tool - Live Agent Dashboard ")
        .title_alignment(Alignment::Center)
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Cyan));

    let inner = block.inner(area);
    f.render_widget(block, area);

    // Layout for header content
    let header_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Length(1)])
        .split(inner);

    // Progress info
    let progress_text = format!(
        "Overall Progress: {}/{} tasks ({:.1}%)",
        state.completed_count, state.total_count, state.overall_progress
    );
    let progress_para = Paragraph::new(progress_text)
        .style(Style::default().fg(Color::White))
        .alignment(Alignment::Center);
    f.render_widget(progress_para, header_chunks[0]);

    // Progress bar
    let gauge = Gauge::default()
        .block(Block::default())
        .gauge_style(
            Style::default()
                .fg(Color::Green)
                .bg(Color::Black)
                .add_modifier(Modifier::BOLD),
        )
        .ratio(state.overall_progress / 100.0);
    f.render_widget(gauge, header_chunks[1]);
}

/// Render agent table
fn render_agent_table(f: &mut Frame, state: &DashboardState, area: Rect) {
    let block = Block::default()
        .title(" Agents ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Cyan));

    let header = Row::new(vec![
        Cell::from("Agent").style(Style::default().add_modifier(Modifier::BOLD)),
        Cell::from("Status").style(Style::default().add_modifier(Modifier::BOLD)),
        Cell::from("Task").style(Style::default().add_modifier(Modifier::BOLD)),
        Cell::from("Progress").style(Style::default().add_modifier(Modifier::BOLD)),
        Cell::from("Elapsed").style(Style::default().add_modifier(Modifier::BOLD)),
    ])
    .height(1);

    let rows: Vec<Row> = state
        .agents
        .iter()
        .map(|agent| {
            let status_style = get_status_style(&agent.status);
            let status_text = format_status(&agent.status);

            let task_text = agent
                .current_task
                .map(|id| format!("#{}", id))
                .unwrap_or_else(|| "-".to_string());

            let progress_text = if agent.status == AgentStatus::Working {
                format!("{}%", agent.progress)
            } else {
                "-".to_string()
            };

            let elapsed_text = if agent.status == AgentStatus::Working {
                DashboardState::format_elapsed(agent.elapsed)
            } else {
                "-".to_string()
            };

            Row::new(vec![
                Cell::from(agent.name.clone()),
                Cell::from(status_text).style(status_style),
                Cell::from(task_text),
                Cell::from(progress_text),
                Cell::from(elapsed_text),
            ])
        })
        .collect();

    let table = Table::new(
        rows,
        [
            Constraint::Percentage(25),
            Constraint::Percentage(20),
            Constraint::Percentage(15),
            Constraint::Percentage(20),
            Constraint::Percentage(20),
        ],
    )
    .header(header)
    .block(block)
    .column_spacing(1);

    f.render_widget(table, area);
}

/// Render activity log
fn render_activity_log(f: &mut Frame, state: &DashboardState, area: Rect) {
    let block = Block::default()
        .title(" Recent Activity ")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Cyan));

    let inner = block.inner(area);
    f.render_widget(block, area);

    let lines: Vec<Line> = state
        .recent_activity
        .iter()
        .take(6)
        .map(|event| {
            let time_str = event.timestamp.format("%H:%M:%S").to_string();
            Line::from(vec![
                Span::styled(time_str, Style::default().fg(Color::DarkGray)),
                Span::raw(" - "),
                Span::styled(event.message.clone(), Style::default().fg(Color::White)),
            ])
        })
        .collect();

    let paragraph = Paragraph::new(lines).style(Style::default());
    f.render_widget(paragraph, inner);
}

/// Render footer with keyboard shortcuts
fn render_footer(f: &mut Frame, area: Rect) {
    let footer_text = " [q] Quit  [r] Refresh  [s] Sync  [h] Help ";
    let footer = Paragraph::new(footer_text)
        .style(Style::default().fg(Color::DarkGray))
        .alignment(Alignment::Center);
    f.render_widget(footer, area);
}

/// Get color style for agent status
fn get_status_style(status: &AgentStatus) -> Style {
    match status {
        AgentStatus::Working => Style::default()
            .fg(Color::Green)
            .add_modifier(Modifier::BOLD),
        AgentStatus::Idle => Style::default().fg(Color::Gray),
        AgentStatus::Blocked => Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        AgentStatus::Offline => Style::default().fg(Color::DarkGray),
    }
}

/// Format status as display text
fn format_status(status: &AgentStatus) -> String {
    match status {
        AgentStatus::Working => "● Working",
        AgentStatus::Idle => "○ Idle",
        AgentStatus::Blocked => "■ Blocked",
        AgentStatus::Offline => "✕ Offline",
    }
    .to_string()
}

/// Detect newly completed tasks since last check
fn detect_newly_completed_tasks(
    db: &Database,
    completed_tasks: &mut HashSet<String>,
) -> Result<Vec<(crate::db::Task, crate::db::Agent)>> {
    let mut newly_completed = Vec::new();

    // Get all currently completed tasks
    let current_completed = db.list_tasks(Some(TaskStatus::Completed))?;

    for task in current_completed {
        // If this task wasn't in our set, it's newly completed
        if !completed_tasks.contains(&task.id) {
            // Mark as seen
            completed_tasks.insert(task.id.clone());

            // Try to get the agent who completed it
            if let Some(agent_id) = &task.assigned_agent {
                if let Ok(Some(agent)) = db.get_agent(agent_id) {
                    newly_completed.push((task, agent));
                }
            }
        }
    }

    Ok(newly_completed)
}

/// Detect agents with errors or blocked status
fn detect_agent_errors(
    db: &Database,
    blocked_agents: &mut HashSet<String>,
) -> Result<Vec<(crate::db::Task, crate::db::Agent, String)>> {
    let mut errors = Vec::new();

    // Get all agents
    let agents = db.list_agents()?;

    for agent in agents {
        // Check if agent is blocked
        if agent.status == AgentStatus::Blocked {
            // If this agent wasn't blocked before, it's a new error
            if !blocked_agents.contains(&agent.id) {
                blocked_agents.insert(agent.id.clone());

                // Try to get the task they're blocked on
                if let Some(task_id) = &agent.current_task_id {
                    if let Ok(Some(task)) = db.get_task(task_id) {
                        let error_msg =
                            format!("Agent blocked on task #{}", task.display_id.unwrap_or(0));
                        errors.push((task, agent.clone(), error_msg));
                    }
                }
            }
        } else {
            // Agent is no longer blocked, remove from tracking
            blocked_agents.remove(&agent.id);
        }
    }

    Ok(errors)
}

/// Check and notify for milestone achievements
fn check_and_notify_milestones(
    notifier: &mut Notifier,
    current_progress: f64,
    completed: i32,
    total: i32,
) {
    let percentage = current_progress as u8;

    // Check each milestone threshold
    if percentage >= 25 && percentage < 50 {
        let _ = notifier.notify_milestone(25, completed, total);
    } else if percentage >= 50 && percentage < 75 {
        let _ = notifier.notify_milestone(50, completed, total);
    } else if percentage >= 75 && percentage < 100 {
        let _ = notifier.notify_milestone(75, completed, total);
    } else if percentage == 100 {
        let _ = notifier.notify_milestone(100, completed, total);
    }
}
