use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Hero models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Hero {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub primary_trait: String,
    pub secondary_trait: String,
    pub appearance: String,
    pub special_ability: String,
    pub avatar_prompt: Option<String>,
    pub avatar_url: Option<String>,
    pub generation_id: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Story models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Story {
    pub id: Uuid,
    pub user_id: Uuid,
    pub hero_id: Uuid,
    pub title: String,
    pub content: String,
    pub event_type: String,
    pub event_data: serde_json::Value,
    pub language: String,
    pub duration: f64,
    pub audio_url: Option<String>,
    pub illustrations: Vec<StoryIllustration>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoryIllustration {
    pub scene_number: i32,
    pub prompt: String,
    pub image_url: Option<String>,
    pub generation_id: Option<String>,
    pub timestamp: f64,
    pub error: Option<String>,
}

// Custom event models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomEvent {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: String,
    pub description: String,
    pub prompt_seed: String,
    pub category: String,
    pub tone: String,
    pub age_range: String,
    pub keywords: Vec<String>,
    pub pictogram: Option<String>,
    pub usage_count: i32,
    pub is_favorite: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Storage file reference
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageFile {
    pub bucket: String,
    pub path: String,
    pub url: String,
    pub size: Option<i64>,
    pub content_type: Option<String>,
    pub checksum: Option<String>,
}

// Migration metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MigrationRecord {
    pub entity_type: String,
    pub entity_id: Uuid,
    pub source_system: String,
    pub target_system: String,
    pub status: MigrationStatus,
    pub started_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub error: Option<String>,
    pub retry_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MigrationStatus {
    Pending,
    InProgress,
    Completed,
    Failed,
    Skipped,
}

// Validation results
#[derive(Debug, Default, Serialize)]
pub struct ValidationResults {
    pub heroes_validated: usize,
    pub heroes_matched: usize,
    pub heroes_mismatched: usize,
    pub stories_validated: usize,
    pub stories_matched: usize,
    pub stories_mismatched: usize,
    pub storage_validated: usize,
    pub storage_matched: usize,
    pub storage_missing: usize,
    pub errors: Vec<String>,
}

impl ValidationResults {
    pub fn is_valid(&self) -> bool {
        self.heroes_mismatched == 0 &&
            self.stories_mismatched == 0 &&
            self.storage_missing == 0 &&
            self.errors.is_empty()
    }
}

// Migration status report
#[derive(Debug, Serialize)]
pub struct MigrationStatusReport {
    pub state: String,
    pub started_at: Option<DateTime<Utc>>,
    pub last_activity: Option<DateTime<Utc>>,
    pub heroes_total: usize,
    pub heroes_migrated: usize,
    pub stories_total: usize,
    pub stories_migrated: usize,
    pub storage_total: usize,
    pub storage_migrated: usize,
    pub errors: Vec<String>,
}

// Migration report
#[derive(Debug, Serialize)]
pub struct MigrationReport {
    pub generated_at: DateTime<Utc>,
    pub summary: MigrationSummary,
    pub details: Vec<MigrationDetail>,
    pub errors: Vec<MigrationError>,
}

#[derive(Debug, Serialize)]
pub struct MigrationSummary {
    pub total_entities: usize,
    pub successful: usize,
    pub failed: usize,
    pub skipped: usize,
    pub duration_seconds: f64,
    pub average_rate_per_second: f64,
}

#[derive(Debug, Serialize)]
pub struct MigrationDetail {
    pub entity_type: String,
    pub entity_id: String,
    pub status: String,
    pub duration_ms: u64,
    pub retries: u32,
}

#[derive(Debug, Serialize)]
pub struct MigrationError {
    pub entity_type: String,
    pub entity_id: String,
    pub error_message: String,
    pub timestamp: DateTime<Utc>,
}

impl MigrationReport {
    pub fn to_csv(&self) -> anyhow::Result<String> {
        let mut csv = String::new();
        csv.push_str("Entity Type,Entity ID,Status,Duration (ms),Retries\n");
        for detail in &self.details {
            csv.push_str(&format!(
                "{},{},{},{},{}\n",
                detail.entity_type,
                detail.entity_id,
                detail.status,
                detail.duration_ms,
                detail.retries
            ));
        }
        Ok(csv)
    }

    pub fn to_html(&self) -> anyhow::Result<String> {
        let html = format!(r#"
<!DOCTYPE html>
<html>
<head>
    <title>Migration Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        h1 {{ color: #333; }}
        .summary {{ background: #f0f0f0; padding: 15px; margin: 20px 0; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #4CAF50; color: white; }}
        .success {{ color: green; }}
        .failed {{ color: red; }}
        .skipped {{ color: orange; }}
    </style>
</head>
<body>
    <h1>Migration Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Generated: {}</p>
        <p>Total Entities: {}</p>
        <p class="success">Successful: {}</p>
        <p class="failed">Failed: {}</p>
        <p class="skipped">Skipped: {}</p>
        <p>Duration: {:.2} seconds</p>
        <p>Average Rate: {:.2} entities/second</p>
    </div>
    <h2>Details</h2>
    <table>
        <tr>
            <th>Entity Type</th>
            <th>Entity ID</th>
            <th>Status</th>
            <th>Duration (ms)</th>
            <th>Retries</th>
        </tr>
        {}
    </table>
    {}
</body>
</html>"#,
            self.generated_at,
            self.summary.total_entities,
            self.summary.successful,
            self.summary.failed,
            self.summary.skipped,
            self.summary.duration_seconds,
            self.summary.average_rate_per_second,
            self.details.iter().map(|d| format!(
                "<tr><td>{}</td><td>{}</td><td class='{}'>{}</td><td>{}</td><td>{}</td></tr>",
                d.entity_type,
                d.entity_id,
                d.status.to_lowercase(),
                d.status,
                d.duration_ms,
                d.retries
            )).collect::<Vec<_>>().join("\n"),
            if !self.errors.is_empty() {
                format!(
                    "<h2>Errors</h2><ul>{}</ul>",
                    self.errors.iter().map(|e| format!(
                        "<li><strong>{} {}</strong>: {} ({})</li>",
                        e.entity_type, e.entity_id, e.error_message, e.timestamp
                    )).collect::<Vec<_>>().join("\n")
                )
            } else {
                String::new()
            }
        );
        Ok(html)
    }
}