use crate::db::{Agent, Database, Task};
use anyhow::Result;
use colored::Colorize;

/// Error context builder for creating helpful, actionable error messages
/// with fuzzy matching suggestions and clear next steps.
pub struct ErrorContext {
    db: Database,
}

impl ErrorContext {
    /// Create a new error context with database access
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    /// Generate error message when a task is not found
    /// Includes:
    /// - Similar task IDs (within ±10 range)
    /// - Recent pending tasks
    /// - Helpful command suggestion
    pub fn task_not_found(&self, task_id: i32) -> String {
        let mut msg = format!(
            "{} Task #{} not found in database\n",
            "Error:".red().bold(),
            task_id
        );

        // Add similar tasks
        if let Ok(similar) = self.find_similar_task_ids(task_id, 3) {
            if !similar.is_empty() {
                msg.push_str(&format!("\n{}\n", "Did you mean one of these?".yellow()));
                for task in similar {
                    msg.push_str(&format!(
                        "  {} Task #{}: \"{}\"\n",
                        "•".cyan(),
                        task.display_id.unwrap_or(0),
                        task.title.dimmed()
                    ));
                }
            }
        }

        // Add recent pending tasks
        if let Ok(recent) = self.get_recent_tasks("pending", 3) {
            if !recent.is_empty() {
                msg.push_str(&format!("\n{}\n", "Recent pending tasks:".yellow()));
                for task in recent {
                    msg.push_str(&format!(
                        "  {} Task #{}: \"{}\" ({})\n",
                        "•".cyan(),
                        task.display_id.unwrap_or(0),
                        task.title.dimmed(),
                        task.status.as_str().green()
                    ));
                }
            }
        }

        msg.push_str(&format!(
            "\n{} Use {} to see all tasks\n",
            "Tip:".blue().bold(),
            "prd list".green()
        ));

        msg
    }

    /// Generate error message when an agent is not found
    /// Includes:
    /// - Similar agent names (fuzzy matching)
    /// - List of available agents
    /// - Command to create new agent
    pub fn agent_not_found(&self, agent_id: &str) -> String {
        let mut msg = format!(
            "{} Agent {} not found in database\n",
            "Error:".red().bold(),
            agent_id.cyan()
        );

        // Add similar agents
        if let Ok(similar) = self.find_similar_agent_names(agent_id, 3) {
            if !similar.is_empty() {
                msg.push_str(&format!("\n{}\n", "Did you mean one of these?".yellow()));
                for agent in similar {
                    let agent_display = agent
                        .display_id
                        .map(|id| format!("A{}", id))
                        .unwrap_or_else(|| agent.id[..8].to_string());
                    msg.push_str(&format!(
                        "  {} {} ({})\n",
                        "•".cyan(),
                        agent_display.cyan(),
                        agent.name.dimmed()
                    ));
                }
            }
        }

        // List available agents
        if let Ok(agents) = self.db.list_agents() {
            if !agents.is_empty() && agents.len() <= 5 {
                msg.push_str(&format!("\n{}\n", "Available agents:".yellow()));
                for agent in agents.iter().take(5) {
                    let agent_display = agent
                        .display_id
                        .map(|id| format!("A{}", id))
                        .unwrap_or_else(|| agent.id[..8].to_string());
                    msg.push_str(&format!(
                        "  {} {} ({})\n",
                        "•".cyan(),
                        agent_display.cyan(),
                        agent.name.dimmed()
                    ));
                }
            } else if agents.len() > 5 {
                msg.push_str(&format!(
                    "\n{} {} agents available. Use {} to see all.\n",
                    "Note:".blue(),
                    agents.len(),
                    "prd agent-list".green()
                ));
            }
        }

        msg.push_str(&format!(
            "\n{} Create new agent: {}\n",
            "Tip:".blue().bold(),
            format!("prd agent-create \"{}\"", agent_id).green()
        ));

        msg
    }

