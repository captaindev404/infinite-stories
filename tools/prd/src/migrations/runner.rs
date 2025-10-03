use anyhow::{Context, Result};
use rusqlite::{Connection, OptionalExtension};
use std::fs;
use std::path::Path;

pub struct MigrationRunner<'a> {
    conn: &'a Connection,
}

impl<'a> MigrationRunner<'a> {
    pub fn new(conn: &'a Connection) -> Self {
        Self { conn }
    }

    pub fn init(&self) -> Result<()> {
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL
            )",
            [],
        )?;
        Ok(())
    }

    pub fn get_current_version(&self) -> Result<i32> {
        let result = self
            .conn
            .query_row(
                "SELECT MAX(version) FROM schema_migrations",
                [],
                |row| row.get::<_, Option<i32>>(0),
            );

        match result {
            Ok(Some(version)) => Ok(version),
            Ok(None) => Ok(0),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(0),
            Err(e) => Err(e.into()),
        }
    }

    pub fn migrate_to_latest(&self) -> Result<Vec<i32>> {
        self.init()?;
        let current_version = self.get_current_version()?;

        // Try multiple paths to find migrations directory
        let possible_paths = vec![
            Path::new("tools/prd/migrations"),
            Path::new("migrations"),
            Path::new("./migrations"),
            Path::new("../migrations"),
        ];

        let migrations_dir = possible_paths
            .iter()
            .find(|p| p.exists())
            .ok_or_else(|| anyhow::anyhow!("No migrations directory found. Searched: {:?}", possible_paths))?;

        let mut migrations: Vec<(i32, String)> = Vec::new();

        for entry in fs::read_dir(migrations_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("sql") {
                if let Some(filename) = path.file_name().and_then(|s| s.to_str()) {
                    if let Some(version_str) = filename.split('_').next() {
                        if let Ok(version) = version_str.parse::<i32>() {
                            if version > current_version {
                                let content = fs::read_to_string(&path)?;
                                migrations.push((version, content));
                            }
                        }
                    }
                }
            }
        }

        migrations.sort_by_key(|(v, _)| *v);

        let mut applied_versions = Vec::new();

        for (version, sql) in migrations {
            println!("Applying migration {}...", version);

            self.conn.execute("BEGIN TRANSACTION", [])?;

            match self.apply_migration(version, &sql) {
                Ok(_) => {
                    self.conn.execute("COMMIT", [])?;
                    applied_versions.push(version);
                    println!("✓ Migration {} applied successfully", version);
                }
                Err(e) => {
                    self.conn.execute("ROLLBACK", [])?;
                    return Err(e).context(format!("Failed to apply migration {}", version));
                }
            }
        }

        Ok(applied_versions)
    }

    fn apply_migration(&self, version: i32, sql: &str) -> Result<()> {
        // Execute the migration SQL
        self.conn.execute_batch(sql)?;

        // Record the migration
        self.conn.execute(
            "INSERT INTO schema_migrations (version, applied_at) VALUES (?1, datetime('now'))",
            [version],
        )?;

        Ok(())
    }

    pub fn rollback(&self, target_version: i32) -> Result<()> {
        let current_version = self.get_current_version()?;

        if target_version >= current_version {
            println!("Already at or below version {}", target_version);
            return Ok(());
        }

        println!("⚠️  Warning: Rollback support is limited. This will only remove the migration record.");
        println!("   Manual intervention may be required to reverse schema changes.");

        self.conn.execute(
            "DELETE FROM schema_migrations WHERE version > ?1",
            [target_version],
        )?;

        println!("✓ Rolled back to version {}", target_version);
        Ok(())
    }

    pub fn status(&self) -> Result<()> {
        self.init()?;
        let current_version = self.get_current_version()?;

        println!("Current schema version: {}", current_version);

        let mut stmt = self.conn.prepare(
            "SELECT version, applied_at FROM schema_migrations ORDER BY version"
        )?;

        let migrations = stmt.query_map([], |row| {
            Ok((row.get::<_, i32>(0)?, row.get::<_, String>(1)?))
        })?;

        println!("\nApplied migrations:");
        for migration in migrations {
            let (version, applied_at) = migration?;
            println!("  {} - applied at {}", version, applied_at);
        }

        Ok(())
    }
}
