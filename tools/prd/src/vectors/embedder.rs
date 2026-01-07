//! Embedder module - wraps fastembed for text embedding generation

use anyhow::{Context, Result};
use fastembed::{EmbeddingModel, InitOptions, TextEmbedding};

use super::EMBEDDING_DIM;

/// Wrapper around fastembed for generating text embeddings
pub struct Embedder {
    model: Option<TextEmbedding>,
}

impl Embedder {
    /// Create a new embedder (model loaded lazily on first use)
    pub fn new() -> Self {
        Self { model: None }
    }

    /// Ensure the model is loaded
    fn ensure_loaded(&mut self) -> Result<&TextEmbedding> {
        if self.model.is_none() {
            let mut init_options = InitOptions::default();
            init_options.model_name = EmbeddingModel::BGESmallENV15;
            init_options.show_download_progress = true;

            let model = TextEmbedding::try_new(init_options)
                .context("Failed to initialize embedding model")?;

            self.model = Some(model);
        }

        Ok(self.model.as_ref().unwrap())
    }

    /// Generate embeddings for multiple texts (more efficient for batches)
    pub fn embed_batch(&mut self, texts: &[&str]) -> Result<Vec<Vec<f32>>> {
        if texts.is_empty() {
            return Ok(vec![]);
        }

        let model = self.ensure_loaded()?;
        let embeddings = model
            .embed(texts.to_vec(), None)
            .context("Failed to generate embeddings")?;

        // Validate dimensions
        for (i, emb) in embeddings.iter().enumerate() {
            if emb.len() != EMBEDDING_DIM {
                anyhow::bail!(
                    "Unexpected embedding dimension: got {}, expected {} (text {})",
                    emb.len(),
                    EMBEDDING_DIM,
                    i
                );
            }
        }

        Ok(embeddings)
    }

    /// Generate embedding for a single text
    pub fn embed_one(&mut self, text: &str) -> Result<Vec<f32>> {
        let results = self.embed_batch(&[text])?;
        results
            .into_iter()
            .next()
            .ok_or_else(|| anyhow::anyhow!("No embedding generated"))
    }

    /// Check if model is loaded
    pub fn is_loaded(&self) -> bool {
        self.model.is_some()
    }
}

impl Default for Embedder {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore] // Requires model download
    fn test_embed_one() {
        let mut embedder = Embedder::new();
        let embedding = embedder.embed_one("Hello, world!").unwrap();
        assert_eq!(embedding.len(), EMBEDDING_DIM);
    }

    #[test]
    #[ignore] // Requires model download
    fn test_embed_batch() {
        let mut embedder = Embedder::new();
        let embeddings = embedder
            .embed_batch(&["Hello", "World", "Test"])
            .unwrap();
        assert_eq!(embeddings.len(), 3);
        for emb in embeddings {
            assert_eq!(emb.len(), EMBEDDING_DIM);
        }
    }

    #[test]
    fn test_embed_empty() {
        let mut embedder = Embedder::new();
        let embeddings = embedder.embed_batch(&[]).unwrap();
        assert!(embeddings.is_empty());
    }
}
