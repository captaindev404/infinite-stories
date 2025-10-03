use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;
use uuid::Uuid;

use crate::models::{MigrationStatusReport, MigrationReport, MigrationSummary, MigrationDetail, MigrationError};

#[derive(Clone)]
pub struct ProgressTracker {
    db_path: String,
}

impl ProgressTracker {
    pub fn new(db_path: &str) -> Result<Self> {
        let conn = Connection::open(db_path)?;

        // Create tables
        conn.execute(
            "CREATE TABLE IF NOT EXISTS migration_state (
                id INTEGER PRIMARY KEY,
                state TEXT NOT NULL,
                started_at TEXT,
                completed_at TEXT,
                last_activity TEXT,
                heroes_total INTEGER DEFAULT 0,
                heroes_migrated INTEGER DEFAULT 0,
                stories_total INTEGER DEFAULT 0,
                stories_migrated INTEGER DEFAULT 0,
                storage_total INTEGER DEFAULT 0,
                storage_migrated INTEGER DEFAULT 0
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS migration_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                status TEXT NOT NULL,
                started_at TEXT NOT NULL,
                completed_at TEXT,
                error TEXT,
                retry_count INTEGER DEFAULT 0,
                checkpoint_id TEXT,
                UNIQUE(entity_type, entity_id)
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS checkpoints (
                id TEXT PRIMARY KEY,
                created_at TEXT NOT NULL,
                entity_count INTEGER NOT NULL,
                description TEXT
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS errors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                error_message TEXT NOT NULL,
                occurred_at TEXT NOT NULL
            )",
            [],
        )?;

        Ok(Self {
            db_path: db_path.to_string(),
        })
    }

    fn conn(&self) -> Result<Connection> {
        Connection::open(&self.db_path).context("Failed to open database")
    }

