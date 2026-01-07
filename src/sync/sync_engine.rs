use crate::db::Database;
use crate::sync::doc_scanner::{scan_completion_docs, CompletionDoc};
use anyhow::{Context, Result};
use colored::*;
use std::path::Path;

/// Result of a sync operation
#[derive(Debug)]
pub struct SyncResult {
    pub newly_completed: usize,
    pub already_synced: usize,
    pub failed: Vec<SyncError>,
    pub duration_ms: u128,
}

#[derive(Debug)]
pub struct SyncError {
    pub task_id: i32,
    pub error: String,
}

enum SyncStatus {
    Completed,
    AlreadySynced,
}

/// Sync tasks from completion documents
///
/// # Arguments
/// * `db` - Database connection
/// * `docs_dir` - Path to docs/tasks/
/// * `dry_run` - If true, preview without applying changes
///
/// # Returns
/// * `Ok(SyncResult)` - Summary of sync operation
/// * `Err(_)` - Fatal error (e.g., database connection lost)
///
/// # Example
/// ```
/// use prd::sync::sync_tasks_from_docs;
/// use prd::db::Database;
/// use std::path::Path;
///
/// let db = Database::new("prd.db")?;
/// let result = sync_tasks_from_docs(&db, Path::new("docs/tasks"), false)?;
/// println!("Completed {} tasks", result.newly_completed);
/// ```
pub fn sync_tasks_from_docs(db: &Database, docs_dir: &Path, dry_run: bool) -> Result<SyncResult> {
    let start = std::time::Instant::now();

    // 1. Scan for completion documents
    println!(
        "{} Scanning {} for completion documents...",
        "🔍".cyan(),
        docs_dir.display()
    );

    let docs = scan_completion_docs(docs_dir).context("Failed to scan completion documents")?;

    if docs.is_empty() {
        println!("{}", "No completion documents found.".yellow());
        return Ok(SyncResult {
            newly_completed: 0,
            already_synced: 0,
            failed: Vec::new(),
            duration_ms: start.elapsed().as_millis(),
        });
    }

    println!("Found {} completion document(s)", docs.len());

    if dry_run {
        println!(
            "\n{} {}",
            "DRY RUN".yellow().bold(),
            "No changes will be made".dimmed()
        );
    }

    // 2. Process each document
    let mut newly_completed = 0;
    let mut already_synced = 0;
    let mut failed: Vec<SyncError> = Vec::new();

    for doc in docs {
        match process_completion_doc(db, &doc, dry_run) {
            Ok(status) => match status {
                SyncStatus::Completed => {
                    newly_completed += 1;
                    let action = if dry_run { "Would mark" } else { "Marked" };
                    println!(
                        "✓ {} task #{} complete ({})",
                        action.green(),
                        doc.task_id,
                        doc.file_path
                            .file_name()
                            .unwrap()
                            .to_str()
                            .unwrap()
                            .dimmed()
                    );
                }
                SyncStatus::AlreadySynced => {
                    already_synced += 1;
                    println!(
                        "⚠ Skipped task #{} (already marked complete)",
                        doc.task_id.to_string().dimmed()
                    );
                }
            },
            Err(e) => {
                failed.push(SyncError {
                    task_id: doc.task_id,
                    error: e.to_string(),
                });
                println!(
                    "❌ Failed to sync task #{}: {}",
                    doc.task_id.to_string().red(),
                    e.to_string().dimmed()
                );
            }
        }
    }

    // 3. Show summary
    println!("\n{}", "━".repeat(50).dimmed());
    println!("\n{}", "Summary:".bold());
    println!(
        "  Newly completed: {}",
        newly_completed.to_string().green().bold()
    );
    println!("  Already synced: {}", already_synced);
    if !failed.is_empty() {
        println!("  Errors: {}", failed.len().to_string().red());
    }

    let duration_ms = start.elapsed().as_millis();
    println!("  Time: {:.3}s", (duration_ms as f64 / 1000.0));

    Ok(SyncResult {
        newly_completed,
        already_synced,
        failed,
        duration_ms,
    })
}

