use anyhow::{Context, Result};
use reqwest::{Client, header};
use serde_json::json;
use tracing::{debug, info, warn};
use uuid::Uuid;
use base64::{Engine as _, engine::general_purpose};

use crate::models::{Hero, Story, CustomEvent, StorageFile};
use crate::config::MigrationConfig;

pub struct FirebaseClient {
    client: Client,
    project_id: String,
    api_key: String,
    auth_token: Option<String>,
    storage_bucket: String,
}

impl FirebaseClient {
    pub fn new(config: &MigrationConfig) -> Result<Self> {
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()?;

        Ok(Self {
            client,
            project_id: config.firebase_project_id.clone(),
            api_key: config.firebase_api_key.clone(),
            auth_token: None,
            storage_bucket: config.firebase_storage_bucket.clone(),
        })
    }

    pub async fn initialize(&mut self, service_account_path: Option<&str>) -> Result<()> {
        if let Some(path) = service_account_path {
            // Load service account and get auth token
            let service_account = std::fs::read_to_string(path)
                .context("Failed to read service account file")?;

            // For production, implement proper OAuth2 flow with service account
            // This is a simplified placeholder
            self.auth_token = Some(self.get_service_account_token(&service_account).await?);
        } else {
            // Use API key authentication
            info!("Using API key authentication for Firebase");
        }
        Ok(())
    }

    async fn get_service_account_token(&self, _service_account: &str) -> Result<String> {
        // TODO: Implement proper OAuth2 flow for service account
        // This would involve:
        // 1. Parse service account JSON
        // 2. Create JWT
        // 3. Exchange JWT for access token
        // For now, return a placeholder
        warn!("Service account authentication not fully implemented");
        Ok("placeholder_token".to_string())
    }

    pub async fn test_connection(&self) -> Result<bool> {
        // Test Firestore connection
        let url = format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/test",
            self.project_id
        );

        let response = self.client
            .get(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .send()
            .await;

        match response {
            Ok(resp) => {
                // 404 is ok (document doesn't exist), we just want to test auth
                Ok(resp.status().is_success() || resp.status() == reqwest::StatusCode::NOT_FOUND)
            }
            Err(_) => Ok(false)
        }
    }

    pub async fn create_hero(&self, hero: &Hero) -> Result<()> {
        let url = format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/heroes?documentId={}",
            self.project_id,
            hero.id
        );

        let doc = json!({
            "fields": {
                "id": { "stringValue": hero.id.to_string() },
                "user_id": { "stringValue": hero.user_id.to_string() },
                "name": { "stringValue": &hero.name },
                "primary_trait": { "stringValue": &hero.primary_trait },
                "secondary_trait": { "stringValue": &hero.secondary_trait },
                "appearance": { "stringValue": &hero.appearance },
                "special_ability": { "stringValue": &hero.special_ability },
                "avatar_prompt": if hero.avatar_prompt.is_some() {
                    json!({ "stringValue": hero.avatar_prompt.as_ref().unwrap() })
                } else {
                    json!({ "nullValue": null })
                },
                "avatar_url": if hero.avatar_url.is_some() {
                    json!({ "stringValue": hero.avatar_url.as_ref().unwrap() })
                } else {
                    json!({ "nullValue": null })
                },
                "generation_id": if hero.generation_id.is_some() {
                    json!({ "stringValue": hero.generation_id.as_ref().unwrap() })
                } else {
                    json!({ "nullValue": null })
                },
                "created_at": { "timestampValue": hero.created_at.to_rfc3339() },
                "updated_at": { "timestampValue": hero.updated_at.to_rfc3339() }
            }
        });

        debug!("Creating hero in Firebase: {}", hero.id);

        let response = self.client
            .patch(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .json(&doc)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to create hero in Firebase: {}", error_text);
        }

