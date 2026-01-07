use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use colored::*;
use serde::Deserialize;
use std::path::Path;

use crate::db::Database;

/// A single task completion record
#[derive(Debug, Clone, Deserialize)]
pub struct CompletionRecord {
    /// Task ID (integer or "#42" format)
    pub task: String,

    /// Agent ID (e.g., "A11" or agent name)
    pub agent: String,

    /// Optional completion timestamp (defaults to now)
    #[serde(default = "default_timestamp")]
    pub timestamp: DateTime<Utc>,
}

fn default_timestamp() -> DateTime<Utc> {
    Utc::now()
}

/// Result of batch completion
#[derive(Debug)]
pub struct BatchResult {
    pub completed: usize,
    pub failed: Vec<BatchError>,
    pub duration_ms: u128,
}

#[derive(Debug)]
pub struct BatchError {
    pub task_id: String,
    pub agent_id: String,
    pub error: String,
}

/// Parse completion records from CLI arguments
///
/// Example:
/// --tasks "33,34,35" --agent-map "33:A11,34:A11,35:A12"
pub fn parse_cli_args(tasks: &str, agent_map: &str) -> Result<Vec<CompletionRecord>> {
    let task_ids: Vec<&str> = tasks.split(',').map(|s| s.trim()).collect();

    // Parse agent map: "33:A11,34:A11,35:A12"
    let mut agent_mapping = std::collections::HashMap::new();
    for pair in agent_map.split(',') {
        let parts: Vec<&str> = pair.split(':').collect();
        if parts.len() != 2 {
            anyhow::bail!(
                "Invalid agent-map format. Expected 'task:agent', got '{}'",
                pair
            );
        }
        agent_mapping.insert(parts[0].trim(), parts[1].trim());
    }

    // Build records
    let mut records = Vec::new();
    for task_id in task_ids {
        let agent = agent_mapping
            .get(task_id)
            .ok_or_else(|| anyhow::anyhow!("No agent specified for task {}", task_id))?;

        records.push(CompletionRecord {
            task: task_id.to_string(),
            agent: agent.to_string(),
            timestamp: Utc::now(),
        });
    }

    Ok(records)
}

/// Parse completion records from JSON file
///
/// Expected format:
/// ```json
/// [
///   {
///     "task": "33",
///     "agent": "A11",
///     "timestamp": "2025-10-13T10:30:00Z"
///   }
/// ]
/// ```
pub fn parse_json_file(path: &Path) -> Result<Vec<CompletionRecord>> {
    let content = std::fs::read_to_string(path).context("Failed to read JSON file")?;

    let records: Vec<CompletionRecord> =
        serde_json::from_str(&content).context("Failed to parse JSON")?;

    if records.is_empty() {
        anyhow::bail!("JSON file contains no records");
    }

    Ok(records)
}

/// Parse completion records from CSV file
///
/// Expected format:
/// ```csv
/// task,agent,timestamp
/// 33,A11,2025-10-13T10:30:00Z
/// 34,A11,2025-10-13T11:00:00Z
/// ```
pub fn parse_csv_file(path: &Path) -> Result<Vec<CompletionRecord>> {
    let mut reader = csv::Reader::from_path(path).context("Failed to open CSV file")?;

    let mut records = Vec::new();

    for result in reader.deserialize() {
        let record: CompletionRecord = result.context("Failed to parse CSV record")?;
        records.push(record);
    }

    if records.is_empty() {
        anyhow::bail!("CSV file contains no records");
    }

    Ok(records)
}

