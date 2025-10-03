use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct MigrationConfig {
    // Supabase configuration
    pub supabase_url: String,
    pub supabase_anon_key: String,
    pub supabase_service_key: String,

    // Firebase configuration
    pub firebase_project_id: String,
    pub firebase_api_key: String,
    pub firebase_auth_domain: String,
    pub firebase_storage_bucket: String,
    pub firebase_service_account_path: Option<String>,

    // Migration settings
    pub checkpoint_interval: usize,
    pub retry_max_attempts: u32,
    pub retry_delay_ms: u64,
    pub rate_limit_requests_per_second: u32,

    // Storage settings
    pub temp_directory: String,
    pub verify_checksums: bool,
    pub parallel_downloads: usize,
}

impl MigrationConfig {
    pub fn from_env() -> Result<Self> {
        Ok(Self {
            supabase_url: std::env::var("SUPABASE_URL")
                .context("SUPABASE_URL not set")?,
            supabase_anon_key: std::env::var("SUPABASE_ANON_KEY")
                .context("SUPABASE_ANON_KEY not set")?,
            supabase_service_key: std::env::var("SUPABASE_SERVICE_KEY")
                .context("SUPABASE_SERVICE_KEY not set")?,

            firebase_project_id: std::env::var("FIREBASE_PROJECT_ID")
                .context("FIREBASE_PROJECT_ID not set")?,
            firebase_api_key: std::env::var("FIREBASE_API_KEY")
                .context("FIREBASE_API_KEY not set")?,
            firebase_auth_domain: std::env::var("FIREBASE_AUTH_DOMAIN")
                .context("FIREBASE_AUTH_DOMAIN not set")?,
            firebase_storage_bucket: std::env::var("FIREBASE_STORAGE_BUCKET")
                .context("FIREBASE_STORAGE_BUCKET not set")?,
            firebase_service_account_path: std::env::var("FIREBASE_SERVICE_ACCOUNT_PATH").ok(),

            checkpoint_interval: std::env::var("CHECKPOINT_INTERVAL")
                .unwrap_or_else(|_| "100".to_string())
                .parse()
                .unwrap_or(100),
            retry_max_attempts: std::env::var("RETRY_MAX_ATTEMPTS")
                .unwrap_or_else(|_| "3".to_string())
                .parse()
                .unwrap_or(3),
            retry_delay_ms: std::env::var("RETRY_DELAY_MS")
                .unwrap_or_else(|_| "1000".to_string())
                .parse()
                .unwrap_or(1000),
            rate_limit_requests_per_second: std::env::var("RATE_LIMIT_RPS")
                .unwrap_or_else(|_| "10".to_string())
                .parse()
                .unwrap_or(10),

            temp_directory: std::env::var("TEMP_DIRECTORY")
                .unwrap_or_else(|_| "/tmp/migration".to_string()),
            verify_checksums: std::env::var("VERIFY_CHECKSUMS")
                .unwrap_or_else(|_| "true".to_string())
                .parse()
                .unwrap_or(true),
            parallel_downloads: std::env::var("PARALLEL_DOWNLOADS")
                .unwrap_or_else(|_| "4".to_string())
                .parse()
                .unwrap_or(4),
        })
    }

    pub fn validate(&self) -> Result<()> {
        if self.supabase_url.is_empty() {
            anyhow::bail!("Supabase URL cannot be empty");
        }
        if self.firebase_project_id.is_empty() {
            anyhow::bail!("Firebase project ID cannot be empty");
        }
        if self.checkpoint_interval == 0 {
            anyhow::bail!("Checkpoint interval must be greater than 0");
        }
        Ok(())
    }
}