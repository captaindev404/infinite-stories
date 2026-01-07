//! Content indexer module - indexes tasks, code, and documentation

use anyhow::{Context, Result};
use ignore::WalkBuilder;
use rusqlite::Connection;
use sha2::{Digest, Sha256};
use std::path::Path;
use std::time::Instant;

use super::chunker::TextChunker;
use super::embedder::Embedder;
use super::store::{ContentType, VectorStore};

/// Statistics from an indexing operation
#[derive(Debug, Clone, Default)]
pub struct IndexStats {
    pub items_indexed: usize,
    pub items_skipped: usize,
    pub chunks_created: usize,
    pub errors: usize,
    pub duration_ms: u64,
}

impl IndexStats {
    pub fn merge(&mut self, other: &IndexStats) {
        self.items_indexed += other.items_indexed;
        self.items_skipped += other.items_skipped;
        self.chunks_created += other.chunks_created;
        self.errors += other.errors;
        self.duration_ms += other.duration_ms;
    }
}

/// Content indexer for creating embeddings
pub struct ContentIndexer<'a> {
    embedder: &'a mut Embedder,
    conn: &'a Connection,
    chunker: TextChunker,
}

impl<'a> ContentIndexer<'a> {
    /// Create a new content indexer
    pub fn new(embedder: &'a mut Embedder, conn: &'a Connection) -> Self {
        Self {
            embedder,
            conn,
            chunker: TextChunker::new(),
        }
    }