    /// Generate warning when a task is already complete
    /// Not an error, just informational
    pub fn task_already_complete(&self, task_id: i32) -> String {
        let mut msg = format!(
            "{} Task #{} is already marked as completed\n",
            "Warning:".yellow().bold(),
            task_id
        );

        // Get task details if available
        if let Ok(task) = self.get_task_by_display_id(task_id) {
            if let Some(task) = task {
                msg.push_str(&format!("\nTask: {}\n", task.title.dimmed()));
                if let Some(completed_at) = task.completed_at {
                    msg.push_str(&format!(
                        "Completed: {}\n",
                        completed_at
                            .format("%Y-%m-%d %H:%M:%S")
                            .to_string()
                            .dimmed()
                    ));
                }
            }
        }

        msg.push_str(&format!(
            "\n{} Use {} to see task details\n",
            "Tip:".blue().bold(),
            format!("prd show {}", task_id).green()
        ));

        msg
    }

    /// Generate error message for invalid status value
    /// Shows valid status options
    pub fn invalid_status(&self, status: &str) -> String {
        let mut msg = format!(
            "{} Invalid status: {}\n",
            "Error:".red().bold(),
            status.yellow()
        );

        // Find similar valid statuses
        let valid_statuses = vec![
            "pending",
            "in_progress",
            "blocked",
            "review",
            "completed",
            "cancelled",
        ];

        let similar: Vec<&str> = valid_statuses
            .iter()
            .filter(|&&s| similarity_score(status, s) > 0.5)
            .copied()
            .collect();

        if !similar.is_empty() {
            msg.push_str(&format!("\n{}\n", "Did you mean:".yellow()));
            for s in similar {
                msg.push_str(&format!("  {} {}\n", "•".cyan(), s.green()));
            }
        }

        msg.push_str(&format!("\n{}\n", "Valid statuses:".yellow()));
        for status in valid_statuses {
            msg.push_str(&format!("  {} {}\n", "•".cyan(), status.green()));
        }

        msg.push_str(&format!(
            "\n{} Example: {}\n",
            "Tip:".blue().bold(),
            "prd update #1 in_progress".green()
        ));

        msg
    }

    /// Generate error message for invalid priority value
    /// Shows valid priority options
    pub fn invalid_priority(&self, priority: &str) -> String {
        let mut msg = format!(
            "{} Invalid priority: {}\n",
            "Error:".red().bold(),
            priority.yellow()
        );

        let valid_priorities = vec!["low", "medium", "high", "critical"];

        let similar: Vec<&str> = valid_priorities
            .iter()
            .filter(|&&p| similarity_score(priority, p) > 0.5)
            .copied()
            .collect();

        if !similar.is_empty() {
            msg.push_str(&format!("\n{}\n", "Did you mean:".yellow()));
            for p in similar {
                msg.push_str(&format!("  {} {}\n", "•".cyan(), p.green()));
            }
        }

        msg.push_str(&format!("\n{}\n", "Valid priorities:".yellow()));
        for priority in valid_priorities {
            msg.push_str(&format!("  {} {}\n", "•".cyan(), priority.green()));
        }

        msg.push_str(&format!(
            "\n{} Example: {}\n",
            "Tip:".blue().bold(),
            "prd create \"Fix bug\" --priority high".green()
        ));

        msg
    }

    /// Generate error message when task has incomplete dependencies
    pub fn task_has_dependencies(&self, task_id: i32, dep_ids: Vec<i32>) -> String {
        let mut msg = format!(
            "{} Task #{} cannot be started - has incomplete dependencies\n",
            "Error:".red().bold(),
            task_id
        );

        msg.push_str(&format!("\n{}\n", "Blocked by:".yellow()));
        for dep_id in &dep_ids {
            if let Ok(task) = self.get_task_by_display_id(*dep_id) {
                if let Some(task) = task {
                    msg.push_str(&format!(
                        "  {} Task #{}: \"{}\" ({})\n",
                        "•".cyan(),
                        dep_id,
                        task.title.dimmed(),
                        task.status.as_str().yellow()
                    ));
                }
            } else {
                msg.push_str(&format!("  {} Task #{}\n", "•".cyan(), dep_id));
            }
        }

        msg.push_str(&format!(
            "\n{} Complete blocking tasks first, or use {} to see ready tasks\n",
            "Tip:".blue().bold(),
            "prd ready".green()
        ));

        msg
    }

    // Helper methods

