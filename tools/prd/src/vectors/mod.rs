//! Vector embeddings module for semantic search capabilities
//!
//! This module provides:
//! - Text embeddings using fastembed (BAAI/bge-small-en-v1.5)
//! - Vector storage in SQLite
//! - Content indexing (tasks, code, documentation)
//! - Similarity search

pub mod chunker;
pub mod embedder;
pub mod indexer;
pub mod search;
pub mod store;

pub use chunker::{Chunk, TextChunker};
pub use embedder::Embedder;
pub use indexer::{ContentIndexer, IndexStats};
pub use search::{SearchResult, VectorSearch};
pub use store::{ContentType, EmbeddingRecord, VectorStore};

/// Vector dimension for bge-small-en-v1.5 model
pub const EMBEDDING_DIM: usize = 384;

/// Maximum chunk size in characters (approx 500 tokens)
pub const MAX_CHUNK_SIZE: usize = 2000;

/// Overlap between chunks in characters
pub const CHUNK_OVERLAP: usize = 200;
