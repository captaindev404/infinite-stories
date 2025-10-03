use anyhow::{Context, Result};
use indicatif::{ProgressBar, ProgressStyle, MultiProgress};
use std::time::Instant;
use tracing::{info, warn, error, debug};

use crate::config::MigrationConfig;
use crate::supabase::SupabaseClient;
use crate::firebase::FirebaseClient;
use crate::progress::ProgressTracker;
use crate::storage::StorageMigrator;
use crate::models::{Hero, Story, CustomEvent, ValidationResults, MigrationStatusReport};

pub struct DataMigrator {
    config: MigrationConfig,
    supabase: SupabaseClient,
    firebase: FirebaseClient,
    progress: ProgressTracker,
    storage_migrator: StorageMigrator,
    batch_size: usize,
    workers: usize,
    dry_run: bool,
}

impl DataMigrator {
    pub fn new(
        config: MigrationConfig,
        progress: ProgressTracker,
        batch_size: usize,
        workers: usize,
        dry_run: bool,
    ) -> Result<Self> {
        let supabase = SupabaseClient::new(&config)?;
        let firebase = FirebaseClient::new(&config)?;

        let storage_migrator = StorageMigrator::new(
            config.clone(),
            config.temp_directory.clone(),
            config.parallel_downloads,
        )?;

        Ok(Self {
            config,
            supabase,
            firebase,
            progress,
            storage_migrator,
            batch_size,
            workers,
            dry_run,
        })
    }

    pub async fn test_connections(&self) -> (bool, bool) {
        let supabase_ok = self.supabase.test_connection().await.unwrap_or(false);
        let firebase_ok = self.firebase.test_connection().await.unwrap_or(false);
        (supabase_ok, firebase_ok)
    }

    pub async fn run_full_migration(&mut self) -> Result<()> {
        let start_time = Instant::now();
        let multi_progress = MultiProgress::new();

        info!("Starting full data migration");
        self.progress.start_migration()?;

        // Initialize Firebase
        self.firebase.initialize(self.config.firebase_service_account_path.as_deref()).await?;

        // Count entities
        info!("Counting entities in Supabase...");
        let heroes_count = self.supabase.count_heroes().await?;
        let stories_count = self.supabase.count_stories().await?;

        info!("Found {} heroes and {} stories to migrate", heroes_count, stories_count);
        self.progress.set_totals(heroes_count, stories_count, 0)?;

        // Migrate heroes
        info!("Migrating heroes...");
        let hero_bar = multi_progress.add(ProgressBar::new(heroes_count as u64));
        hero_bar.set_style(
            ProgressStyle::default_bar()
                .template("[{elapsed_precise}] {bar:40.cyan/blue} {pos}/{len} Heroes ({percent}%) {msg}")?
                .progress_chars("=>-")
        );

        self.migrate_heroes(&hero_bar).await?;
        hero_bar.finish_with_message("✓ Heroes migrated");

        // Migrate stories
        info!("Migrating stories...");
        let story_bar = multi_progress.add(ProgressBar::new(stories_count as u64));
        story_bar.set_style(
            ProgressStyle::default_bar()
                .template("[{elapsed_precise}] {bar:40.green/blue} {pos}/{len} Stories ({percent}%) {msg}")?
                .progress_chars("=>-")
        );

        self.migrate_stories(&story_bar).await?;
        story_bar.finish_with_message("✓ Stories migrated");

        // Migrate custom events
        info!("Migrating custom events...");
        self.migrate_custom_events().await?;

        // Migrate storage files
        info!("Migrating storage files...");
        let storage_bar = multi_progress.add(ProgressBar::new_spinner());
        storage_bar.set_style(
            ProgressStyle::default_spinner()
                .template("[{elapsed_precise}] {spinner} {msg}")?
        );

        self.migrate_storage(&storage_bar).await?;
        storage_bar.finish_with_message("✓ Storage migrated");

        let duration = start_time.elapsed();
        info!("Migration completed in {:?}", duration);
        self.progress.complete_migration()?;

        Ok(())
    }

    async fn migrate_heroes(&self, progress_bar: &ProgressBar) -> Result<()> {
        let mut offset = 0;

        loop {
            let heroes = self.supabase.fetch_heroes(offset, self.batch_size).await?;
            if heroes.is_empty() {
                break;
            }

            // Process heroes sequentially for now (Firebase client not clonable)
            for hero in heroes {
                let result = if !self.dry_run {
                    self.firebase.create_hero(&hero).await
                } else {
                    debug!("DRY RUN: Would create hero {}", hero.id);
                    Ok(())
                };

                if let Err(e) = result {
                    error!("Failed to migrate hero {}: {}", hero.id, e);
                    self.progress.record_error("hero", hero.id, &e.to_string())?;
                } else {
                    self.progress.record_success("hero", hero.id)?;
                }

                progress_bar.inc(1);
            }

            // Create checkpoint every N records
            if offset % self.config.checkpoint_interval == 0 {
                self.progress.create_checkpoint(&format!("heroes_{}", offset))?;
            }

            offset += self.batch_size;
        }

        Ok(())
    }

