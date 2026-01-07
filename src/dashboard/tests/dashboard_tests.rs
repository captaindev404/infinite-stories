use crate::dashboard::state::{DashboardState, ActivityEvent};
use crate::db::{Database, Priority};
use anyhow::Result;
use chrono::Utc;

#[test]
fn test_dashboard_state_creation() {
    let state = DashboardState::new();
    assert_eq!(state.agents.len(), 0);
    assert_eq!(state.overall_progress, 0.0);
    assert_eq!(state.completed_count, 0);
    assert_eq!(state.total_count, 0);
}

#[test]
fn test_dashboard_refresh() -> Result<()> {
    let db = Database::new(":memory:")?;

    // Create some agents
    let agent1 = db.create_agent("agent-1".to_string())?;
    let agent2 = db.create_agent("agent-2".to_string())?;

    // Create some tasks
    let _task1 = db.create_task(
        "Task 1".to_string(),
        None,
        Priority::High,
        None,
        None,
    )?;
    let task2 = db.create_task(
        "Task 2".to_string(),
        None,
        Priority::Medium,
        None,
        None,
    )?;

    // Assign task and update status
    db.assign_task(&task2.id, &agent1.id)?;
    db.update_agent_status(&agent1.id, crate::db::AgentStatus::Working, Some(&task2.id))?;

    // Create dashboard state and refresh
    let mut state = DashboardState::new();
    state.refresh(&db)?;

    // Verify agents were loaded
    assert_eq!(state.agents.len(), 2);
    assert_eq!(state.total_count, 2);

    Ok(())
}

#[test]
fn test_add_activity() {
    let mut state = DashboardState::new();

    state.add_activity("Test event 1".to_string());
    assert_eq!(state.recent_activity.len(), 1);

    state.add_activity("Test event 2".to_string());
    assert_eq!(state.recent_activity.len(), 2);

    // Add 10 more events to test the limit
    for i in 3..=15 {
        state.add_activity(format!("Test event {}", i));
    }

    // Should cap at 10
    assert_eq!(state.recent_activity.len(), 10);
}

#[test]
fn test_format_elapsed() {
    use std::time::Duration;

    let one_min = Duration::from_secs(60);
    assert_eq!(DashboardState::format_elapsed(one_min), "1m 0s");

    let five_mins = Duration::from_secs(300);
    assert_eq!(DashboardState::format_elapsed(five_mins), "5m 0s");

    let one_hour = Duration::from_secs(3600);
    assert_eq!(DashboardState::format_elapsed(one_hour), "1h 0m");

    let complex = Duration::from_secs(3723); // 1h 2m 3s
    assert_eq!(DashboardState::format_elapsed(complex), "1h 2m");
}

#[test]
fn test_progress_integration() -> Result<()> {
    let db = Database::new(":memory:")?;

    // Create agent and task
    let agent = db.create_agent("test-agent".to_string())?;
    let task = db.create_task(
        "Test task".to_string(),
        None,
        Priority::High,
        None,
        None,
    )?;
    let task_display_id = task.display_id.unwrap();

    // Report progress
    db.report_progress(&agent.id, task_display_id, 50, Some("Half done".to_string()))?;

    // Create and refresh dashboard
    let mut state = DashboardState::new();
    state.refresh(&db)?;

    // Verify agent progress is loaded
    assert_eq!(state.agents.len(), 1);
    let agent_display = &state.agents[0];
    assert_eq!(agent_display.progress, 50);

    Ok(())
}
