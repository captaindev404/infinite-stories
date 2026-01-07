//! Similarity search module - performs vector similarity queries

use anyhow::Result;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};

use super::store::{ContentType, EmbeddingRecord, VectorStore};
use super::Embedder;

/// A search result with similarity score
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub record: EmbeddingRecord,
    pub similarity: f32,
    pub rank: usize,
}

/// Vector search engine
pub struct VectorSearch;

impl VectorSearch {
    /// Search for similar content using a text query
    pub fn search_text(
        conn: &Connection,
        embedder: &mut Embedder,
        query: &str,
        content_type: Option<ContentType>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<SearchResult>> {
        let query_embedding = embedder.embed_one(query)?;
        Self::search_embedding(conn, &query_embedding, content_type, limit, threshold)
    }

    /// Search for similar content using an embedding vector
    pub fn search_embedding(
        conn: &Connection,
        query_embedding: &[f32],
        content_type: Option<ContentType>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<SearchResult>> {
        let all_embeddings = VectorStore::get_all_embeddings(conn, content_type)?;

        let mut results: Vec<SearchResult> = all_embeddings
            .into_iter()
            .map(|(record, embedding)| {
                let similarity = Self::cosine_similarity(query_embedding, &embedding);
                SearchResult {
                    record,
                    similarity,
                    rank: 0,
                }
            })
            .filter(|r| r.similarity >= threshold)
            .collect();

        // Sort by similarity (descending)
        results.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap());

        // Assign ranks and limit results
        for (i, result) in results.iter_mut().enumerate() {
            result.rank = i + 1;
        }

        Ok(results.into_iter().take(limit).collect())
    }

    /// Find content similar to a specific item
    pub fn find_similar(
        conn: &Connection,
        content_type: ContentType,
        content_id: &str,
        search_types: Option<Vec<ContentType>>,
        limit: usize,
        threshold: f32,
    ) -> Result<Vec<SearchResult>> {
        // Get the embedding for the source item
        let source_embeddings = VectorStore::get_all_embeddings(conn, Some(content_type))?;

        let source = source_embeddings
            .iter()
            .find(|(record, _)| record.content_id == content_id && record.chunk_index == 0)
            .ok_or_else(|| anyhow::anyhow!("Content not found: {}", content_id))?;

        let source_embedding = &source.1;

        // Get all embeddings to search through
        let search_embeddings = match search_types {
            Some(types) => {
                let mut all = Vec::new();
                for t in types {
                    all.extend(VectorStore::get_all_embeddings(conn, Some(t))?);
                }
                all
            }
            None => VectorStore::get_all_embeddings(conn, None)?,
        };

        let mut results: Vec<SearchResult> = search_embeddings
            .into_iter()
            .filter(|(record, _)| {
                // Exclude the source item itself
                !(record.content_type == content_type && record.content_id == content_id)
            })
            .map(|(record, embedding)| {
                let similarity = Self::cosine_similarity(source_embedding, &embedding);
                SearchResult {
                    record,
                    similarity,
                    rank: 0,
                }
            })
            .filter(|r| r.similarity >= threshold)
            .collect();

        results.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap());

        // Deduplicate by content_id (keep highest similarity chunk)
        let mut seen_ids = std::collections::HashSet::new();
        let mut deduped = Vec::new();
        for mut result in results {
            let key = format!("{}:{}", result.record.content_type, result.record.content_id);
            if seen_ids.insert(key) {
                result.rank = deduped.len() + 1;
                deduped.push(result);
            }
        }

        Ok(deduped.into_iter().take(limit).collect())
    }

    /// Calculate cosine similarity between two vectors
    pub fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() || a.is_empty() {
            return 0.0;
        }

        let mut dot_product = 0.0f32;
        let mut norm_a = 0.0f32;
        let mut norm_b = 0.0f32;

        for i in 0..a.len() {
            dot_product += a[i] * b[i];
            norm_a += a[i] * a[i];
            norm_b += b[i] * b[i];
        }

        let denominator = norm_a.sqrt() * norm_b.sqrt();
        if denominator == 0.0 {
            return 0.0;
        }

        dot_product / denominator
    }

    /// Calculate Euclidean distance between two vectors
    #[allow(dead_code)]
    pub fn euclidean_distance(a: &[f32], b: &[f32]) -> f32 {
        if a.len() != b.len() {
            return f32::INFINITY;
        }

        let sum: f32 = a.iter().zip(b.iter()).map(|(x, y)| (x - y).powi(2)).sum();
        sum.sqrt()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cosine_similarity_identical() {
        let a = vec![1.0, 2.0, 3.0];
        let b = vec![1.0, 2.0, 3.0];
        let sim = VectorSearch::cosine_similarity(&a, &b);
        assert!((sim - 1.0).abs() < 1e-6);
    }

    #[test]
    fn test_cosine_similarity_orthogonal() {
        let a = vec![1.0, 0.0, 0.0];
        let b = vec![0.0, 1.0, 0.0];
        let sim = VectorSearch::cosine_similarity(&a, &b);
        assert!(sim.abs() < 1e-6);
    }

    #[test]
    fn test_cosine_similarity_opposite() {
        let a = vec![1.0, 2.0, 3.0];
        let b = vec![-1.0, -2.0, -3.0];
        let sim = VectorSearch::cosine_similarity(&a, &b);
        assert!((sim + 1.0).abs() < 1e-6);
    }

    #[test]
    fn test_cosine_similarity_different_magnitude() {
        let a = vec![1.0, 0.0];
        let b = vec![100.0, 0.0];
        let sim = VectorSearch::cosine_similarity(&a, &b);
        assert!((sim - 1.0).abs() < 1e-6); // Direction same, magnitude irrelevant
    }

    #[test]
    fn test_euclidean_distance() {
        let a = vec![0.0, 0.0, 0.0];
        let b = vec![1.0, 0.0, 0.0];
        let dist = VectorSearch::euclidean_distance(&a, &b);
        assert!((dist - 1.0).abs() < 1e-6);
    }

    #[test]
    fn test_empty_vectors() {
        let a: Vec<f32> = vec![];
        let b: Vec<f32> = vec![];
        let sim = VectorSearch::cosine_similarity(&a, &b);
        assert_eq!(sim, 0.0);
    }
}