    pub fn start_migration(&self) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT OR REPLACE INTO migration_state (id, state, started_at, last_activity)
             VALUES (1, 'in_progress', ?1, ?1)",
            params![now],
        )?;

        Ok(())
    }

    pub fn complete_migration(&self) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "UPDATE migration_state SET state = 'completed', completed_at = ?1, last_activity = ?1
             WHERE id = 1",
            params![now],
        )?;

        Ok(())
    }

    pub fn set_totals(&self, heroes: usize, stories: usize, storage: usize) -> Result<()> {
        let conn = self.conn()?;

        conn.execute(
            "UPDATE migration_state SET heroes_total = ?1, stories_total = ?2, storage_total = ?3
             WHERE id = 1",
            params![heroes as i64, stories as i64, storage as i64],
        )?;

        Ok(())
    }

    pub fn record_success(&self, entity_type: &str, entity_id: Uuid) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT OR REPLACE INTO migration_records
             (entity_type, entity_id, status, started_at, completed_at, retry_count)
             VALUES (?1, ?2, 'completed', ?3, ?3, 0)",
            params![entity_type, entity_id.to_string(), now],
        )?;

        // Update counters
        match entity_type {
            "hero" => {
                conn.execute(
                    "UPDATE migration_state SET heroes_migrated = heroes_migrated + 1, last_activity = ?1
                     WHERE id = 1",
                    params![now],
                )?;
            }
            "story" => {
                conn.execute(
                    "UPDATE migration_state SET stories_migrated = stories_migrated + 1, last_activity = ?1
                     WHERE id = 1",
                    params![now],
                )?;
            }
            _ => {}
        }

        Ok(())
    }

    pub fn record_error(&self, entity_type: &str, entity_id: Uuid, error: &str) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        // Record in migration_records
        conn.execute(
            "INSERT OR REPLACE INTO migration_records
             (entity_type, entity_id, status, started_at, error, retry_count)
             VALUES (?1, ?2, 'failed', ?3, ?4,
                     COALESCE((SELECT retry_count + 1 FROM migration_records
                               WHERE entity_type = ?1 AND entity_id = ?2), 0))",
            params![entity_type, entity_id.to_string(), now, error],
        )?;

        // Record in errors table
        conn.execute(
            "INSERT INTO errors (entity_type, entity_id, error_message, occurred_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![entity_type, entity_id.to_string(), error, now],
        )?;

        Ok(())
    }

    pub fn record_storage_success(&self, path: &str) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "UPDATE migration_state SET storage_migrated = storage_migrated + 1, last_activity = ?1
             WHERE id = 1",
            params![now],
        )?;

        Ok(())
    }

    pub fn record_storage_error(&self, path: &str, error: &str) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            "INSERT INTO errors (entity_type, entity_id, error_message, occurred_at)
             VALUES ('storage', ?1, ?2, ?3)",
            params![path, error, now],
        )?;

        Ok(())
    }

    pub fn create_checkpoint(&self, checkpoint_id: &str) -> Result<()> {
        let conn = self.conn()?;
        let now = Utc::now().to_rfc3339();

        let count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM migration_records WHERE status = 'completed'",
            [],
            |row| row.get(0),
        )?;

        conn.execute(
            "INSERT INTO checkpoints (id, created_at, entity_count)
             VALUES (?1, ?2, ?3)",
            params![checkpoint_id, now, count],
        )?;

        // Update checkpoint_id for recent records
        conn.execute(
            "UPDATE migration_records SET checkpoint_id = ?1
             WHERE checkpoint_id IS NULL AND status = 'completed'",
            params![checkpoint_id],
        )?;

        Ok(())
    }

    pub fn get_last_checkpoint(&self) -> Result<Option<String>> {
        let conn = self.conn()?;

        let checkpoint: Option<String> = conn.query_row(
            "SELECT id FROM checkpoints ORDER BY created_at DESC LIMIT 1",
            [],
            |row| row.get(0),
        ).optional()?;

        Ok(checkpoint)
    }

    pub fn get_entities_after_checkpoint(&self, checkpoint_id: &str) -> Result<Vec<(String, Uuid)>> {
        let conn = self.conn()?;

        let checkpoint_time: String = conn.query_row(
            "SELECT created_at FROM checkpoints WHERE id = ?1",
            params![checkpoint_id],
            |row| row.get(0),
        )?;

        let mut stmt = conn.prepare(
            "SELECT entity_type, entity_id FROM migration_records
             WHERE completed_at > ?1 AND status = 'completed'"
        )?;

        let entities = stmt.query_map(params![checkpoint_time], |row| {
            let entity_type: String = row.get(0)?;
            let entity_id_str: String = row.get(1)?;
            let entity_id = Uuid::parse_str(&entity_id_str)
                .unwrap_or_else(|_| Uuid::nil());
            Ok((entity_type, entity_id))
        })?;

        let mut result = Vec::new();
        for entity in entities {
            result.push(entity?);
        }

        Ok(result)
    }

    pub fn rollback_to_checkpoint(&self, checkpoint_id: &str) -> Result<()> {
        let conn = self.conn()?;

        // Delete records after checkpoint
        conn.execute(
            "DELETE FROM migration_records
             WHERE completed_at > (SELECT created_at FROM checkpoints WHERE id = ?1)",
            params![checkpoint_id],
        )?;

        // Delete checkpoints after this one
        conn.execute(
            "DELETE FROM checkpoints
             WHERE created_at > (SELECT created_at FROM checkpoints WHERE id = ?1)",
            params![checkpoint_id],
        )?;

        // Update state
        conn.execute(
            "UPDATE migration_state SET state = 'rolled_back', last_activity = ?1
             WHERE id = 1",
            params![Utc::now().to_rfc3339()],
        )?;

        Ok(())
    }

    pub fn get_migration_status(&self) -> Result<MigrationStatusReport> {
        let conn = self.conn()?;

        let (state, started_at, last_activity, heroes_total, heroes_migrated,
             stories_total, stories_migrated, storage_total, storage_migrated):
            (String, Option<String>, Option<String>, i64, i64, i64, i64, i64, i64) =
            conn.query_row(
                "SELECT state, started_at, last_activity, heroes_total, heroes_migrated,
                        stories_total, stories_migrated, storage_total, storage_migrated
                 FROM migration_state WHERE id = 1",
                [],
                |row| Ok((
                    row.get(0).unwrap_or_else(|_| "not_started".to_string()),
                    row.get(1).ok(),
                    row.get(2).ok(),
                    row.get(3).unwrap_or(0),
                    row.get(4).unwrap_or(0),
                    row.get(5).unwrap_or(0),
                    row.get(6).unwrap_or(0),
                    row.get(7).unwrap_or(0),
                    row.get(8).unwrap_or(0),
                )),
            ).unwrap_or((
                "not_started".to_string(), None, None, 0, 0, 0, 0, 0, 0
            ));

        // Get recent errors
        let mut stmt = conn.prepare(
            "SELECT error_message FROM errors ORDER BY occurred_at DESC LIMIT 10"
        )?;

        let errors: Vec<String> = stmt.query_map([], |row| row.get(0))?
            .filter_map(|r| r.ok())
            .collect();

        Ok(MigrationStatusReport {
            state,
            started_at: started_at.and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
                .map(|dt| dt.with_timezone(&Utc)),
            last_activity: last_activity.and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
                .map(|dt| dt.with_timezone(&Utc)),
            heroes_total: heroes_total as usize,
            heroes_migrated: heroes_migrated as usize,
            stories_total: stories_total as usize,
            stories_migrated: stories_migrated as usize,
            storage_total: storage_total as usize,
            storage_migrated: storage_migrated as usize,
            errors,
        })
    }

    pub fn generate_report(&self) -> Result<MigrationReport> {
        let conn = self.conn()?;

        // Get summary
        let (total, successful, failed, skipped): (i64, i64, i64, i64) = conn.query_row(
            "SELECT COUNT(*),
                    COUNT(CASE WHEN status = 'completed' THEN 1 END),
                    COUNT(CASE WHEN status = 'failed' THEN 1 END),
                    COUNT(CASE WHEN status = 'skipped' THEN 1 END)
             FROM migration_records",
            [],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
        )?;

        // Calculate duration
        let (started_at, completed_at): (Option<String>, Option<String>) = conn.query_row(
            "SELECT started_at, completed_at FROM migration_state WHERE id = 1",
            [],
            |row| Ok((row.get(0).ok(), row.get(1).ok())),
        ).unwrap_or((None, None));

        let duration_seconds = if let (Some(start), Some(end)) = (started_at, completed_at) {
            if let (Ok(start_dt), Ok(end_dt)) = (
                DateTime::parse_from_rfc3339(&start),
                DateTime::parse_from_rfc3339(&end)
            ) {
                (end_dt.timestamp() - start_dt.timestamp()) as f64
            } else {
                0.0
            }
        } else {
            0.0
        };

        let summary = MigrationSummary {
            total_entities: total as usize,
            successful: successful as usize,
            failed: failed as usize,
            skipped: skipped as usize,
            duration_seconds,
            average_rate_per_second: if duration_seconds > 0.0 {
                total as f64 / duration_seconds
            } else {
                0.0
            },
        };

        // Get details (sample)
        let mut stmt = conn.prepare(
            "SELECT entity_type, entity_id, status, retry_count
             FROM migration_records LIMIT 100"
        )?;

        let details: Vec<MigrationDetail> = stmt.query_map([], |row| {
            Ok(MigrationDetail {
                entity_type: row.get(0)?,
                entity_id: row.get(1)?,
                status: row.get(2)?,
                duration_ms: 0, // Would need to track this separately
                retries: row.get(3)?,
            })
        })?.filter_map(|r| r.ok()).collect();

        // Get errors
        let mut stmt = conn.prepare(
            "SELECT entity_type, entity_id, error_message, occurred_at
             FROM errors ORDER BY occurred_at DESC LIMIT 100"
        )?;

        let errors: Vec<MigrationError> = stmt.query_map([], |row| {
            let occurred_at_str: String = row.get(3)?;
            let timestamp = DateTime::parse_from_rfc3339(&occurred_at_str)
                .unwrap_or_else(|_| Utc::now().into())
                .with_timezone(&Utc);

            Ok(MigrationError {
                entity_type: row.get(0)?,
                entity_id: row.get(1)?,
                error_message: row.get(2)?,
                timestamp,
            })
        })?.filter_map(|r| r.ok()).collect();

        Ok(MigrationReport {
            generated_at: Utc::now(),
            summary,
            details,
            errors,
        })
    }
}