    /// Index all tasks from the database
    pub fn index_tasks(&mut self, force: bool) -> Result<IndexStats> {
        let start = Instant::now();
        let mut stats = IndexStats::default();

        // Get all tasks
        let mut stmt = self.conn.prepare(
            "SELECT id, display_id, title, description FROM tasks WHERE status != 'cancelled'",
        )?;

        let tasks: Vec<(String, Option<i32>, String, Option<String>)> = stmt
            .query_map([], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?))
            })?
            .collect::<Result<Vec<_>, _>>()?;

        // Get acceptance criteria for each task
        for (task_id, display_id, title, description) in tasks {
            let content_id = match display_id {
                Some(id) => format!("#{}", id),
                None => task_id.clone(),
            };

            // Build full task text
            let mut text = format!("Task: {}\n\n", title);
            if let Some(desc) = &description {
                text.push_str(&format!("Description:\n{}\n\n", desc));
            }

            // Add acceptance criteria
            let criteria: Vec<String> = self
                .conn
                .prepare(
                    "SELECT criterion FROM acceptance_criteria WHERE task_display_id = ?1 ORDER BY id",
                )?
                .query_map([display_id.unwrap_or(0)], |row| row.get(0))?
                .collect::<Result<Vec<_>, _>>()
                .unwrap_or_default();

            if !criteria.is_empty() {
                text.push_str("Acceptance Criteria:\n");
                for (i, criterion) in criteria.iter().enumerate() {
                    text.push_str(&format!("{}. {}\n", i + 1, criterion));
                }
            }

            // Check if content changed
            let hash = Self::hash_content(&text);
            if !force {
                if let Some(existing_hash) =
                    VectorStore::get_content_hash(self.conn, ContentType::Task, &content_id)?
                {
                    if existing_hash == hash {
                        stats.items_skipped += 1;
                        continue;
                    }
                }
            }

            // Generate embedding
            match self.embedder.embed_one(&text) {
                Ok(embedding) => {
                    let preview = Self::create_preview(&text, 200);
                    VectorStore::store_embedding(
                        self.conn,
                        ContentType::Task,
                        &content_id,
                        0,
                        Some(&preview),
                        &hash,
                        &embedding,
                        Some(&format!(
                            r#"{{"task_id":"{}","display_id":{}}}"#,
                            task_id,
                            display_id.unwrap_or(0)
                        )),
                    )?;
                    stats.items_indexed += 1;
                    stats.chunks_created += 1;
                }
                Err(e) => {
                    eprintln!("Error indexing task {}: {}", content_id, e);
                    stats.errors += 1;
                }
            }
        }

        stats.duration_ms = start.elapsed().as_millis() as u64;

        // Update stats
        VectorStore::update_stats(
            self.conn,
            ContentType::Task,
            stats.items_indexed as i64,
            stats.chunks_created as i64,
            stats.duration_ms as i64,
        )?;

        Ok(stats)
    }

    /// Index files in a directory
    pub fn index_directory(
        &mut self,
        path: &Path,
        content_type: ContentType,
        patterns: &[String],
        force: bool,
    ) -> Result<IndexStats> {
        let start = Instant::now();
        let mut stats = IndexStats::default();

        if !path.exists() {
            anyhow::bail!("Path does not exist: {}", path.display());
        }

        // Build walker with gitignore support
        let mut walker = WalkBuilder::new(path);
        walker
            .hidden(false)
            .git_ignore(true)
            .git_global(true)
            .git_exclude(true);

        for entry in walker.build() {
            let entry = match entry {
                Ok(e) => e,
                Err(e) => {
                    eprintln!("Error walking directory: {}", e);
                    stats.errors += 1;
                    continue;
                }
            };

            let file_path = entry.path();

            // Skip directories
            if file_path.is_dir() {
                continue;
            }

            // Check if file matches patterns (if specified)
            if !patterns.is_empty() {
                let file_name = file_path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("");
                let matches = patterns.iter().any(|p| {
                    let pattern = p.trim_start_matches("*.");
                    file_name.ends_with(pattern) || glob::Pattern::new(p).map(|g| g.matches(file_name)).unwrap_or(false)
                });
                if !matches {
                    continue;
                }
            }

            // Filter by content type
            if !Self::is_indexable_file(file_path, content_type) {
                continue;
            }

            match self.index_file(file_path, content_type, force) {
                Ok(file_stats) => stats.merge(&file_stats),
                Err(e) => {
                    eprintln!("Error indexing {}: {}", file_path.display(), e);
                    stats.errors += 1;
                }
            }
        }

        stats.duration_ms = start.elapsed().as_millis() as u64;

        // Update stats
        VectorStore::update_stats(
            self.conn,
            content_type,
            stats.items_indexed as i64,
            stats.chunks_created as i64,
            stats.duration_ms as i64,
        )?;

        Ok(stats)
    }

    /// Index a single file
    pub fn index_file(
        &mut self,
        path: &Path,
        content_type: ContentType,
        force: bool,
    ) -> Result<IndexStats> {
        let mut stats = IndexStats::default();

        // Read file content
        let content = std::fs::read_to_string(path)
            .with_context(|| format!("Failed to read file: {}", path.display()))?;

        if content.is_empty() {
            stats.items_skipped += 1;
            return Ok(stats);
        }

        let content_id = path.to_string_lossy().to_string();
        let hash = Self::hash_content(&content);

        // Check if content changed
        if !force {
            if let Some(existing_hash) =
                VectorStore::get_content_hash(self.conn, content_type, &content_id)?
            {
                if existing_hash == hash {
                    stats.items_skipped += 1;
                    return Ok(stats);
                }
            }
        }

        // Delete old embeddings for this file
        VectorStore::delete_embeddings(self.conn, content_type, &content_id)?;

        // Get file extension
        let extension = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("");

        // Chunk the content
        let chunks = if content_type == ContentType::Code {
            self.chunker.chunk_code(&content, extension)
        } else {
            self.chunker.chunk(&content)
        };

        // Generate embeddings for each chunk
        for chunk in &chunks {
            match self.embedder.embed_one(&chunk.text) {
                Ok(embedding) => {
                    let preview = Self::create_preview(&chunk.text, 200);
                    let metadata = serde_json::json!({
                        "file_path": content_id,
                        "file_type": extension,
                        "line_start": chunk.line_start,
                        "line_end": chunk.line_end,
                        "char_start": chunk.start_char,
                        "char_end": chunk.end_char,
                    });

                    VectorStore::store_embedding(
                        self.conn,
                        content_type,
                        &content_id,
                        chunk.index as i32,
                        Some(&preview),
                        &hash,
                        &embedding,
                        Some(&metadata.to_string()),
                    )?;
                    stats.chunks_created += 1;
                }
                Err(e) => {
                    eprintln!(
                        "Error embedding chunk {} of {}: {}",
                        chunk.index,
                        path.display(),
                        e
                    );
                    stats.errors += 1;
                }
            }
        }

        if stats.chunks_created > 0 {
            stats.items_indexed = 1;
        }

        Ok(stats)
    }

    /// Check if a file should be indexed based on content type
    fn is_indexable_file(path: &Path, content_type: ContentType) -> bool {
        let extension = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();

        match content_type {
            ContentType::Code => {
                matches!(
                    extension.as_str(),
                    "rs" | "ts"
                        | "tsx"
                        | "js"
                        | "jsx"
                        | "py"
                        | "go"
                        | "java"
                        | "c"
                        | "cpp"
                        | "h"
                        | "hpp"
                        | "cs"
                        | "rb"
                        | "php"
                        | "swift"
                        | "kt"
                        | "scala"
                        | "vue"
                        | "svelte"
                )
            }
            ContentType::Doc => {
                matches!(
                    extension.as_str(),
                    "md" | "txt" | "rst" | "adoc" | "yaml" | "yml" | "json" | "toml"
                )
            }
            ContentType::Task => false, // Tasks come from database, not files
        }
    }

    /// Create a preview of content (first N characters)
    fn create_preview(content: &str, max_len: usize) -> String {
        let preview: String = content
            .chars()
            .take(max_len)
            .collect::<String>()
            .replace('\n', " ")
            .replace("  ", " ");

        if content.len() > max_len {
            format!("{}...", preview.trim())
        } else {
            preview.trim().to_string()
        }
    }

    /// Hash content for change detection
    fn hash_content(content: &str) -> String {
        let mut hasher = Sha256::new();
        hasher.update(content.as_bytes());
        format!("{:x}", hasher.finalize())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hash_content() {
        let hash1 = ContentIndexer::<'_>::hash_content("hello");
        let hash2 = ContentIndexer::<'_>::hash_content("hello");
        let hash3 = ContentIndexer::<'_>::hash_content("world");

        assert_eq!(hash1, hash2);
        assert_ne!(hash1, hash3);
    }

    #[test]
    fn test_create_preview() {
        let content = "This is a long text\nthat spans multiple lines\nand has lots of content.";
        let preview = ContentIndexer::<'_>::create_preview(content, 30);

        assert!(preview.len() <= 33); // 30 + "..."
        assert!(!preview.contains('\n'));
    }

    #[test]
    fn test_is_indexable_code() {
        assert!(ContentIndexer::<'_>::is_indexable_file(
            Path::new("main.rs"),
            ContentType::Code
        ));
        assert!(ContentIndexer::<'_>::is_indexable_file(
            Path::new("app.tsx"),
            ContentType::Code
        ));
        assert!(!ContentIndexer::<'_>::is_indexable_file(
            Path::new("readme.md"),
            ContentType::Code
        ));
    }

    #[test]
    fn test_is_indexable_doc() {
        assert!(ContentIndexer::<'_>::is_indexable_file(
            Path::new("README.md"),
            ContentType::Doc
        ));
        assert!(ContentIndexer::<'_>::is_indexable_file(
            Path::new("config.yaml"),
            ContentType::Doc
        ));
        assert!(!ContentIndexer::<'_>::is_indexable_file(
            Path::new("main.rs"),
            ContentType::Doc
        ));
    }

    #[test]
    fn test_stats_merge() {
        let mut stats1 = IndexStats {
            items_indexed: 5,
            items_skipped: 2,
            chunks_created: 10,
            errors: 1,
            duration_ms: 100,
        };

        let stats2 = IndexStats {
            items_indexed: 3,
            items_skipped: 1,
            chunks_created: 6,
            errors: 0,
            duration_ms: 50,
        };

        stats1.merge(&stats2);

        assert_eq!(stats1.items_indexed, 8);
        assert_eq!(stats1.items_skipped, 3);
        assert_eq!(stats1.chunks_created, 16);
        assert_eq!(stats1.errors, 1);
        assert_eq!(stats1.duration_ms, 150);
    }
}
