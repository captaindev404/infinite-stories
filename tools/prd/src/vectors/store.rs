//! Vector storage module - handles SQLite storage and retrieval of embeddings

use anyhow::{Context, Result};
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::io::Cursor;

use super::EMBEDDING_DIM;

/// Content type for embeddings
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ContentType {
    Task,
    Code,
    Doc,
}

impl ContentType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ContentType::Task => "task",
            ContentType::Code => "code",
            ContentType::Doc => "doc",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "task" | "tasks" => Some(ContentType::Task),
            "code" => Some(ContentType::Code),
            "doc" | "docs" => Some(ContentType::Doc),
            _ => None,
        }
    }
}

impl std::fmt::Display for ContentType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

/// A stored embedding record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingRecord {
    pub id: i64,
    pub content_type: ContentType,
    pub content_id: String,
    pub chunk_index: i32,
    pub content_preview: Option<String>,
    pub content_hash: String,
    pub metadata: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// Vector statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorStats {
    pub content_type: ContentType,
    pub total_items: i64,
    pub total_chunks: i64,
    pub last_indexed_at: Option<DateTime<Utc>>,
    pub index_duration_ms: Option<i64>,
}

/// Vector store operations
pub struct VectorStore;

impl VectorStore {
    /// Store an embedding in the database
    pub fn store_embedding(
        conn: &Connection,
        content_type: ContentType,
        content_id: &str,
        chunk_index: i32,
        content_preview: Option<&str>,
        content_hash: &str,
        embedding: &[f32],
        metadata: Option<&str>,
    ) -> Result<i64> {
        if embedding.len() != EMBEDDING_DIM {
            anyhow::bail!(
                "Invalid embedding dimension: got {}, expected {}",
                embedding.len(),
                EMBEDDING_DIM
            );
        }

        let embedding_blob = Self::encode_embedding(embedding)?;
        let now = Utc::now().to_rfc3339();

        conn.execute(
            r#"
            INSERT INTO embeddings (content_type, content_id, chunk_index, content_preview, content_hash, embedding, metadata, created_at, updated_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?8)
            ON CONFLICT(content_type, content_id, chunk_index)
            DO UPDATE SET
                content_preview = excluded.content_preview,
                content_hash = excluded.content_hash,
                embedding = excluded.embedding,
                metadata = excluded.metadata,
                updated_at = excluded.updated_at
            "#,
            params![
                content_type.as_str(),
                content_id,
                chunk_index,
                content_preview,
                content_hash,
                embedding_blob,
                metadata,
                now
            ],
        )
        .context("Failed to store embedding")?;

        Ok(conn.last_insert_rowid())
    }

    /// Delete all embeddings for a content item
    pub fn delete_embeddings(
        conn: &Connection,
        content_type: ContentType,
        content_id: &str,
    ) -> Result<usize> {
        let deleted = conn
            .execute(
                "DELETE FROM embeddings WHERE content_type = ?1 AND content_id = ?2",
                params![content_type.as_str(), content_id],
            )
            .context("Failed to delete embeddings")?;
        Ok(deleted)
    }

    /// Delete all embeddings of a given type
    pub fn delete_all_by_type(conn: &Connection, content_type: ContentType) -> Result<usize> {
        let deleted = conn
            .execute(
                "DELETE FROM embeddings WHERE content_type = ?1",
                params![content_type.as_str()],
            )
            .context("Failed to delete embeddings by type")?;
        Ok(deleted)
    }

    /// Get content hash for a content item (to check if re-indexing needed)
    pub fn get_content_hash(
        conn: &Connection,
        content_type: ContentType,
        content_id: &str,
    ) -> Result<Option<String>> {
        let result: Option<String> = conn
            .query_row(
                "SELECT content_hash FROM embeddings WHERE content_type = ?1 AND content_id = ?2 AND chunk_index = 0",
                params![content_type.as_str(), content_id],
                |row| row.get(0),
            )
            .ok();
        Ok(result)
    }

    /// Get all embeddings (used for similarity search)
    pub fn get_all_embeddings(
        conn: &Connection,
        content_type: Option<ContentType>,
    ) -> Result<Vec<(EmbeddingRecord, Vec<f32>)>> {
        let query = match content_type {
            Some(ct) => format!(
                "SELECT id, content_type, content_id, chunk_index, content_preview, content_hash, embedding, metadata, created_at, updated_at
                 FROM embeddings WHERE content_type = '{}'
                 ORDER BY content_id, chunk_index",
                ct.as_str()
            ),
            None => "SELECT id, content_type, content_id, chunk_index, content_preview, content_hash, embedding, metadata, created_at, updated_at
                     FROM embeddings ORDER BY content_type, content_id, chunk_index".to_string(),
        };

        let mut stmt = conn.prepare(&query)?;
        let rows = stmt.query_map([], |row| {
            let ct_str: String = row.get(1)?;
            let embedding_blob: Vec<u8> = row.get(6)?;
            let created_str: String = row.get(8)?;
            let updated_str: String = row.get(9)?;

            Ok((
                EmbeddingRecord {
                    id: row.get(0)?,
                    content_type: ContentType::from_str(&ct_str).unwrap_or(ContentType::Task),
                    content_id: row.get(2)?,
                    chunk_index: row.get(3)?,
                    content_preview: row.get(4)?,
                    content_hash: row.get(5)?,
                    metadata: row.get(7)?,
                    created_at: DateTime::parse_from_rfc3339(&created_str)
                        .map(|dt| dt.with_timezone(&Utc))
                        .unwrap_or_else(|_| Utc::now()),
                    updated_at: DateTime::parse_from_rfc3339(&updated_str)
                        .map(|dt| dt.with_timezone(&Utc))
                        .unwrap_or_else(|_| Utc::now()),
                },
                embedding_blob,
            ))
        })?;

        let mut results = Vec::new();
        for row in rows {
            let (record, blob) = row?;
            let embedding = Self::decode_embedding(&blob)?;
            results.push((record, embedding));
        }

        Ok(results)
    }