        info!("Created hero in Firebase: {}", hero.name);
        Ok(())
    }

    pub async fn create_story(&self, story: &Story) -> Result<()> {
        let url = format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/stories?documentId={}",
            self.project_id,
            story.id
        );

        // Convert illustrations to Firestore format
        let illustrations: Vec<serde_json::Value> = story.illustrations.iter().map(|ill| {
            json!({
                "mapValue": {
                    "fields": {
                        "scene_number": { "integerValue": ill.scene_number.to_string() },
                        "prompt": { "stringValue": &ill.prompt },
                        "image_url": if ill.image_url.is_some() {
                            json!({ "stringValue": ill.image_url.as_ref().unwrap() })
                        } else {
                            json!({ "nullValue": null })
                        },
                        "generation_id": if ill.generation_id.is_some() {
                            json!({ "stringValue": ill.generation_id.as_ref().unwrap() })
                        } else {
                            json!({ "nullValue": null })
                        },
                        "timestamp": { "doubleValue": ill.timestamp },
                        "error": if ill.error.is_some() {
                            json!({ "stringValue": ill.error.as_ref().unwrap() })
                        } else {
                            json!({ "nullValue": null })
                        }
                    }
                }
            })
        }).collect();

        let doc = json!({
            "fields": {
                "id": { "stringValue": story.id.to_string() },
                "user_id": { "stringValue": story.user_id.to_string() },
                "hero_id": { "stringValue": story.hero_id.to_string() },
                "title": { "stringValue": &story.title },
                "content": { "stringValue": &story.content },
                "event_type": { "stringValue": &story.event_type },
                "event_data": { "stringValue": story.event_data.to_string() },
                "language": { "stringValue": &story.language },
                "duration": { "doubleValue": story.duration },
                "audio_url": if story.audio_url.is_some() {
                    json!({ "stringValue": story.audio_url.as_ref().unwrap() })
                } else {
                    json!({ "nullValue": null })
                },
                "illustrations": {
                    "arrayValue": {
                        "values": illustrations
                    }
                },
                "created_at": { "timestampValue": story.created_at.to_rfc3339() },
                "updated_at": { "timestampValue": story.updated_at.to_rfc3339() }
            }
        });

        debug!("Creating story in Firebase: {}", story.id);

        let response = self.client
            .patch(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .json(&doc)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to create story in Firebase: {}", error_text);
        }

        info!("Created story in Firebase: {}", story.title);
        Ok(())
    }

    pub async fn create_custom_event(&self, event: &CustomEvent) -> Result<()> {
        let url = format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/custom_events?documentId={}",
            self.project_id,
            event.id
        );

        let keywords: Vec<serde_json::Value> = event.keywords.iter()
            .map(|k| json!({ "stringValue": k }))
            .collect();

        let doc = json!({
            "fields": {
                "id": { "stringValue": event.id.to_string() },
                "user_id": { "stringValue": event.user_id.to_string() },
                "title": { "stringValue": &event.title },
                "description": { "stringValue": &event.description },
                "prompt_seed": { "stringValue": &event.prompt_seed },
                "category": { "stringValue": &event.category },
                "tone": { "stringValue": &event.tone },
                "age_range": { "stringValue": &event.age_range },
                "keywords": {
                    "arrayValue": {
                        "values": keywords
                    }
                },
                "pictogram": if event.pictogram.is_some() {
                    json!({ "stringValue": event.pictogram.as_ref().unwrap() })
                } else {
                    json!({ "nullValue": null })
                },
                "usage_count": { "integerValue": event.usage_count.to_string() },
                "is_favorite": { "booleanValue": event.is_favorite },
                "created_at": { "timestampValue": event.created_at.to_rfc3339() },
                "updated_at": { "timestampValue": event.updated_at.to_rfc3339() }
            }
        });

        debug!("Creating custom event in Firebase: {}", event.id);

        let response = self.client
            .patch(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .json(&doc)
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to create custom event in Firebase: {}", error_text);
        }

        info!("Created custom event in Firebase: {}", event.title);
        Ok(())
    }

    pub async fn upload_storage_file(&self, path: &str, data: &[u8], content_type: Option<&str>) -> Result<String> {
        // Firebase Storage upload URL
        let url = format!(
            "https://firebasestorage.googleapis.com/v0/b/{}/o?name={}",
            self.storage_bucket,
            urlencoding::encode(path)
        );

        let content_type = content_type.unwrap_or("application/octet-stream");

        debug!("Uploading file to Firebase Storage: {}", path);

        let response = self.client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .header("Content-Type", content_type)
            .body(data.to_vec())
            .send()
            .await?;

        if !response.status().is_success() {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to upload file to Firebase Storage: {}", error_text);
        }

        let response_json: serde_json::Value = response.json().await?;
        let download_token = response_json.get("downloadTokens")
            .and_then(|t| t.as_str())
            .unwrap_or("");

        let public_url = format!(
            "https://firebasestorage.googleapis.com/v0/b/{}/o/{}?alt=media&token={}",
            self.storage_bucket,
            urlencoding::encode(path),
            download_token
        );

        info!("Uploaded file to Firebase Storage: {} ({} bytes)", path, data.len());
        Ok(public_url)
    }

    pub async fn delete_document(&self, collection: &str, doc_id: &str) -> Result<()> {
        let url = format!(
            "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/{}/{}",
            self.project_id,
            collection,
            doc_id
        );

        let response = self.client
            .delete(&url)
            .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
            .send()
            .await?;

        if !response.status().is_success() && response.status() != reqwest::StatusCode::NOT_FOUND {
            let error_text = response.text().await?;
            anyhow::bail!("Failed to delete document: {}", error_text);
        }

        Ok(())
    }

    pub async fn batch_create_heroes(&self, heroes: &[Hero]) -> Result<()> {
        // Firebase doesn't have a direct batch API like Supabase,
        // but we can use the batch write endpoint

        for batch in heroes.chunks(500) { // Firebase limit is 500 per batch
            let writes: Vec<serde_json::Value> = batch.iter().map(|hero| {
                let doc_name = format!("projects/{}/databases/(default)/documents/heroes/{}",
                    self.project_id, hero.id);

                json!({
                    "update": {
                        "name": doc_name,
                        "fields": {
                            "id": { "stringValue": hero.id.to_string() },
                            "user_id": { "stringValue": hero.user_id.to_string() },
                            "name": { "stringValue": &hero.name },
                            "primary_trait": { "stringValue": &hero.primary_trait },
                            "secondary_trait": { "stringValue": &hero.secondary_trait },
                            "appearance": { "stringValue": &hero.appearance },
                            "special_ability": { "stringValue": &hero.special_ability },
                            "created_at": { "timestampValue": hero.created_at.to_rfc3339() },
                            "updated_at": { "timestampValue": hero.updated_at.to_rfc3339() }
                        }
                    }
                })
            }).collect();

            let body = json!({
                "writes": writes
            });

            let url = format!(
                "https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents:batchWrite",
                self.project_id
            );

            let response = self.client
                .post(&url)
                .header("Authorization", format!("Bearer {}", self.auth_token.as_ref().unwrap_or(&self.api_key)))
                .json(&body)
                .send()
                .await?;

            if !response.status().is_success() {
                let error_text = response.text().await?;
                anyhow::bail!("Failed to batch create heroes: {}", error_text);
            }
        }

        info!("Batch created {} heroes", heroes.len());
        Ok(())
    }
}