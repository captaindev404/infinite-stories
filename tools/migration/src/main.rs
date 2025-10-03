use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use colored::*;
use std::path::PathBuf;
use tracing::{info, warn, error};

mod config;
mod supabase;
mod firebase;
mod migrator;
mod progress;
mod models;
mod storage;

use config::MigrationConfig;
use migrator::DataMigrator;
use progress::ProgressTracker;

#[derive(Parser)]
#[command(name = "supabase-to-firebase-migration")]
#[command(author, version, about = "Migrate data from Supabase to Firebase", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Configuration file path
    #[arg(short, long, default_value = ".env")]
    config: PathBuf,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,

    /// Dry run mode (no actual data modification)
    #[arg(long)]
    dry_run: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Run the full migration
    Migrate {
        /// Batch size for processing records
        #[arg(long, default_value = "100")]
        batch_size: usize,

        /// Number of parallel workers
        #[arg(long, default_value = "4")]
        workers: usize,

        /// Resume from previous migration state
        #[arg(long)]
        resume: bool,
    },

    /// Validate data consistency between systems
    Validate {
        /// Sample size for validation (0 = all)
        #[arg(long, default_value = "100")]
        sample_size: usize,
    },

    /// Rollback migration to a specific checkpoint
    Rollback {
        /// Checkpoint ID to rollback to
        checkpoint_id: String,
    },

    /// Show migration status and statistics
    Status,

    /// Test connections to both Supabase and Firebase
    TestConnection,

    /// Export migration report
    Report {
        /// Output format (json, csv, html)
        #[arg(long, default_value = "json")]
        format: String,

        /// Output file path
        #[arg(long)]
        output: Option<PathBuf>,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    let log_level = if cli.verbose { "debug" } else { "info" };
    tracing_subscriber::fmt()
        .with_env_filter(log_level)
        .with_target(false)
        .init();

    // Load configuration
    dotenv::from_path(&cli.config).ok();
    let config = MigrationConfig::from_env()
        .context("Failed to load migration configuration")?;

    // Initialize progress tracker
    let progress_tracker = ProgressTracker::new("migration_progress.db")
        .context("Failed to initialize progress tracker")?;

    // Execute command
    match cli.command {
        Commands::Migrate { batch_size, workers, resume } => {
            info!("Starting data migration from Supabase to Firebase");

            if cli.dry_run {
                warn!("Running in DRY RUN mode - no data will be modified");
            }

            let mut migrator = DataMigrator::new(
                config,
                progress_tracker,
                batch_size,
                workers,
                cli.dry_run,
            )?;

            if resume {
                info!("Resuming migration from last checkpoint");
                migrator.resume_migration().await?;
            } else {
                migrator.run_full_migration().await?;
            }

            println!("{}", "Migration completed successfully!".green().bold());
        }

        Commands::Validate { sample_size } => {
            info!("Validating data consistency between Supabase and Firebase");

            let mut migrator = DataMigrator::new(
                config,
                progress_tracker,
                100,
                1,
                true, // Always dry run for validation
            )?;

            let results = migrator.validate_migration(sample_size).await?;

            println!("\n{}", "Validation Results:".cyan().bold());
            println!("  Heroes validated: {}", results.heroes_validated);
            println!("  Heroes matched: {}", results.heroes_matched.to_string().green());
            println!("  Heroes mismatched: {}", results.heroes_mismatched.to_string().yellow());

            println!("  Stories validated: {}", results.stories_validated);
            println!("  Stories matched: {}", results.stories_matched.to_string().green());
            println!("  Stories mismatched: {}", results.stories_mismatched.to_string().yellow());

            println!("  Storage files validated: {}", results.storage_validated);
            println!("  Storage files matched: {}", results.storage_matched.to_string().green());
            println!("  Storage files missing: {}", results.storage_missing.to_string().yellow());

            if results.is_valid() {
                println!("\n{}", "✓ Data validation passed!".green().bold());
            } else {
                println!("\n{}", "✗ Data validation failed!".red().bold());
                std::process::exit(1);
            }
        }

        Commands::Rollback { checkpoint_id } => {
            info!("Rolling back migration to checkpoint: {}", checkpoint_id);

            let mut migrator = DataMigrator::new(
                config,
                progress_tracker,
                100,
                1,
                cli.dry_run,
            )?;

            migrator.rollback_to_checkpoint(&checkpoint_id).await?;

            println!("{}", format!("Rollback to checkpoint {} completed!", checkpoint_id).green().bold());
        }

        Commands::Status => {
            let status = progress_tracker.get_migration_status()?;

            println!("\n{}", "Migration Status:".cyan().bold());
            println!("  State: {}", format_state(&status.state));
            println!("  Started: {}", status.started_at.map_or("Not started".to_string(), |d| d.to_string()));
            println!("  Last activity: {}", status.last_activity.map_or("None".to_string(), |d| d.to_string()));

            println!("\n{}", "Progress:".cyan().bold());
            println!("  Heroes: {}/{} ({}%)",
                status.heroes_migrated,
                status.heroes_total,
                if status.heroes_total > 0 { status.heroes_migrated * 100 / status.heroes_total } else { 0 }
            );
            println!("  Stories: {}/{} ({}%)",
                status.stories_migrated,
                status.stories_total,
                if status.stories_total > 0 { status.stories_migrated * 100 / status.stories_total } else { 0 }
            );
            println!("  Storage files: {}/{} ({}%)",
                status.storage_migrated,
                status.storage_total,
                if status.storage_total > 0 { status.storage_migrated * 100 / status.storage_total } else { 0 }
            );

            if !status.errors.is_empty() {
                println!("\n{}", "Recent Errors:".red().bold());
                for error in status.errors.iter().take(5) {
                    println!("  - {}", error);
                }
            }
        }

        Commands::TestConnection => {
            info!("Testing connections to Supabase and Firebase");

            let mut migrator = DataMigrator::new(
                config,
                progress_tracker,
                1,
                1,
                true,
            )?;

            println!("{}", "Testing connections...".cyan());

            let (supabase_ok, firebase_ok) = migrator.test_connections().await;

            if supabase_ok {
                println!("  {} Supabase connection", "✓".green().bold());
            } else {
                println!("  {} Supabase connection", "✗".red().bold());
            }

            if firebase_ok {
                println!("  {} Firebase connection", "✓".green().bold());
            } else {
                println!("  {} Firebase connection", "✗".red().bold());
            }

            if !supabase_ok || !firebase_ok {
                std::process::exit(1);
            }
        }

        Commands::Report { format, output } => {
            info!("Generating migration report");

            let report = progress_tracker.generate_report()?;

            let formatted = match format.as_str() {
                "json" => serde_json::to_string_pretty(&report)?,
                "csv" => report.to_csv()?,
                "html" => report.to_html()?,
                _ => {
                    error!("Unsupported format: {}", format);
                    std::process::exit(1);
                }
            };

            if let Some(output_path) = output {
                std::fs::write(output_path, formatted)?;
                println!("{}", "Report saved successfully!".green().bold());
            } else {
                println!("{}", formatted);
            }
        }
    }

    Ok(())
}

fn format_state(state: &str) -> colored::ColoredString {
    match state {
        "not_started" => state.white(),
        "in_progress" => state.yellow(),
        "completed" => state.green(),
        "failed" => state.red(),
        "rolled_back" => state.magenta(),
        _ => state.normal(),
    }
}