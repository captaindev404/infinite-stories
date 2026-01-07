use anyhow::Result;
use chrono::{DateTime, TimeZone, Utc};
use git2::{Commit, Repository, Time};
use regex::Regex;
use std::path::Path;

use crate::sync::CompletionDoc;

/// Git sync manager for scanning commit history
pub struct GitSync {
    repo: Repository,
}

impl GitSync {
    /// Create a new GitSync instance
    ///
    /// # Arguments
    /// * `repo_path` - Path to the git repository root
    ///
    /// # Returns
    /// * `Ok(GitSync)` - Successfully opened repository
    /// * `Err(_)` - Failed to open repository
    pub fn new(repo_path: &Path) -> Result<Self> {
        let repo = Repository::open(repo_path)?;
        Ok(Self { repo })
    }

    /// Scan git log for task completions
    ///
    /// # Arguments
    /// * `since` - Optional start date (inclusive)
    /// * `until` - Optional end date (inclusive)
    /// * `branch` - Optional branch name (defaults to HEAD)
    ///
    /// # Returns
    /// * `Ok(Vec<CompletionDoc>)` - List of found completions
    /// * `Err(_)` - Error during scanning
    pub fn scan_for_completions(
        &self,
        since: Option<DateTime<Utc>>,
        until: Option<DateTime<Utc>>,
        branch: Option<&str>,
    ) -> Result<Vec<CompletionDoc>> {
        println!("🔍 Scanning git log for task completions...");

        let mut revwalk = self.repo.revwalk()?;

        // Set starting point
        if let Some(branch_name) = branch {
            let branch = self
                .repo
                .find_branch(branch_name, git2::BranchType::Local)?;
            revwalk.push(branch.get().target().unwrap())?;
            println!("  Branch: {}", branch_name);
        } else {
            revwalk.push_head()?;
            println!("  Branch: HEAD");
        }

        // Date range
        if let Some(since_date) = since {
            println!("  Since: {}", since_date.format("%Y-%m-%d"));
        }
        if let Some(until_date) = until {
            println!("  Until: {}", until_date.format("%Y-%m-%d"));
        }

        println!();

        let mut completions = Vec::new();
        let mut commits_scanned = 0;
        let mut commits_with_tasks = 0;

        // Compile regex patterns for task ID extraction
        let patterns = TaskPatterns::new()?;

        for oid in revwalk {
            let oid = oid?;
            let commit = self.repo.find_commit(oid)?;

            commits_scanned += 1;

            // Filter by date range
            let commit_time = convert_git_time_to_datetime(commit.time());

            if let Some(since) = since {
                if commit_time < since {
                    break; // Commits are chronological, stop here
                }
            }

            if let Some(until) = until {
                if commit_time > until {
                    continue;
                }
            }

            // Parse commit message for task IDs
            let message = commit.message().unwrap_or("");
            let task_ids = patterns.extract_task_ids(message);

            if !task_ids.is_empty() {
                commits_with_tasks += 1;

                for task_id in task_ids {
                    println!(
                        "✓ Found commit {}: Task #{}",
                        &commit.id().to_string()[..7],
                        task_id
                    );
                    println!("  Author: {}", commit.author().name().unwrap_or("Unknown"));
                    println!("  Date: {}", commit_time.format("%Y-%m-%d %H:%M:%S"));
                    println!("  Message: {}", message.lines().next().unwrap_or(""));
                    println!();

                    completions.push(CompletionDoc {
                        task_id,
                        agent_id: parse_agent_from_author(&commit),
                        completed_at: commit_time,
                        file_path: std::path::PathBuf::from(format!("git:{}", commit.id())),
                        git_commit_hash: Some(commit.id().to_string()),
                    });
                }
            }
        }

        println!("Summary:");
        println!("  Commits scanned: {}", commits_scanned);
        println!("  Commits with tasks: {}", commits_with_tasks);
        println!("  Tasks found: {}", completions.len());

        Ok(completions)
    }
}

/// Supported commit message patterns
struct TaskPatterns {
    patterns: Vec<Regex>,
}

impl TaskPatterns {
    fn new() -> Result<Self> {
        let patterns = vec![
            // TASK-XXX format
            Regex::new(r"TASK-(\d+)")?,
            // Task #XXX or task #XXX
            Regex::new(r"(?i)[Tt]ask\s*#(\d+)")?,
            // Complete XXX, Finish XXX, Done XXX
            Regex::new(r"(?i)(?:Complete|Finish|Done)(?:d|s)?:?\s*(?:task\s*)?#?(\d+)")?,
            // Closes #XXX, Fixes #XXX
            Regex::new(r"(?i)(?:Close|Fix)(?:es|ed)?:?\s*#?(\d+)")?,
            // [XXX] at start
            Regex::new(r"^\[(\d+)\]")?,
        ];

        Ok(Self { patterns })
    }

