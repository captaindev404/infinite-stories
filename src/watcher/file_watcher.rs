use anyhow::Result;
use notify::{event::EventKind, Event, RecursiveMode, Watcher};
use rusqlite::params;
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::time::Duration;

use crate::db::Database;
use crate::sync::parse_completion_doc;

/// Statistics for the file watcher
#[derive(Debug, Default)]
struct WatcherStats {
    tasks_completed: usize,
    errors: usize,
    start_time: Option<std::time::Instant>,
}

/// File watcher for detecting new completion documents
pub struct FileWatcher {
    db: Database,
    docs_path: PathBuf,
    pub running: Arc<AtomicBool>,
    stats: Arc<Mutex<WatcherStats>>,
}

impl FileWatcher {
    /// Create a new file watcher
    pub fn new(docs_path: PathBuf, db: Database) -> Result<Self> {
        Ok(Self {
            db,
            docs_path,
            running: Arc::new(AtomicBool::new(false)),
            stats: Arc::new(Mutex::new(WatcherStats::default())),
        })
    }

    /// Start watching for file changes
    pub fn start(&mut self) -> Result<()> {
        println!(
            "👁 Watching {} for completion documents...",
            self.docs_path.display()
        );
        println!("Press Ctrl+C to stop...\n");

        self.running.store(true, Ordering::SeqCst);
        self.stats.lock().unwrap().start_time = Some(std::time::Instant::now());

        let docs_path = self.docs_path.clone();
        let running = Arc::clone(&self.running);
        let stats = Arc::clone(&self.stats);

        // Create watcher with recommended implementation
        let mut watcher =
            notify::recommended_watcher(move |res: Result<Event, notify::Error>| match res {
                Ok(event) => {
                    // Just collect events, we'll process them in the main loop
                    // This is simpler than trying to share the database across threads
                    match event.kind {
                        notify::EventKind::Create(_) | notify::EventKind::Modify(_) => {
                            for path in &event.paths {
                                if is_completion_doc(path) {
                                    println!(
                                        "✓ Detected new file: {}",
                                        path.file_name().unwrap().to_str().unwrap()
                                    );
                                }
                            }
                        }
                        _ => {}
                    }
                }
                Err(e) => {
                    eprintln!("Watch error: {:?}", e);
                    stats.lock().unwrap().errors += 1;
                }
            })?;

        // Watch directory for new files (non-recursive)
        watcher.watch(&docs_path, RecursiveMode::NonRecursive)?;

        // Keep running until stopped
        // Check for new files periodically
        let mut last_check = std::time::Instant::now();
        while running.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_millis(100));

            // Every second, scan for new completion docs
            if last_check.elapsed() > Duration::from_secs(1) {
                if let Err(e) = self.scan_and_process() {
                    eprintln!("❌ Error scanning for completions: {}", e);
                    self.stats.lock().unwrap().errors += 1;
                }
                last_check = std::time::Instant::now();
            }
        }

        println!("\n⏹ File watcher stopped");
        self.print_stats();

        Ok(())
    }

    /// Scan for new completion documents and process them
    fn scan_and_process(&self) -> Result<()> {
        use glob::glob;

        let pattern = self.docs_path.join("TASK-*.md");
        let pattern_str = pattern
            .to_str()
            .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

        for entry in glob(pattern_str)? {
            if let Ok(path) = entry {
                if is_completion_doc(&path) {
                    if let Err(e) = process_completion_doc(path, &self.db, &self.stats) {
                        eprintln!("❌ Error processing document: {}", e);
                        self.stats.lock().unwrap().errors += 1;
                    }
                }
            }
        }

        Ok(())
    }

    /// Stop the file watcher
    pub fn stop(&mut self) {
        self.running.store(false, Ordering::SeqCst);
    }

    /// Print watcher statistics
    fn print_stats(&self) {
        let stats = self.stats.lock().unwrap();
        if let Some(start) = stats.start_time {
            let uptime = start.elapsed();
            println!("\nStatistics:");
            println!("  Tasks auto-completed: {}", stats.tasks_completed);
            println!("  Errors: {}", stats.errors);
            println!("  Uptime: {}", format_duration(uptime));
        }
    }
}