/// Process a single completion document
fn process_completion_doc(db: &Database, doc: &CompletionDoc, dry_run: bool) -> Result<SyncStatus> {
    // 1. Check if task exists
    let task_result = db.get_connection().query_row(
        "SELECT id, status FROM tasks WHERE display_id = ?1",
        [doc.task_id],
        |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
    );

    let (task_uuid, current_status) = match task_result {
        Ok(data) => data,
        Err(_) => {
            return Err(anyhow::anyhow!(
                "Task #{} not found in database",
                doc.task_id
            ));
        }
    };

    // 2. Skip if already completed
    if current_status == "completed" {
        return Ok(SyncStatus::AlreadySynced);
    }

    // 3. If dry-run, stop here
    if dry_run {
        return Ok(SyncStatus::Completed);
    }

    // 4. Update task in transaction
    let conn = db.get_connection();
    let tx = conn.unchecked_transaction()?;

    // Update task
    tx.execute(
        "UPDATE tasks
         SET status = 'completed',
             completion_doc_path = ?1,
             auto_completed = TRUE,
             completed_at = ?2,
             updated_at = ?2
         WHERE id = ?3",
        rusqlite::params![
            doc.file_path.to_str(),
            doc.completed_at.to_rfc3339(),
            task_uuid
        ],
    )?;

    // Update agent to idle (if provided)
    if let Some(agent_id) = &doc.agent_id {
        // Resolve agent UUID
        if let Ok(agent_uuid) = crate::resolver::resolve_agent_id(&tx, agent_id) {
            tx.execute(
                "UPDATE agents
                 SET status = 'idle',
                     current_task_id = NULL,
                     last_active = ?1
                 WHERE id = ?2",
                rusqlite::params![chrono::Utc::now().to_rfc3339(), agent_uuid],
            )?;
        }
    }

    tx.commit()?;

    Ok(SyncStatus::Completed)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::{Database, Priority, TaskStatus};
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_sync_marks_task_complete() {
        // 1. Setup: Create test database
        let temp_db = tempfile::NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // 2. Create test task
        db.create_task("Test task".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        // 3. Create completion document
        let temp_docs = tempdir().unwrap();
        fs::write(
            temp_docs.path().join("TASK-001-COMPLETION.md"),
            "# Task Complete",
        )
        .unwrap();

        // 4. Run sync
        let result = sync_tasks_from_docs(&db, temp_docs.path(), false).unwrap();

        // 5. Verify
        assert_eq!(result.newly_completed, 1);
        assert_eq!(result.already_synced, 0);
        assert!(result.failed.is_empty());

        // 6. Verify task status in DB
        let tasks = db.list_tasks(Some(TaskStatus::Completed)).unwrap();
        assert_eq!(tasks.len(), 1);
        assert_eq!(tasks[0].status, TaskStatus::Completed);
    }

    #[test]
    fn test_sync_skips_already_completed() {
        // Setup database with completed task
        let temp_db = tempfile::NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        let task = db
            .create_task("Test".to_string(), None, Priority::Medium, None, None)
            .unwrap();
        db.update_task_status(&task.id, TaskStatus::Completed, None)
            .unwrap();

        // Create completion doc
        let temp_docs = tempdir().unwrap();
        fs::write(temp_docs.path().join("TASK-001-COMPLETION.md"), "# Done").unwrap();

        // Run sync
        let result = sync_tasks_from_docs(&db, temp_docs.path(), false).unwrap();

        // Verify skipped
        assert_eq!(result.already_synced, 1);
        assert_eq!(result.newly_completed, 0);
    }

    #[test]
    fn test_sync_dry_run_no_changes() {
        let temp_db = tempfile::NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        db.create_task("Test".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        let temp_docs = tempdir().unwrap();
        fs::write(temp_docs.path().join("TASK-001-COMPLETION.md"), "# Done").unwrap();

        // Run sync with dry_run = true
        let result = sync_tasks_from_docs(&db, temp_docs.path(), true).unwrap();

        // Verify preview worked
        assert_eq!(result.newly_completed, 1);

        // Verify database NOT updated
        let tasks = db.list_tasks(Some(TaskStatus::Completed)).unwrap();
        assert_eq!(tasks.len(), 0);
    }

    #[test]
    fn test_sync_handles_missing_task() {
        let temp_db = tempfile::NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create doc for non-existent task
        let temp_docs = tempdir().unwrap();
        fs::write(temp_docs.path().join("TASK-999-COMPLETION.md"), "# Done").unwrap();

        // Run sync
        let result = sync_tasks_from_docs(&db, temp_docs.path(), false).unwrap();

        // Verify error reported
        assert_eq!(result.failed.len(), 1);
        assert_eq!(result.failed[0].task_id, 999);
    }

    #[test]
    fn test_sync_updates_agent_status() {
        let temp_db = tempfile::NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create task and agent
        let task = db
            .create_task("Test".to_string(), None, Priority::Medium, None, None)
            .unwrap();
        let agent = db.create_agent("TestAgent".to_string()).unwrap();
        db.assign_task(&task.id, &agent.id).unwrap();

        // Create completion doc with agent_id
        let temp_docs = tempdir().unwrap();
        let content = r#"---
agent_id: A1
---
# Task Complete
"#;
        fs::write(temp_docs.path().join("TASK-001-COMPLETION.md"), content).unwrap();

        // Run sync
        sync_tasks_from_docs(&db, temp_docs.path(), false).unwrap();

        // Verify agent set to idle
        let updated_agent = db.get_agent(&agent.id).unwrap().unwrap();
        assert_eq!(updated_agent.status, crate::db::AgentStatus::Idle);
        assert!(updated_agent.current_task_id.is_none());
    }
}
