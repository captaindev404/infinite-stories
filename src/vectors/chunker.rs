//! Text chunking module - splits large content into manageable chunks

use super::{CHUNK_OVERLAP, MAX_CHUNK_SIZE};

/// Find the nearest valid UTF-8 character boundary at or before the given byte index
fn floor_char_boundary(s: &str, index: usize) -> usize {
    if index >= s.len() {
        return s.len();
    }
    let mut i = index;
    while i > 0 && !s.is_char_boundary(i) {
        i -= 1;
    }
    i
}

/// Find the nearest valid UTF-8 character boundary at or after the given byte index
fn ceil_char_boundary(s: &str, index: usize) -> usize {
    if index >= s.len() {
        return s.len();
    }
    let mut i = index;
    while i < s.len() && !s.is_char_boundary(i) {
        i += 1;
    }
    i
}

/// A chunk of text with metadata
#[derive(Debug, Clone)]
pub struct Chunk {
    pub index: usize,
    pub text: String,
    pub start_char: usize,
    pub end_char: usize,
    pub line_start: Option<usize>,
    pub line_end: Option<usize>,
}

/// Text chunker for splitting large content
pub struct TextChunker {
    max_size: usize,
    overlap: usize,
}

impl TextChunker {
    /// Create a new chunker with default settings
    pub fn new() -> Self {
        Self {
            max_size: MAX_CHUNK_SIZE,
            overlap: CHUNK_OVERLAP,
        }
    }

    /// Create a chunker with custom settings
    pub fn with_settings(max_size: usize, overlap: usize) -> Self {
        Self { max_size, overlap }
    }

    /// Chunk text into overlapping segments
    pub fn chunk(&self, text: &str) -> Vec<Chunk> {
        if text.len() <= self.max_size {
            return vec![Chunk {
                index: 0,
                text: text.to_string(),
                start_char: 0,
                end_char: text.len(),
                line_start: Some(1),
                line_end: Some(text.lines().count()),
            }];
        }

        let mut chunks = Vec::new();
        let mut start = 0;
        let mut chunk_index = 0;

        while start < text.len() {
            let end = self.find_chunk_end(text, start);
            // Ensure we're on valid char boundaries
            let safe_start = ceil_char_boundary(text, start);
            let safe_end = floor_char_boundary(text, end);
            if safe_start >= safe_end {
                break;
            }
            let chunk_text = &text[safe_start..safe_end];

            // Calculate line numbers
            let line_start = text[..safe_start].matches('\n').count() + 1;
            let line_end = line_start + chunk_text.matches('\n').count();

            chunks.push(Chunk {
                index: chunk_index,
                text: chunk_text.to_string(),
                start_char: safe_start,
                end_char: safe_end,
                line_start: Some(line_start),
                line_end: Some(line_end),
            });

            // Move start position, accounting for overlap
            if end >= text.len() {
                break;
            }

            start = end.saturating_sub(self.overlap);
            // Try to start at a natural boundary
            start = self.find_natural_start(text, start, end);
            chunk_index += 1;
        }

        chunks
    }

    /// Chunk code with awareness of code structure
    pub fn chunk_code(&self, text: &str, _file_extension: &str) -> Vec<Chunk> {
        // For code, we try to split at function/class boundaries
        // This is a simplified version - a full implementation would parse AST

        if text.len() <= self.max_size {
            return vec![Chunk {
                index: 0,
                text: text.to_string(),
                start_char: 0,
                end_char: text.len(),
                line_start: Some(1),
                line_end: Some(text.lines().count()),
            }];
        }

        let mut chunks = Vec::new();
        let mut start = 0;
        let mut chunk_index = 0;

        while start < text.len() {
            let end = self.find_code_chunk_end(text, start);
            // Ensure we're on valid char boundaries
            let safe_start = ceil_char_boundary(text, start);
            let safe_end = floor_char_boundary(text, end);
            if safe_start >= safe_end {
                break;
            }
            let chunk_text = &text[safe_start..safe_end];

            let line_start = text[..safe_start].matches('\n').count() + 1;
            let line_end = line_start + chunk_text.matches('\n').count();

            chunks.push(Chunk {
                index: chunk_index,
                text: chunk_text.to_string(),
                start_char: safe_start,
                end_char: safe_end,
                line_start: Some(line_start),
                line_end: Some(line_end),
            });

            if safe_end >= text.len() {
                break;
            }

            start = safe_end.saturating_sub(self.overlap);
            start = self.find_code_natural_start(text, start, safe_end);
            chunk_index += 1;
        }

        chunks
    }

    /// Find a good end position for a text chunk
    fn find_chunk_end(&self, text: &str, start: usize) -> usize {
        let safe_start = ceil_char_boundary(text, start);
        let ideal_end = floor_char_boundary(text, (start + self.max_size).min(text.len()));

        if ideal_end >= text.len() {
            return text.len();
        }

        if safe_start >= ideal_end {
            return ideal_end;
        }

        let search_text = &text[safe_start..ideal_end];

        // Try to end at a paragraph boundary
        if let Some(pos) = search_text.rfind("\n\n") {
            return safe_start + pos + 2;
        }

        // Try to end at a sentence boundary
        for pattern in [". ", ".\n", "! ", "!\n", "? ", "?\n"] {
            if let Some(pos) = search_text.rfind(pattern) {
                return safe_start + pos + pattern.len();
            }
        }

        // Try to end at a line boundary
        if let Some(pos) = search_text.rfind('\n') {
            return safe_start + pos + 1;
        }

        // Fall back to word boundary
        if let Some(pos) = search_text.rfind(' ') {
            return safe_start + pos + 1;
        }

        ideal_end
    }