    fn extract_task_ids(&self, message: &str) -> Vec<i32> {
        let mut task_ids = Vec::new();

        for pattern in &self.patterns {
            for cap in pattern.captures_iter(message) {
                if let Some(matched) = cap.get(1) {
                    if let Ok(task_id) = matched.as_str().parse::<i32>() {
                        if !task_ids.contains(&task_id) {
                            task_ids.push(task_id);
                        }
                    }
                }
            }
        }

        task_ids
    }
}

/// Convert git Time to DateTime<Utc>
fn convert_git_time_to_datetime(time: Time) -> DateTime<Utc> {
    Utc.timestamp_opt(time.seconds(), 0)
        .single()
        .unwrap_or_else(Utc::now)
}

/// Parse agent ID from commit author
///
/// Attempts to extract agent ID from author email or name.
/// Example patterns:
///   - agent-a12@example.com -> A12
///   - a15-bot@example.com -> A15
///   - Agent A10 <user@example.com> -> A10
fn parse_agent_from_author(commit: &Commit) -> Option<String> {
    let author = commit.author();
    let email = author.email().unwrap_or("").to_string();
    let name = author.name().unwrap_or("").to_string();

    // Try email first
    if let Ok(re) = Regex::new(r"(?i)agent[_-]?(a\d+)") {
        if let Some(cap) = re.captures(&email) {
            return Some(cap[1].to_uppercase());
        }
        if let Some(cap) = re.captures(&name) {
            return Some(cap[1].to_uppercase());
        }
    }

    // Try standalone A## pattern
    if let Ok(re) = Regex::new(r"(?i)\b(a\d+)\b") {
        if let Some(cap) = re.captures(&name) {
            return Some(cap[1].to_uppercase());
        }
        if let Some(cap) = re.captures(&email) {
            return Some(cap[1].to_uppercase());
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_task_pattern_extraction() {
        let patterns = TaskPatterns::new().unwrap();

        assert_eq!(patterns.extract_task_ids("TASK-033: Add feature"), vec![33]);
        assert_eq!(patterns.extract_task_ids("Complete task #50"), vec![50]);
        assert_eq!(
            patterns.extract_task_ids("Finish #42 and TASK-43"),
            vec![42, 43]
        );
        assert_eq!(patterns.extract_task_ids("Closes #100"), vec![100]);
        assert_eq!(patterns.extract_task_ids("[57] Fix bug"), vec![57]);
        assert_eq!(
            patterns.extract_task_ids("No tasks here"),
            Vec::<i32>::new()
        );
    }

    #[test]
    fn test_task_pattern_case_insensitive() {
        let patterns = TaskPatterns::new().unwrap();

        assert_eq!(patterns.extract_task_ids("task #50"), vec![50]);
        assert_eq!(patterns.extract_task_ids("TASK #50"), vec![50]);
        assert_eq!(patterns.extract_task_ids("complete #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("COMPLETE #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("fixes #10"), vec![10]);
        assert_eq!(patterns.extract_task_ids("FIXES #10"), vec![10]);
    }

    #[test]
    fn test_task_pattern_multiple() {
        let patterns = TaskPatterns::new().unwrap();

        assert_eq!(
            patterns.extract_task_ids("TASK-033 and TASK-034"),
            vec![33, 34]
        );
        assert_eq!(
            patterns.extract_task_ids("Complete task #50 and #51"),
            vec![50, 51]
        );
    }

    #[test]
    fn test_task_pattern_variations() {
        let patterns = TaskPatterns::new().unwrap();

        assert_eq!(patterns.extract_task_ids("Completed #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("Finishes #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("Finished #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("Done: #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("Closed #42"), vec![42]);
        assert_eq!(patterns.extract_task_ids("Fixed #42"), vec![42]);
    }

    #[test]
    fn test_task_pattern_no_duplicates() {
        let patterns = TaskPatterns::new().unwrap();

        // Same task mentioned multiple times should only appear once
        assert_eq!(
            patterns.extract_task_ids("TASK-033: Complete task #33"),
            vec![33]
        );
    }
}
