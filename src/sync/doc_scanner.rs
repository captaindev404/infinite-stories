use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use regex::Regex;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};

/// Represents a parsed completion document
#[derive(Debug, Clone)]
pub struct CompletionDoc {
    /// Task ID extracted from filename
    pub task_id: i32,
    /// Optional agent ID from frontmatter
    pub agent_id: Option<String>,
    /// Completion timestamp (from frontmatter or file mtime)
    pub completed_at: DateTime<Utc>,
    /// Full path to the document
    pub file_path: PathBuf,
    /// Optional git commit hash (for git-based completions)
    pub git_commit_hash: Option<String>,
}

/// Frontmatter metadata (optional)
#[derive(Debug, Deserialize)]
struct Frontmatter {
    #[allow(dead_code)]
    task_id: Option<i32>,
    agent_id: Option<String>,
    completed_at: Option<String>,
}

/// Extract task ID from filename
///
/// Supports formats:
/// - TASK-033-COMPLETION.md → 33
/// - TASK-050-TESTING-GUIDE.md → 50
/// - TASK-054-AUTOSAVE-IMPLEMENTATION.md → 54
///
/// # Returns
/// * `Some(task_id)` if valid format
/// * `None` if invalid or no match
fn extract_task_id_from_filename(path: &Path) -> Option<i32> {
    let filename = path.file_name()?.to_str()?;
    let re = Regex::new(r"^TASK-(\d+)-").ok()?;
    let captures = re.captures(filename)?;
    let id_str = captures.get(1)?.as_str();
    id_str.parse::<i32>().ok()
}

/// Get file modified time
fn get_file_modified_time(path: &Path) -> Option<DateTime<Utc>> {
    let metadata = fs::metadata(path).ok()?;
    let modified = metadata.modified().ok()?;
    let datetime: DateTime<Utc> = modified.into();
    Some(datetime)
}

/// Parse YAML frontmatter from markdown file
///
/// Looks for:
/// ```markdown
/// ---
/// task_id: 33
/// agent_id: A11
/// completed_at: 2025-10-13T10:30:00Z
/// ---
/// ```
///
/// # Returns
/// * `Some(Frontmatter)` if found and valid
/// * `None` if no frontmatter or invalid YAML
fn parse_frontmatter(content: &str) -> Option<Frontmatter> {
    // Check if content starts with ---
    if !content.starts_with("---") {
        return None;
    }

    // Find the closing ---
    let lines: Vec<&str> = content.lines().collect();
    if lines.len() < 3 {
        return None;
    }

    let mut end_index = None;
    for (i, line) in lines.iter().enumerate().skip(1) {
        if line.trim() == "---" {
            end_index = Some(i);
            break;
        }
    }

    let end_index = end_index?;

    // Extract YAML content (excluding the --- delimiters)
    let yaml_lines = &lines[1..end_index];
    let yaml_content = yaml_lines.join("\n");

    // Parse YAML
    serde_yaml::from_str(&yaml_content).ok()
}

/// Parse a single completion document
///
/// # Steps
/// 1. Extract task ID from filename
/// 2. Read file contents
/// 3. Parse YAML frontmatter (if present)
/// 4. Get file modified time as fallback
/// 5. Return CompletionDoc
///
/// # Returns
/// * `Some(CompletionDoc)` on success
/// * `None` if parsing fails (logs warning)
pub fn parse_completion_doc(path: PathBuf) -> Option<CompletionDoc> {
    // Step 1: Extract task ID from filename
    let task_id = extract_task_id_from_filename(&path)?;

    // Step 2: Read file contents
    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("Warning: Failed to read file {:?}: {}", path, e);
            return None;
        }
    };

    // Step 3: Parse frontmatter
    let frontmatter = parse_frontmatter(&content);

    // Step 4: Get completion timestamp
    let completed_at = if let Some(ref fm) = frontmatter {
        if let Some(ref timestamp_str) = fm.completed_at {
            // Try to parse ISO 8601 timestamp
            DateTime::parse_from_rfc3339(timestamp_str)
                .ok()
                .map(|dt| dt.with_timezone(&Utc))
                .or_else(|| get_file_modified_time(&path))
        } else {
            get_file_modified_time(&path)
        }
    } else {
        get_file_modified_time(&path)
    };

    let completed_at = completed_at?;

    // Extract agent_id from frontmatter
    let agent_id = frontmatter.and_then(|fm| fm.agent_id);

    Some(CompletionDoc {
        task_id,
        agent_id,
        completed_at,
        file_path: path,
        git_commit_hash: None,
    })
}