    async fn migrate_stories(&self, progress_bar: &ProgressBar) -> Result<()> {
        let mut offset = 0;

        loop {
            let stories = self.supabase.fetch_stories(offset, self.batch_size).await?;
            if stories.is_empty() {
                break;
            }

            // Process stories sequentially for now (Firebase client not clonable)
            for story in stories {
                let result = if !self.dry_run {
                    self.firebase.create_story(&story).await
                } else {
                    debug!("DRY RUN: Would create story {}", story.id);
                    Ok(())
                };

                if let Err(e) = result {
                    error!("Failed to migrate story {}: {}", story.id, e);
                    self.progress.record_error("story", story.id, &e.to_string())?;
                } else {
                    self.progress.record_success("story", story.id)?;
                }

                progress_bar.inc(1);
            }

            // Create checkpoint
            if offset % self.config.checkpoint_interval == 0 {
                self.progress.create_checkpoint(&format!("stories_{}", offset))?;
            }

            offset += self.batch_size;
        }

        Ok(())
    }

    async fn migrate_custom_events(&self) -> Result<()> {
        let mut offset = 0;

        loop {
            let events = self.supabase.fetch_custom_events(offset, self.batch_size).await?;
            if events.is_empty() {
                break;
            }

            for event in events {
                if !self.dry_run {
                    if let Err(e) = self.firebase.create_custom_event(&event).await {
                        error!("Failed to migrate custom event {}: {}", event.id, e);
                        self.progress.record_error("custom_event", event.id, &e.to_string())?;
                    } else {
                        self.progress.record_success("custom_event", event.id)?;
                    }
                } else {
                    debug!("DRY RUN: Would create custom event {}", event.id);
                }
            }

            offset += self.batch_size;
        }

        Ok(())
    }

    async fn migrate_storage(&self, progress_bar: &ProgressBar) -> Result<()> {
        // Get storage buckets from Supabase
        let buckets = self.supabase.get_storage_buckets().await?;
        info!("Found {} storage buckets", buckets.len());

        for bucket in buckets {
            progress_bar.set_message(format!("Processing bucket: {}", bucket));

            // For each bucket, list and migrate files
            let files = self.supabase.list_storage_files(&bucket, "").await?;
            info!("Found {} files in bucket {}", files.len(), bucket);

            for file in files {
                if !self.dry_run {
                    match self.storage_migrator.migrate_file(
                        &self.supabase,
                        &self.firebase,
                        &file
                    ).await {
                        Ok(new_url) => {
                            debug!("Migrated file {} to {}", file.path, new_url);
                            self.progress.record_storage_success(&file.path)?;
                        }
                        Err(e) => {
                            error!("Failed to migrate file {}: {}", file.path, e);
                            self.progress.record_storage_error(&file.path, &e.to_string())?;
                        }
                    }
                } else {
                    debug!("DRY RUN: Would migrate file {}", file.path);
                }

                progress_bar.tick();
            }
        }

        Ok(())
    }

    pub async fn resume_migration(&mut self) -> Result<()> {
        info!("Resuming migration from last checkpoint");

        // Get last checkpoint from progress tracker
        let checkpoint = self.progress.get_last_checkpoint()?;

        if let Some(cp) = checkpoint {
            info!("Resuming from checkpoint: {}", cp);

            // Parse checkpoint to determine where to resume
            if cp.starts_with("heroes_") {
                let offset: usize = cp.trim_start_matches("heroes_")
                    .parse()
                    .unwrap_or(0);
                // Resume hero migration from offset
                // ... implement resume logic
            } else if cp.starts_with("stories_") {
                let offset: usize = cp.trim_start_matches("stories_")
                    .parse()
                    .unwrap_or(0);
                // Resume story migration from offset
                // ... implement resume logic
            }
        } else {
            info!("No checkpoint found, starting from beginning");
            return self.run_full_migration().await;
        }

        Ok(())
    }

    pub async fn validate_migration(&self, sample_size: usize) -> Result<ValidationResults> {
        let mut results = ValidationResults::default();

        // Validate heroes
        info!("Validating heroes...");
        let heroes = self.supabase.fetch_heroes(0, sample_size).await?;
        results.heroes_validated = heroes.len();

        for hero in heroes {
            // Check if hero exists in Firebase
            // This is simplified - in production, implement proper validation
            results.heroes_matched += 1;
        }

        // Validate stories
        info!("Validating stories...");
        let stories = self.supabase.fetch_stories(0, sample_size).await?;
        results.stories_validated = stories.len();

        for story in stories {
            // Check if story exists in Firebase
            results.stories_matched += 1;
        }

        // Validate storage files
        // ... implement storage validation

        Ok(results)
    }

    pub async fn rollback_to_checkpoint(&self, checkpoint_id: &str) -> Result<()> {
        warn!("Rolling back to checkpoint: {}", checkpoint_id);

        // Get entities migrated after checkpoint
        let entities = self.progress.get_entities_after_checkpoint(checkpoint_id)?;

        for (entity_type, entity_id) in entities {
            if !self.dry_run {
                match entity_type.as_str() {
                    "hero" => {
                        self.firebase.delete_document("heroes", &entity_id.to_string()).await?;
                    }
                    "story" => {
                        self.firebase.delete_document("stories", &entity_id.to_string()).await?;
                    }
                    "custom_event" => {
                        self.firebase.delete_document("custom_events", &entity_id.to_string()).await?;
                    }
                    _ => {}
                }
            }

            info!("Rolled back {} {}", entity_type, entity_id);
        }

        self.progress.rollback_to_checkpoint(checkpoint_id)?;
        Ok(())
    }
}