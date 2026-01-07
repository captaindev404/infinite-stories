use super::file_watcher::*;
use crate::db::{Database, Priority};
use std::path::Path;
use tempfile::TempDir;

#[test]
fn test_is_completion_doc() {
    assert!(is_completion_doc(Path::new("TASK-033-COMPLETION.md")));
    assert!(is_completion_doc(Path::new("TASK-050-COMPLETE.md")));
    assert!(is_completion_doc(Path::new(
        "TASK-100-IMPLEMENTATION-COMPLETE.md"
    )));
    assert!(!is_completion_doc(Path::new("README.md")));
    assert!(!is_completion_doc(Path::new("task-033.md")));
    assert!(!is_completion_doc(Path::new("TASK-033.md"))); // Missing COMPLETION/COMPLETE
    assert!(!is_completion_doc(Path::new("TASK-033-COMPLETION"))); // Missing .md
}

#[test]
fn test_file_watcher_creation() {
    let temp_dir = TempDir::new().unwrap();
    let db = Database::new(":memory:").unwrap();

    let watcher = FileWatcher::new(temp_dir.path().to_path_buf(), db);
    assert!(watcher.is_ok());
}

#[test]
fn test_format_duration() {
    use std::time::Duration;

    assert_eq!(format_duration(Duration::from_secs(30)), "30s");
    assert_eq!(format_duration(Duration::from_secs(90)), "1m 30s");
    assert_eq!(format_duration(Duration::from_secs(3661)), "1h 1m 1s");
    assert_eq!(format_duration(Duration::from_secs(7200)), "2h 0m 0s");
}

#[test]
fn test_process_completion_doc_basic() {
    use rusqlite::params;
    use std::fs;
    use std::sync::{Arc, Mutex};

    // Create test database with task
    let db = Database::new(":memory:").unwrap();
    let task = db
        .create_task(
            "Test Task".to_string(),
            None,
            Priority::Medium,
            None,
            None,
        )
        .unwrap();
    let task_display_id = task.display_id.unwrap();

    // Create completion document
    let temp_dir = TempDir::new().unwrap();
    let doc_path = temp_dir
        .path()
        .join(format!("TASK-{}-COMPLETION.md", task_display_id));
    fs::write(&doc_path, format!("# Task {} Complete", task_display_id)).unwrap();

    // Process it
    let stats = Arc::new(Mutex::new(WatcherStats::default()));
    process_completion_doc(doc_path, &db, &stats).unwrap();

    // Verify task is complete
    let updated_task = db.get_task(&task.id).unwrap().unwrap();
    assert_eq!(updated_task.status.as_str(), "completed");
    assert_eq!(stats.lock().unwrap().tasks_completed, 1);
}

#[test]
fn test_process_completion_doc_with_agent() {
    use rusqlite::params;
    use std::fs;
    use std::sync::{Arc, Mutex};

    // Create test database with task and agent
    let db = Database::new(":memory:").unwrap();
    let agent = db.create_agent("test-agent".to_string()).unwrap();
    let agent_display_id = agent.display_id.unwrap();

    let task = db
        .create_task(
            "Test Task".to_string(),
            None,
            Priority::Medium,
            None,
            None,
        )
        .unwrap();
    let task_display_id = task.display_id.unwrap();

    // Assign task to agent
    db.assign_task(&task.id, &agent.id).unwrap();

    // Create completion document with frontmatter
    let temp_dir = TempDir::new().unwrap();
    let doc_path = temp_dir
        .path()
        .join(format!("TASK-{}-COMPLETION.md", task_display_id));
    let content = format!(
        r#"---
agent_id: A{}
---

# Task {} Complete
"#,
        agent_display_id, task_display_id
    );
    fs::write(&doc_path, content).unwrap();

    // Process it
    let stats = Arc::new(Mutex::new(WatcherStats::default()));
    process_completion_doc(doc_path, &db, &stats).unwrap();

    // Verify task is complete
    let updated_task = db.get_task(&task.id).unwrap().unwrap();
    assert_eq!(updated_task.status.as_str(), "completed");

    // Verify agent is idle
    let updated_agent = db.get_agent(&agent.id).unwrap().unwrap();
    assert_eq!(updated_agent.status.as_str(), "idle");
    assert_eq!(updated_agent.current_task_id, None);

    assert_eq!(stats.lock().unwrap().tasks_completed, 1);
}

#[test]
fn test_process_completion_doc_already_complete() {
    use rusqlite::params;
    use std::fs;
    use std::sync::{Arc, Mutex};

    // Create test database with completed task
    let db = Database::new(":memory:").unwrap();
    let task = db
        .create_task(
            "Test Task".to_string(),
            None,
            Priority::Medium,
            None,
            None,
        )
        .unwrap();
    let task_display_id = task.display_id.unwrap();

    // Mark task as complete
    db.update_task_status(
        &task.id,
        crate::db::TaskStatus::Completed,
        None,
    )
    .unwrap();

    // Create completion document
    let temp_dir = TempDir::new().unwrap();
    let doc_path = temp_dir
        .path()
        .join(format!("TASK-{}-COMPLETION.md", task_display_id));
    fs::write(&doc_path, format!("# Task {} Complete", task_display_id)).unwrap();

    // Process it
    let stats = Arc::new(Mutex::new(WatcherStats::default()));
    process_completion_doc(doc_path, &db, &stats).unwrap();

    // Verify stats unchanged (already complete)
    assert_eq!(stats.lock().unwrap().tasks_completed, 0);
}

#[test]
fn test_process_completion_doc_nonexistent_task() {
    use std::fs;
    use std::sync::{Arc, Mutex};

    // Create test database (no tasks)
    let db = Database::new(":memory:").unwrap();

    // Create completion document for nonexistent task
    let temp_dir = TempDir::new().unwrap();
    let doc_path = temp_dir.path().join("TASK-999-COMPLETION.md");
    fs::write(&doc_path, "# Task 999 Complete").unwrap();

    // Process it
    let stats = Arc::new(Mutex::new(WatcherStats::default()));
    let result = process_completion_doc(doc_path, &db, &stats);

    // Should not error, just skip
    assert!(result.is_ok());
    assert_eq!(stats.lock().unwrap().tasks_completed, 0);
}