    /// Find tasks with similar IDs (within ±10 range)
    fn find_similar_task_ids(&self, task_id: i32, limit: usize) -> Result<Vec<Task>> {
        let min = (task_id - 10).max(0);
        let max = task_id + 10;

        let all_tasks = self.db.list_tasks(None)?;
        let mut similar: Vec<Task> = all_tasks
            .into_iter()
            .filter(|t| {
                if let Some(display_id) = t.display_id {
                    display_id >= min && display_id <= max && display_id != task_id
                } else {
                    false
                }
            })
            .collect();

        // Sort by distance from target ID
        similar.sort_by_key(|t| {
            let display_id = t.display_id.unwrap_or(0);
            (display_id - task_id).abs()
        });

        similar.truncate(limit);
        Ok(similar)
    }

    /// Find agents with similar names (fuzzy matching)
    fn find_similar_agent_names(&self, agent_name: &str, limit: usize) -> Result<Vec<Agent>> {
        let all_agents = self.db.list_agents()?;
        let mut similar: Vec<(Agent, f64)> = all_agents
            .into_iter()
            .map(|agent| {
                // Check both name and display ID
                let name_similarity = similarity_score(agent_name, &agent.name);
                let id_similarity = if let Some(display_id) = agent.display_id {
                    let id_str = format!("A{}", display_id);
                    similarity_score(agent_name, &id_str)
                } else {
                    0.0
                };
                let score = name_similarity.max(id_similarity);
                (agent, score)
            })
            .filter(|(_, score)| *score > 0.3)
            .collect();

        similar.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        similar.truncate(limit);

        Ok(similar.into_iter().map(|(agent, _)| agent).collect())
    }

    /// Get recent tasks by status
    fn get_recent_tasks(&self, status: &str, limit: usize) -> Result<Vec<Task>> {
        let status_enum = crate::db::TaskStatus::from_str(status);
        let tasks = self.db.list_tasks(Some(status_enum))?;
        Ok(tasks.into_iter().take(limit).collect())
    }

    /// Get task by display ID
    fn get_task_by_display_id(&self, display_id: i32) -> Result<Option<Task>> {
        let tasks = self.db.list_tasks(None)?;
        Ok(tasks.into_iter().find(|t| t.display_id == Some(display_id)))
    }
}

/// Calculate Levenshtein distance between two strings
/// Used for fuzzy matching in error suggestions
pub fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let len1 = s1.len();
    let len2 = s2.len();
    let mut matrix = vec![vec![0; len2 + 1]; len1 + 1];

    for i in 0..=len1 {
        matrix[i][0] = i;
    }
    for j in 0..=len2 {
        matrix[0][j] = j;
    }

    for (i, c1) in s1.chars().enumerate() {
        for (j, c2) in s2.chars().enumerate() {
            let cost = if c1 == c2 { 0 } else { 1 };
            matrix[i + 1][j + 1] = (matrix[i][j + 1] + 1)
                .min(matrix[i + 1][j] + 1)
                .min(matrix[i][j] + cost);
        }
    }

    matrix[len1][len2]
}