    /// Get statistics for vector storage
    pub fn get_stats(conn: &Connection) -> Result<Vec<VectorStats>> {
        let mut stmt = conn.prepare(
            "SELECT content_type, total_items, total_chunks, last_indexed_at, index_duration_ms
             FROM vector_stats ORDER BY content_type",
        )?;

        let stats = stmt
            .query_map([], |row| {
                let ct_str: String = row.get(0)?;
                let last_indexed: Option<String> = row.get(3)?;

                Ok(VectorStats {
                    content_type: ContentType::from_str(&ct_str).unwrap_or(ContentType::Task),
                    total_items: row.get(1)?,
                    total_chunks: row.get(2)?,
                    last_indexed_at: last_indexed.and_then(|s| {
                        DateTime::parse_from_rfc3339(&s)
                            .map(|dt| dt.with_timezone(&Utc))
                            .ok()
                    }),
                    index_duration_ms: row.get(4)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(stats)
    }

    /// Update statistics after indexing
    pub fn update_stats(
        conn: &Connection,
        content_type: ContentType,
        total_items: i64,
        total_chunks: i64,
        duration_ms: i64,
    ) -> Result<()> {
        let now = Utc::now().to_rfc3339();

        conn.execute(
            r#"
            INSERT INTO vector_stats (content_type, total_items, total_chunks, last_indexed_at, index_duration_ms)
            VALUES (?1, ?2, ?3, ?4, ?5)
            ON CONFLICT(content_type)
            DO UPDATE SET
                total_items = excluded.total_items,
                total_chunks = excluded.total_chunks,
                last_indexed_at = excluded.last_indexed_at,
                index_duration_ms = excluded.index_duration_ms
            "#,
            params![content_type.as_str(), total_items, total_chunks, now, duration_ms],
        )?;

        Ok(())
    }

    /// Encode embedding as binary blob
    fn encode_embedding(embedding: &[f32]) -> Result<Vec<u8>> {
        let mut buf = Vec::with_capacity(embedding.len() * 4);
        for &val in embedding {
            buf.write_f32::<LittleEndian>(val)?;
        }
        Ok(buf)
    }

    /// Decode embedding from binary blob
    fn decode_embedding(blob: &[u8]) -> Result<Vec<f32>> {
        let mut cursor = Cursor::new(blob);
        let mut embedding = Vec::with_capacity(blob.len() / 4);
        while cursor.position() < blob.len() as u64 {
            embedding.push(cursor.read_f32::<LittleEndian>()?);
        }
        Ok(embedding)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn setup_test_db() -> Connection {
        let conn = Connection::open(":memory:").unwrap();
        conn.execute_batch(include_str!("../../migrations/008_add_vectors.sql"))
            .unwrap();
        conn
    }

    #[test]
    fn test_encode_decode_embedding() {
        let original: Vec<f32> = (0..384).map(|i| i as f32 * 0.001).collect();
        let encoded = VectorStore::encode_embedding(&original).unwrap();
        let decoded = VectorStore::decode_embedding(&encoded).unwrap();

        assert_eq!(original.len(), decoded.len());
        for (a, b) in original.iter().zip(decoded.iter()) {
            assert!((a - b).abs() < 1e-6);
        }
    }

    #[test]
    fn test_store_and_retrieve() {
        let conn = setup_test_db();
        let embedding: Vec<f32> = (0..384).map(|i| i as f32 * 0.001).collect();

        VectorStore::store_embedding(
            &conn,
            ContentType::Task,
            "task-1",
            0,
            Some("Test task"),
            "abc123",
            &embedding,
            None,
        )
        .unwrap();

        let hash = VectorStore::get_content_hash(&conn, ContentType::Task, "task-1").unwrap();
        assert_eq!(hash, Some("abc123".to_string()));
    }

    #[test]
    fn test_delete_embeddings() {
        let conn = setup_test_db();
        let embedding: Vec<f32> = (0..384).map(|i| i as f32 * 0.001).collect();

        VectorStore::store_embedding(
            &conn,
            ContentType::Task,
            "task-1",
            0,
            Some("Test"),
            "hash1",
            &embedding,
            None,
        )
        .unwrap();

        let deleted = VectorStore::delete_embeddings(&conn, ContentType::Task, "task-1").unwrap();
        assert_eq!(deleted, 1);

        let hash = VectorStore::get_content_hash(&conn, ContentType::Task, "task-1").unwrap();
        assert!(hash.is_none());
    }
}
