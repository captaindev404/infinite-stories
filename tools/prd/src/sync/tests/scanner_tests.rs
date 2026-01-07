use crate::sync::scan_completion_docs;
use std::fs;
use std::time::{Duration, Instant};
use tempfile::tempdir;

#[test]
fn test_scan_empty_directory() {
    let temp_dir = tempdir().unwrap();
    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 0);
}

#[test]
fn test_scan_with_valid_docs() {
    let temp_dir = tempdir().unwrap();

    // Create test files
    fs::write(temp_dir.path().join("TASK-033-COMPLETION.md"), "# Task 33").unwrap();
    fs::write(temp_dir.path().join("TASK-050-TEST.md"), "# Task 50").unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 2);

    // Check task IDs were extracted
    let ids: Vec<i32> = docs.iter().map(|d| d.task_id).collect();
    assert!(ids.contains(&33));
    assert!(ids.contains(&50));
}

#[test]
fn test_scan_skips_invalid_files() {
    let temp_dir = tempdir().unwrap();

    // Create mix of valid and invalid files
    fs::write(temp_dir.path().join("TASK-033-COMPLETION.md"), "# Task 33").unwrap();
    fs::write(temp_dir.path().join("README.md"), "# README").unwrap();
    fs::write(temp_dir.path().join("INVALID-033.md"), "# Invalid").unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);
    assert_eq!(docs[0].task_id, 33);
}

#[test]
fn test_scan_with_frontmatter() {
    let temp_dir = tempdir().unwrap();

    let content = r#"---
task_id: 42
agent_id: A11
completed_at: 2025-10-13T10:30:00Z
---

# Task 42 Completion

This task has been completed successfully.
"#;

    fs::write(temp_dir.path().join("TASK-042-COMPLETION.md"), content).unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);

    let doc = &docs[0];
    assert_eq!(doc.task_id, 42);
    assert_eq!(doc.agent_id, Some("A11".to_string()));
}

#[test]
fn test_scan_without_frontmatter_uses_mtime() {
    let temp_dir = tempdir().unwrap();

    fs::write(
        temp_dir.path().join("TASK-100-NO-FRONTMATTER.md"),
        "# Simple task without frontmatter",
    )
    .unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);

    let doc = &docs[0];
    assert_eq!(doc.task_id, 100);
    assert_eq!(doc.agent_id, None);
    // completed_at should be set to file mtime
    assert!(doc.completed_at.timestamp() > 0);
}

#[test]
fn test_scan_partial_frontmatter() {
    let temp_dir = tempdir().unwrap();

    let content = r#"---
agent_id: A25
---

# Task with partial frontmatter
"#;

    fs::write(temp_dir.path().join("TASK-055-PARTIAL.md"), content).unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);

    let doc = &docs[0];
    assert_eq!(doc.task_id, 55);
    assert_eq!(doc.agent_id, Some("A25".to_string()));
    // Should fall back to mtime for completed_at
    assert!(doc.completed_at.timestamp() > 0);
}

#[test]
fn test_scan_invalid_frontmatter_yaml() {
    let temp_dir = tempdir().unwrap();

    let content = r#"---
invalid: yaml: syntax: [
---

# Task with invalid YAML
"#;

    fs::write(temp_dir.path().join("TASK-066-INVALID-YAML.md"), content).unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);

    let doc = &docs[0];
    assert_eq!(doc.task_id, 66);
    // Should still parse successfully but ignore frontmatter
    assert_eq!(doc.agent_id, None);
}

#[test]
fn test_scan_nonexistent_directory() {
    let result = scan_completion_docs(std::path::Path::new(
        "/nonexistent/path/that/does/not/exist",
    ));
    assert!(result.is_err());
}

#[test]
fn test_scan_file_not_directory() {
    let temp_dir = tempdir().unwrap();
    let file_path = temp_dir.path().join("not-a-directory.txt");
    fs::write(&file_path, "test").unwrap();

    let result = scan_completion_docs(&file_path);
    assert!(result.is_err());
}