    /// Find a good end position for a code chunk
    fn find_code_chunk_end(&self, text: &str, start: usize) -> usize {
        let safe_start = ceil_char_boundary(text, start);
        let ideal_end = floor_char_boundary(text, (start + self.max_size).min(text.len()));

        if ideal_end >= text.len() {
            return text.len();
        }

        if safe_start >= ideal_end {
            return ideal_end;
        }

        // Look for function/block endings (simplified)
        let search_text = &text[safe_start..ideal_end];

        // Try to end at a closing brace followed by newline
        if let Some(pos) = search_text.rfind("}\n") {
            let end_pos = safe_start + pos + 2;
            // Make sure we're not cutting a block too short
            if end_pos > safe_start + self.max_size / 2 {
                return end_pos;
            }
        }

        // Try to end at an empty line (often between functions)
        if let Some(pos) = search_text.rfind("\n\n") {
            return safe_start + pos + 2;
        }

        // Try to end at a line that starts with fn, def, class, pub, etc.
        for pattern in ["\nfn ", "\ndef ", "\nclass ", "\npub ", "\nimpl ", "\nfunc "] {
            if let Some(pos) = search_text.rfind(pattern) {
                return safe_start + pos + 1;
            }
        }

        // Fall back to line boundary
        if let Some(pos) = search_text.rfind('\n') {
            return safe_start + pos + 1;
        }

        ideal_end
    }

    /// Find a natural starting point for a text chunk
    fn find_natural_start(&self, text: &str, start: usize, end: usize) -> usize {
        if start == 0 {
            return 0;
        }

        let search_start = floor_char_boundary(text, start.saturating_sub(100));
        let search_end = floor_char_boundary(text, start.min(text.len()));

        if search_start >= search_end {
            return ceil_char_boundary(text, start.min(end));
        }

        let search_text = &text[search_start..search_end];

        // Try to start at a paragraph
        if let Some(pos) = search_text.find("\n\n") {
            return search_start + pos + 2;
        }

        // Try to start at a line
        if let Some(pos) = search_text.rfind('\n') {
            return search_start + pos + 1;
        }

        ceil_char_boundary(text, start.min(end))
    }

    /// Find a natural starting point for a code chunk
    fn find_code_natural_start(&self, text: &str, start: usize, end: usize) -> usize {
        if start == 0 {
            return 0;
        }

        let search_start = floor_char_boundary(text, start.saturating_sub(100));
        let search_end = floor_char_boundary(text, start.min(text.len()));

        if search_start >= search_end {
            return ceil_char_boundary(text, start.min(end));
        }

        let search_text = &text[search_start..search_end];

        // Try to start at a function definition
        for pattern in ["\nfn ", "\ndef ", "\nclass ", "\npub ", "\nimpl ", "\nfunc "] {
            if let Some(pos) = search_text.rfind(pattern) {
                return search_start + pos + 1;
            }
        }

        // Try to start at an empty line
        if let Some(pos) = search_text.rfind("\n\n") {
            return search_start + pos + 2;
        }

        // Fall back to line boundary
        if let Some(pos) = search_text.rfind('\n') {
            return search_start + pos + 1;
        }

        ceil_char_boundary(text, start.min(end))
    }
}

impl Default for TextChunker {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_small_text_no_chunk() {
        let chunker = TextChunker::new();
        let text = "This is a small text.";
        let chunks = chunker.chunk(text);

        assert_eq!(chunks.len(), 1);
        assert_eq!(chunks[0].text, text);
        assert_eq!(chunks[0].index, 0);
    }

    #[test]
    fn test_large_text_chunks() {
        let chunker = TextChunker::with_settings(100, 20);
        let text = "A".repeat(250);
        let chunks = chunker.chunk(&text);

        assert!(chunks.len() > 1);

        // Verify coverage
        let total_len: usize = chunks.iter().map(|c| c.text.len()).sum();
        assert!(total_len >= text.len()); // May be greater due to overlap
    }

    #[test]
    fn test_paragraph_boundary() {
        let chunker = TextChunker::with_settings(100, 20);
        let text = format!(
            "First paragraph with content.\n\nSecond paragraph.\n\n{}",
            "Third paragraph. ".repeat(10)
        );
        let chunks = chunker.chunk(&text);

        // Should try to split at paragraph boundaries
        assert!(chunks.len() >= 1);
    }

    #[test]
    fn test_code_chunking() {
        let chunker = TextChunker::with_settings(200, 50);
        let code = r#"
fn first_function() {
    println!("Hello");
}

fn second_function() {
    println!("World");
}

fn third_function() {
    let x = 1;
    let y = 2;
    println!("{}", x + y);
}
"#;

        let chunks = chunker.chunk_code(code, "rs");
        assert!(!chunks.is_empty());

        // Verify line numbers are set
        for chunk in &chunks {
            assert!(chunk.line_start.is_some());
            assert!(chunk.line_end.is_some());
        }
    }

    #[test]
    fn test_chunk_metadata() {
        let chunker = TextChunker::with_settings(50, 10);
        let text = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8";
        let chunks = chunker.chunk(text);

        for chunk in &chunks {
            assert!(chunk.start_char < chunk.end_char);
            assert!(chunk.line_start.is_some());
            assert!(chunk.line_end.is_some());
            assert!(chunk.line_start.unwrap() <= chunk.line_end.unwrap());
        }
    }
}
