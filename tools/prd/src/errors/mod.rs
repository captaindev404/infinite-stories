pub mod context;

#[cfg(test)]
mod tests;

pub use context::{levenshtein_distance, similarity_score, ErrorContext};