/// Calculate similarity score between two strings (0.0 to 1.0)
/// Uses normalized Levenshtein distance
pub fn similarity_score(s1: &str, s2: &str) -> f64 {
    let s1_lower = s1.to_lowercase();
    let s2_lower = s2.to_lowercase();

    // Check for exact match first
    if s1_lower == s2_lower {
        return 1.0;
    }

    // Check if one string contains the other
    if s1_lower.contains(&s2_lower) || s2_lower.contains(&s1_lower) {
        let shorter_len = s1_lower.len().min(s2_lower.len()) as f64;
        let longer_len = s1_lower.len().max(s2_lower.len()) as f64;
        return shorter_len / longer_len;
    }

    // Use Levenshtein distance
    let distance = levenshtein_distance(&s1_lower, &s2_lower);
    let max_len = s1.len().max(s2.len()) as f64;
    if max_len == 0.0 {
        1.0
    } else {
        1.0 - (distance as f64 / max_len)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_levenshtein_distance() {
        assert_eq!(levenshtein_distance("kitten", "sitting"), 3);
        assert_eq!(levenshtein_distance("A1", "A2"), 1);
        assert_eq!(levenshtein_distance("same", "same"), 0);
        assert_eq!(levenshtein_distance("", "abc"), 3);
        assert_eq!(levenshtein_distance("abc", ""), 3);
    }

    #[test]
    fn test_similarity_score() {
        // Exact match
        assert_eq!(similarity_score("A1", "A1"), 1.0);
        assert_eq!(similarity_score("test", "TEST"), 1.0);

        // Similar strings
        assert!(similarity_score("A1", "A2") >= 0.5); // Changed to >= since 1 edit in 2 chars = exactly 0.5
        assert!(similarity_score("pending", "pendin") > 0.8);

        // Different strings
        assert!(similarity_score("foo", "bar") < 0.5);

        // Substring match
        assert!(similarity_score("test", "testing") > 0.5);
    }

    #[test]
    fn test_error_context_creation() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);
        // Should not panic
    }

    #[test]
    fn test_task_not_found_message() {
        let db = Database::new(":memory:").unwrap();
        // Insert some test tasks
        db.create_task(
            "Test task 1".to_string(),
            None,
            crate::db::Priority::Medium,
            None,
            None,
        )
        .unwrap();

        let ctx = ErrorContext::new(db);
        let msg = ctx.task_not_found(999);

        assert!(msg.contains("Error"));
        assert!(msg.contains("999"));
        assert!(msg.contains("not found"));
        assert!(msg.contains("prd list"));
    }

    #[test]
    fn test_agent_not_found_message() {
        let db = Database::new(":memory:").unwrap();
        // Insert a test agent
        db.create_agent("test-agent".to_string()).unwrap();

        let ctx = ErrorContext::new(db);
        let msg = ctx.agent_not_found("invalid-agent");

        assert!(msg.contains("Error"));
        assert!(msg.contains("invalid-agent"));
        assert!(msg.contains("not found"));
        assert!(msg.contains("prd agent-create"));
    }

    #[test]
    fn test_invalid_status_message() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);
        let msg = ctx.invalid_status("invalid_stat");

        assert!(msg.contains("Error"));
        assert!(msg.contains("Invalid status"));
        assert!(msg.contains("pending"));
        assert!(msg.contains("in_progress"));
        assert!(msg.contains("completed"));
    }

    #[test]
    fn test_invalid_priority_message() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);
        let msg = ctx.invalid_priority("urgent");

        assert!(msg.contains("Error"));
        assert!(msg.contains("Invalid priority"));
        assert!(msg.contains("low"));
        assert!(msg.contains("high"));
        assert!(msg.contains("critical"));
    }

    #[test]
    fn test_task_already_complete_message() {
        let db = Database::new(":memory:").unwrap();
        let task = db
            .create_task(
                "Completed task".to_string(),
                None,
                crate::db::Priority::Medium,
                None,
                None,
            )
            .unwrap();

        // Mark as completed
        db.update_task_status(&task.id, crate::db::TaskStatus::Completed, None)
            .unwrap();

        let ctx = ErrorContext::new(db);
        let msg = ctx.task_already_complete(task.display_id.unwrap());

        assert!(msg.contains("Warning"));
        assert!(msg.contains("already marked as completed"));
    }

    #[test]
    fn test_find_similar_task_ids() {
        let db = Database::new(":memory:").unwrap();

        // Create tasks with known IDs
        for i in 1..=20 {
            db.create_task(
                format!("Task {}", i),
                None,
                crate::db::Priority::Medium,
                None,
                None,
            )
            .unwrap();
        }

        let ctx = ErrorContext::new(db);
        let similar = ctx.find_similar_task_ids(10, 3).unwrap();

        // Should find tasks around ID 10
        assert!(similar.len() <= 3);
        for task in similar {
            let display_id = task.display_id.unwrap();
            assert!(display_id >= 1 && display_id <= 20);
            assert_ne!(display_id, 10); // Should not include the target ID
        }
    }

    #[test]
    fn test_find_similar_agent_names() {
        let db = Database::new(":memory:").unwrap();

        // Create agents with similar names
        db.create_agent("agent-1".to_string()).unwrap();
        db.create_agent("agent-2".to_string()).unwrap();
        db.create_agent("builder-1".to_string()).unwrap();

        let ctx = ErrorContext::new(db);
        let similar = ctx.find_similar_agent_names("agent", 3).unwrap();

        // Should find agents with "agent" in name
        assert!(!similar.is_empty());
        assert!(similar.len() <= 3);
    }

    #[test]
    fn test_empty_database_errors() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);

        // Should handle empty database gracefully
        let msg = ctx.task_not_found(1);
        assert!(msg.contains("Error"));
        assert!(msg.contains("not found"));

        let msg = ctx.agent_not_found("test");
        assert!(msg.contains("Error"));
        assert!(msg.contains("not found"));
    }
}