/// Handle a file system event
fn handle_file_event(event: &Event, db: &Database, stats: &Arc<Mutex<WatcherStats>>) -> Result<()> {
    match event.kind {
        EventKind::Create(_) | EventKind::Modify(_) => {
            for path in &event.paths {
                if is_completion_doc(path) {
                    process_completion_doc(path.clone(), db, stats)?;
                }
            }
        }
        _ => {}
    }
    Ok(())
}

/// Check if a file is a completion document
fn is_completion_doc(path: &Path) -> bool {
    path.file_name()
        .and_then(|n| n.to_str())
        .map(|n| {
            n.starts_with("TASK-")
                && (n.contains("COMPLETION") || n.contains("COMPLETE"))
                && n.ends_with(".md")
        })
        .unwrap_or(false)
}

/// Process a completion document
fn process_completion_doc(
    path: PathBuf,
    db: &Database,
    stats: &Arc<Mutex<WatcherStats>>,
) -> Result<()> {
    // Parse using Phase 1 document scanner
    let doc = match parse_completion_doc(path.clone()) {
        Some(d) => d,
        None => {
            return Ok(()); // Skip if parsing failed
        }
    };

    {
        // Get task by display_id
        let task_result: Result<String, rusqlite::Error> = db.get_connection().query_row(
            "SELECT id, status FROM tasks WHERE display_id = ?1",
            params![doc.task_id],
            |row| Ok(row.get::<_, String>(0)?),
        );

        let task_uuid = match task_result {
            Ok(uuid) => uuid,
            Err(_) => {
                println!("  ⚠ Task #{} not found in database, skipping", doc.task_id);
                return Ok(());
            }
        };

        // Check if already complete
        let task = db.get_task(&task_uuid)?;
        if let Some(t) = task {
            if t.status.as_str() == "completed" {
                println!("  ⚠ Task #{} already complete, skipping", doc.task_id);
                return Ok(());
            }
        }

        // Mark complete with transaction
        let conn = db.get_connection();
        let tx = conn.unchecked_transaction()?;

        tx.execute(
            "UPDATE tasks
             SET status = 'completed',
                 completed_at = ?,
                 updated_at = ?
             WHERE display_id = ?",
            params![
                doc.completed_at.to_rfc3339(),
                chrono::Utc::now().to_rfc3339(),
                doc.task_id
            ],
        )?;

        // Update agent if provided
        if let Some(agent_id) = &doc.agent_id {
            // Try to resolve agent ID (could be A11 format or UUID)
            let agent_uuid_result: Result<String, rusqlite::Error> = tx.query_row(
                "SELECT id FROM agents WHERE display_id = ?1 OR id = ?2 OR name = ?3",
                params![
                    agent_id.trim_start_matches('A').parse::<i32>().ok(),
                    agent_id,
                    agent_id
                ],
                |row| row.get(0),
            );

            if let Ok(agent_uuid) = agent_uuid_result {
                tx.execute(
                    "UPDATE agents
                     SET status = 'idle',
                         current_task_id = NULL,
                         last_active = ?
                     WHERE id = ?",
                    params![chrono::Utc::now().to_rfc3339(), agent_uuid],
                )?;

                println!(
                    "  → Marked task #{} complete (agent {})",
                    doc.task_id, agent_id
                );
            } else {
                println!("  → Marked task #{} complete", doc.task_id);
            }
        } else {
            println!("  → Marked task #{} complete", doc.task_id);
        }

        tx.commit()?;

        // Update stats
        stats.lock().unwrap().tasks_completed += 1;
    }

    Ok(())
}

/// Format a duration for display
fn format_duration(d: Duration) -> String {
    let secs = d.as_secs();
    let hours = secs / 3600;
    let minutes = (secs % 3600) / 60;
    let seconds = secs % 60;

    if hours > 0 {
        format!("{}h {}m {}s", hours, minutes, seconds)
    } else if minutes > 0 {
        format!("{}m {}s", minutes, seconds)
    } else {
        format!("{}s", seconds)
    }
}