/// Scan a directory for completion documents
///
/// # Arguments
/// * `docs_dir` - Path to docs/tasks/ directory
///
/// # Returns
/// * `Ok(Vec<CompletionDoc>)` - List of parsed documents
/// * `Err(_)` - If directory doesn't exist or can't be read
///
/// # Example
/// ```
/// use std::path::Path;
/// use prd_tool::sync::scan_completion_docs;
///
/// let docs = scan_completion_docs(Path::new("docs/tasks")).unwrap();
/// println!("Found {} completion documents", docs.len());
/// ```
pub fn scan_completion_docs(docs_dir: &Path) -> Result<Vec<CompletionDoc>> {
    // Step 1: Check if directory exists
    if !docs_dir.exists() {
        return Err(anyhow::anyhow!(
            "Directory does not exist: {}",
            docs_dir.display()
        ));
    }

    if !docs_dir.is_dir() {
        return Err(anyhow::anyhow!(
            "Path is not a directory: {}",
            docs_dir.display()
        ));
    }

    // Step 2: Glob for TASK-*.md files
    let pattern = docs_dir.join("TASK-*.md");
    let pattern_str = pattern
        .to_str()
        .context("Failed to convert path to string")?;

    let mut docs = Vec::new();

    for entry in glob::glob(pattern_str).context("Failed to read glob pattern")? {
        match entry {
            Ok(path) => {
                // Step 3: Parse each file
                if let Some(doc) = parse_completion_doc(path) {
                    docs.push(doc);
                }
            }
            Err(e) => {
                eprintln!("Warning: Failed to read glob entry: {}", e);
            }
        }
    }

    // Step 5: Return results
    Ok(docs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_task_id_standard_format() {
        let path = Path::new("TASK-033-COMPLETION.md");
        assert_eq!(extract_task_id_from_filename(path), Some(33));
    }

    #[test]
    fn test_extract_task_id_custom_suffix() {
        let path = Path::new("TASK-050-TESTING-GUIDE.md");
        assert_eq!(extract_task_id_from_filename(path), Some(50));
    }

    #[test]
    fn test_extract_task_id_multi_digit() {
        let path = Path::new("TASK-100-IMPLEMENTATION.md");
        assert_eq!(extract_task_id_from_filename(path), Some(100));
    }

    #[test]
    fn test_extract_task_id_invalid_format() {
        let path = Path::new("README.md");
        assert_eq!(extract_task_id_from_filename(path), None);
    }

    #[test]
    fn test_extract_task_id_wrong_prefix() {
        let path = Path::new("INVALID-033.md");
        assert_eq!(extract_task_id_from_filename(path), None);
    }

    #[test]
    fn test_parse_frontmatter_full() {
        let content = r#"---
task_id: 33
agent_id: A11
completed_at: 2025-10-13T10:30:00Z
---

# Task 33 Completion
"#;
        let fm = parse_frontmatter(content).unwrap();
        assert_eq!(fm.task_id, Some(33));
        assert_eq!(fm.agent_id, Some("A11".to_string()));
        assert_eq!(fm.completed_at, Some("2025-10-13T10:30:00Z".to_string()));
    }

    #[test]
    fn test_parse_frontmatter_partial() {
        let content = r#"---
agent_id: A11
---

# Task Completion
"#;
        let fm = parse_frontmatter(content).unwrap();
        assert_eq!(fm.task_id, None);
        assert_eq!(fm.agent_id, Some("A11".to_string()));
        assert_eq!(fm.completed_at, None);
    }

    #[test]
    fn test_parse_frontmatter_missing() {
        let content = "# No frontmatter here";
        assert!(parse_frontmatter(content).is_none());
    }

    #[test]
    fn test_parse_frontmatter_invalid_yaml() {
        let content = r#"---
invalid yaml: [
---

# Content
"#;
        assert!(parse_frontmatter(content).is_none());
    }

    #[test]
    fn test_parse_frontmatter_no_closing() {
        let content = r#"---
task_id: 33

# Missing closing delimiter
"#;
        assert!(parse_frontmatter(content).is_none());
    }
}
