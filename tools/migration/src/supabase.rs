use anyhow::{Context, Result};
use reqwest::{Client, header};
use serde_json::json;
use tracing::{debug, info, warn};

use crate::models::{Hero, Story, CustomEvent, StorageFile};
use crate::config::MigrationConfig;

pub struct SupabaseClient {
    client: Client,
    base_url: String,
    anon_key: String,
    service_key: String,
}

impl SupabaseClient {
    pub fn new(config: &MigrationConfig) -> Result<Self> {
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()?;

        Ok(Self {
            client,
            base_url: config.supabase_url.clone(),
            anon_key: config.supabase_anon_key.clone(),
            service_key: config.supabase_service_key.clone(),
        })
    }

    pub async fn test_connection(&self) -> Result<bool> {
        let url = format!("{}/rest/v1/", self.base_url);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await
            .context("Failed to connect to Supabase")?;

        Ok(response.status().is_success())
    }

    pub async fn count_heroes(&self) -> Result<usize> {
        let url = format!("{}/rest/v1/heroes?select=count", self.base_url);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .header("Prefer", "count=exact")
            .send()
            .await?;

        let count_header = response.headers()
            .get("content-range")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.split('/').last())
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(0);

        Ok(count_header)
    }

    pub async fn fetch_heroes(&self, offset: usize, limit: usize) -> Result<Vec<Hero>> {
        let url = format!(
            "{}/rest/v1/heroes?select=*&order=created_at.asc&offset={}&limit={}",
            self.base_url, offset, limit
        );

        debug!("Fetching heroes: offset={}, limit={}", offset, limit);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to fetch heroes: {}", error_text);
        }

        let heroes: Vec<Hero> = response.json().await
            .context("Failed to parse heroes response")?;

        info!("Fetched {} heroes", heroes.len());
        Ok(heroes)
    }

    pub async fn count_stories(&self) -> Result<usize> {
        let url = format!("{}/rest/v1/stories?select=count", self.base_url);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .header("Prefer", "count=exact")
            .send()
            .await?;

        let count_header = response.headers()
            .get("content-range")
            .and_then(|v| v.to_str().ok())
            .and_then(|s| s.split('/').last())
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(0);

        Ok(count_header)
    }

    pub async fn fetch_stories(&self, offset: usize, limit: usize) -> Result<Vec<Story>> {
        let url = format!(
            "{}/rest/v1/stories?select=*&order=created_at.asc&offset={}&limit={}",
            self.base_url, offset, limit
        );

        debug!("Fetching stories: offset={}, limit={}", offset, limit);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to fetch stories: {}", error_text);
        }

        let stories: Vec<Story> = response.json().await
            .context("Failed to parse stories response")?;

        info!("Fetched {} stories", stories.len());
        Ok(stories)
    }

    pub async fn fetch_custom_events(&self, offset: usize, limit: usize) -> Result<Vec<CustomEvent>> {
        let url = format!(
            "{}/rest/v1/custom_story_events?select=*&order=created_at.asc&offset={}&limit={}",
            self.base_url, offset, limit
        );

        debug!("Fetching custom events: offset={}, limit={}", offset, limit);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to fetch custom events: {}", error_text);
        }

        let events: Vec<CustomEvent> = response.json().await
            .context("Failed to parse custom events response")?;

        info!("Fetched {} custom events", events.len());
        Ok(events)
    }

    pub async fn download_storage_file(&self, bucket: &str, path: &str) -> Result<Vec<u8>> {
        let url = format!("{}/storage/v1/object/{}/{}", self.base_url, bucket, path);

        debug!("Downloading file: {}/{}", bucket, path);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await?;

        if !response.status().is_success() {
            if response.status() == reqwest::StatusCode::NOT_FOUND {
                anyhow::bail!("File not found: {}/{}", bucket, path);
            }
            let error_text = response.text().await?;
            anyhow::bail!("Failed to download file: {}", error_text);
        }

        let bytes = response.bytes().await?.to_vec();
        info!("Downloaded file: {}/{} ({} bytes)", bucket, path, bytes.len());
        Ok(bytes)
    }

    pub async fn list_storage_files(&self, bucket: &str, prefix: &str) -> Result<Vec<StorageFile>> {
        let url = format!("{}/storage/v1/object/list/{}", self.base_url, bucket);

        let body = json!({
            "prefix": prefix,
            "limit": 1000
        });

        debug!("Listing files in bucket: {} with prefix: {}", bucket, prefix);

        let response = self.client
            .post(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .json(&body)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to list storage files: {}", error_text);
        }

        let files: Vec<serde_json::Value> = response.json().await?;

        let storage_files: Vec<StorageFile> = files.iter()
            .filter_map(|f| {
                let name = f.get("name")?.as_str()?;
                let size = f.get("metadata")?.get("size")?.as_i64();
                let content_type = f.get("metadata")?.get("mimetype")?.as_str().map(String::from);

                Some(StorageFile {
                    bucket: bucket.to_string(),
                    path: format!("{}/{}", prefix, name),
                    url: format!("{}/storage/v1/object/{}/{}/{}", self.base_url, bucket, prefix, name),
                    size,
                    content_type,
                    checksum: None,
                })
            })
            .collect();

        info!("Found {} files in {}/{}", storage_files.len(), bucket, prefix);
        Ok(storage_files)
    }

    pub async fn get_storage_buckets(&self) -> Result<Vec<String>> {
        let url = format!("{}/storage/v1/bucket", self.base_url);

        let response = self.client
            .get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", &self.service_key))
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to get storage buckets: {}", error_text);
        }

        let buckets: Vec<serde_json::Value> = response.json().await?;
        let bucket_names: Vec<String> = buckets.iter()
            .filter_map(|b| b.get("name")?.as_str().map(String::from))
            .collect();

        Ok(bucket_names)
    }
}