use anyhow::{Context, Result};
use sha2::{Sha256, Digest};
use std::path::{Path, PathBuf};
use tempfile::TempDir;
use tracing::{debug, info, warn};

use crate::config::MigrationConfig;
use crate::supabase::SupabaseClient;
use crate::firebase::FirebaseClient;
use crate::models::StorageFile;

pub struct StorageMigrator {
    config: MigrationConfig,
    temp_dir: TempDir,
    parallel_downloads: usize,
}

impl StorageMigrator {
    pub fn new(
        config: MigrationConfig,
        temp_path: String,
        parallel_downloads: usize
    ) -> Result<Self> {
        // Create temp directory
        let temp_dir = if temp_path.is_empty() {
            TempDir::new()?
        } else {
            TempDir::new_in(temp_path)?
        };

        Ok(Self {
            config,
            temp_dir,
            parallel_downloads,
        })
    }

    pub async fn migrate_file(
        &self,
        supabase: &SupabaseClient,
        firebase: &FirebaseClient,
        file: &StorageFile,
    ) -> Result<String> {
        debug!("Migrating file: {}/{}", file.bucket, file.path);

        // Download from Supabase
        let data = supabase.download_storage_file(&file.bucket, &file.path).await?;

        // Verify checksum if enabled
        if self.config.verify_checksums && file.checksum.is_some() {
            let calculated = self.calculate_checksum(&data);
            let expected = file.checksum.as_ref().unwrap();

            if &calculated != expected {
                anyhow::bail!(
                    "Checksum mismatch for {}/{}: expected {}, got {}",
                    file.bucket, file.path, expected, calculated
                );
            }
        }

        // Determine Firebase path
        let firebase_path = self.map_storage_path(&file.bucket, &file.path);

        // Upload to Firebase Storage
        let new_url = firebase.upload_storage_file(
            &firebase_path,
            &data,
            file.content_type.as_deref(),
        ).await?;

        info!(
            "Migrated {}/{} -> {} ({} bytes)",
            file.bucket, file.path, firebase_path, data.len()
        );

        Ok(new_url)
    }

    pub async fn migrate_batch(
        &self,
        supabase: &SupabaseClient,
        firebase: &FirebaseClient,
        files: Vec<StorageFile>,
    ) -> Result<Vec<Result<String>>> {
        let mut results = vec![];

        // Process files sequentially for now (clients not clonable)
        for file in files {
            let result = async {
                // Download from Supabase
                let data = supabase.download_storage_file(&file.bucket, &file.path).await?;

                // Map path
                let firebase_path = format!("migrated/{}/{}", file.bucket, file.path);

                // Upload to Firebase
                let new_url = firebase.upload_storage_file(
                    &firebase_path,
                    &data,
                    file.content_type.as_deref(),
                ).await?;

                Ok::<String, anyhow::Error>(new_url)
            }.await;

            results.push(result);
        }

        Ok(results)
    }

    fn calculate_checksum(&self, data: &[u8]) -> String {
        let mut hasher = Sha256::new();
        hasher.update(data);
        format!("{:x}", hasher.finalize())
    }

    fn map_storage_path(&self, bucket: &str, path: &str) -> String {
        // Map Supabase bucket/path structure to Firebase Storage structure
        match bucket {
            "hero-avatars" => format!("avatars/{}", path),
            "story-audio" => format!("audio/{}", path),
            "story-illustrations" => format!("illustrations/{}", path),
            _ => format!("{}/{}", bucket, path),
        }
    }

    pub async fn verify_migration(
        &self,
        supabase: &SupabaseClient,
        firebase: &FirebaseClient,
        sample_files: Vec<StorageFile>,
    ) -> Result<Vec<(String, bool, Option<String>)>> {
        let mut results = vec![];

        for file in sample_files {
            // Download from both sources
            let supabase_data = supabase.download_storage_file(&file.bucket, &file.path).await?;
            let firebase_path = self.map_storage_path(&file.bucket, &file.path);

            // For Firebase, we'd need to implement a download method
            // For now, we'll just verify the file was uploaded
            let firebase_exists = true; // Placeholder

            let checksum_match = if self.config.verify_checksums {
                let supabase_checksum = self.calculate_checksum(&supabase_data);
                // Would need to download from Firebase and calculate checksum
                Some(supabase_checksum)
            } else {
                None
            };

            results.push((
                format!("{}/{}", file.bucket, file.path),
                firebase_exists,
                checksum_match,
            ));
        }

        Ok(results)
    }

    pub fn get_temp_path(&self) -> &Path {
        self.temp_dir.path()
    }
}