#[test]
fn test_scan_multiple_tasks_with_mixed_formats() {
    let temp_dir = tempdir().unwrap();

    // Task with full frontmatter
    fs::write(
        temp_dir.path().join("TASK-001-COMPLETION.md"),
        r#"---
task_id: 1
agent_id: A1
completed_at: 2025-10-01T10:00:00Z
---
# Task 1
"#,
    )
    .unwrap();

    // Task without frontmatter
    fs::write(temp_dir.path().join("TASK-002-COMPLETION.md"), "# Task 2").unwrap();

    // Task with partial frontmatter
    fs::write(
        temp_dir.path().join("TASK-003-COMPLETION.md"),
        r#"---
agent_id: A3
---
# Task 3
"#,
    )
    .unwrap();

    // Invalid file (should be skipped)
    fs::write(temp_dir.path().join("README.md"), "# README").unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 3);

    let ids: Vec<i32> = docs.iter().map(|d| d.task_id).collect();
    assert!(ids.contains(&1));
    assert!(ids.contains(&2));
    assert!(ids.contains(&3));

    // Check agent IDs
    let doc1 = docs.iter().find(|d| d.task_id == 1).unwrap();
    assert_eq!(doc1.agent_id, Some("A1".to_string()));

    let doc2 = docs.iter().find(|d| d.task_id == 2).unwrap();
    assert_eq!(doc2.agent_id, None);

    let doc3 = docs.iter().find(|d| d.task_id == 3).unwrap();
    assert_eq!(doc3.agent_id, Some("A3".to_string()));
}

#[test]
fn test_scan_performance_100_documents() {
    let temp_dir = tempdir().unwrap();

    // Create 100 test documents
    for i in 1..=100 {
        let content = format!("# Test Task {}", i);
        fs::write(
            temp_dir.path().join(format!("TASK-{:03}-COMPLETION.md", i)),
            content,
        )
        .unwrap();
    }

    let start = Instant::now();
    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    let duration = start.elapsed();

    assert_eq!(docs.len(), 100);
    assert!(
        duration < Duration::from_millis(500),
        "Scanning took {}ms (expected <500ms)",
        duration.as_millis()
    );
}

#[test]
fn test_scan_preserves_file_paths() {
    let temp_dir = tempdir().unwrap();

    fs::write(temp_dir.path().join("TASK-077-PATH-TEST.md"), "# Path test").unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 1);

    let doc = &docs[0];
    assert!(doc.file_path.exists());
    assert!(doc
        .file_path
        .to_string_lossy()
        .contains("TASK-077-PATH-TEST.md"));
}

#[test]
fn test_scan_handles_various_task_id_formats() {
    let temp_dir = tempdir().unwrap();

    // Single digit
    fs::write(temp_dir.path().join("TASK-1-COMPLETION.md"), "# Task 1").unwrap();

    // Double digit
    fs::write(temp_dir.path().join("TASK-42-COMPLETION.md"), "# Task 42").unwrap();

    // Triple digit
    fs::write(temp_dir.path().join("TASK-123-COMPLETION.md"), "# Task 123").unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 3);

    let ids: Vec<i32> = docs.iter().map(|d| d.task_id).collect();
    assert!(ids.contains(&1));
    assert!(ids.contains(&42));
    assert!(ids.contains(&123));
}

#[test]
fn test_scan_handles_different_suffixes() {
    let temp_dir = tempdir().unwrap();

    fs::write(temp_dir.path().join("TASK-010-COMPLETION.md"), "# Task 10").unwrap();
    fs::write(
        temp_dir.path().join("TASK-011-IMPLEMENTATION.md"),
        "# Task 11",
    )
    .unwrap();
    fs::write(
        temp_dir.path().join("TASK-012-TESTING-GUIDE.md"),
        "# Task 12",
    )
    .unwrap();
    fs::write(
        temp_dir.path().join("TASK-013-AUTOSAVE-FEATURE.md"),
        "# Task 13",
    )
    .unwrap();

    let docs = scan_completion_docs(temp_dir.path()).unwrap();
    assert_eq!(docs.len(), 4);

    let ids: Vec<i32> = docs.iter().map(|d| d.task_id).collect();
    assert!(ids.contains(&10));
    assert!(ids.contains(&11));
    assert!(ids.contains(&12));
    assert!(ids.contains(&13));
}