/// Complete multiple tasks at once
///
/// # Arguments
/// * `db` - Database connection
/// * `records` - List of completion records
///
/// # Returns
/// * `Ok(BatchResult)` - Summary of batch operation
///
/// # Behavior
/// - Uses a single transaction (atomic)
/// - Shows progress for large batches
/// - Validates all inputs before applying changes
pub fn complete_batch(db: &Database, records: Vec<CompletionRecord>) -> Result<BatchResult> {
    let start = std::time::Instant::now();

    println!(
        "{} Preparing to complete {} task(s)...",
        "⚙".cyan(),
        records.len()
    );

    // 1. Validate all records first (fail-fast)
    println!("{} Validating inputs...", "🔍".cyan());
    let validated = validate_records(db, &records)?;

    // 2. Show summary before applying
    println!("\n{}", "Summary:".bold());
    println!("  Tasks: {}", validated.len());
    let agents: std::collections::HashSet<_> = validated.iter().map(|r| r.agent.as_str()).collect();
    println!(
        "  Agents: {} ({})",
        agents.len(),
        agents
            .iter()
            .take(3)
            .cloned()
            .collect::<Vec<_>>()
            .join(", ")
    );

    // 3. Apply changes in transaction
    println!("\n{} Applying changes...\n", "⚡".cyan());

    let conn = db.get_connection();
    let tx = conn.unchecked_transaction()?;

    let mut completed = 0;
    let mut failed = Vec::new();

    // Show progress bar for large batches
    let show_progress = validated.len() > 10;
    let pb = if show_progress {
        use indicatif::{ProgressBar, ProgressStyle};
        let pb = ProgressBar::new(validated.len() as u64);
        pb.set_style(
            ProgressStyle::default_bar()
                .template("{spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} ({eta})")
                .unwrap()
                .progress_chars("#>-"),
        );
        Some(pb)
    } else {
        None
    };

    for record in &validated {
        match complete_single_task(&tx, record) {
            Ok(_) => {
                completed += 1;
                if !show_progress {
                    println!(
                        "✓ Completed task {} (agent {})",
                        record.task.cyan(),
                        record.agent.dimmed()
                    );
                }
                if let Some(pb) = &pb {
                    pb.inc(1);
                }
            }
            Err(e) => {
                failed.push(BatchError {
                    task_id: record.task.clone(),
                    agent_id: record.agent.clone(),
                    error: e.to_string(),
                });
                println!(
                    "❌ Failed task {}: {}",
                    record.task.red(),
                    e.to_string().dimmed()
                );
            }
        }
    }

    if let Some(pb) = pb {
        pb.finish_with_message("Done!");
    }

    // 4. Commit or rollback
    if failed.is_empty() {
        tx.commit()?;
        println!("\n{} All changes committed", "✓".green().bold());
    } else {
        drop(tx); // Rollback
        anyhow::bail!("Batch operation failed. No changes applied.");
    }

    let duration_ms = start.elapsed().as_millis();

    // 5. Show summary
    println!("\n{}", "━".repeat(50).dimmed());
    println!("\n{}", "Result:".bold());
    println!("  Completed: {}", completed.to_string().green().bold());
    if !failed.is_empty() {
        println!("  Failed: {}", failed.len().to_string().red());
    }
    println!("  Time: {:.2}s", duration_ms as f64 / 1000.0);

    Ok(BatchResult {
        completed,
        failed,
        duration_ms,
    })
}

/// Validate all records before applying
fn validate_records(db: &Database, records: &[CompletionRecord]) -> Result<Vec<CompletionRecord>> {
    let mut validated = Vec::new();
    let mut errors = Vec::new();

    for record in records {
        // Check task exists
        let task_uuid_result = crate::resolver::resolve_task_id(db.get_connection(), &record.task);

        if task_uuid_result.is_err() {
            errors.push(format!("Task {} not found", record.task));
            continue;
        }

        // Check agent exists (or can be created)
        let agent_uuid_result =
            crate::resolver::resolve_agent_id(db.get_connection(), &record.agent);

        if agent_uuid_result.is_err() {
            // Agent doesn't exist - this is OK, we'll create it
            // But warn the user
            println!(
                "⚠ Agent {} not found. Will create if needed.",
                record.agent.yellow()
            );
        }

        validated.push(record.clone());
    }

    if !errors.is_empty() {
        anyhow::bail!("Validation failed:\n  {}", errors.join("\n  "));
    }

    Ok(validated)
}

/// Complete a single task (within transaction)
fn complete_single_task(tx: &rusqlite::Transaction, record: &CompletionRecord) -> Result<()> {
    // 1. Resolve task UUID
    let task_uuid = crate::resolver::resolve_task_id(tx, &record.task)?;

    // 2. Update task status
    tx.execute(
        "UPDATE tasks
         SET status = 'completed',
             completed_at = ?1,
             updated_at = ?1
         WHERE id = ?2",
        rusqlite::params![record.timestamp.to_rfc3339(), task_uuid],
    )?;

    // 3. Resolve or create agent
    let agent_uuid = match crate::resolver::resolve_agent_id(tx, &record.agent) {
        Ok(uuid) => uuid,
        Err(_) => {
            // Create agent
            Database::create_agent_in_tx(tx, record.agent.clone())?
        }
    };

    // 4. Set agent to idle
    tx.execute(
        "UPDATE agents
         SET status = 'idle',
             current_task_id = NULL,
             last_active = ?1
         WHERE id = ?2",
        rusqlite::params![record.timestamp.to_rfc3339(), agent_uuid],
    )?;

    Ok(())
}

#[cfg(test)]
#[path = "tests/complete_tests.rs"]
mod tests;
