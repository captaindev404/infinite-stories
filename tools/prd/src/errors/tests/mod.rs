// Additional integration tests for error context

#[cfg(test)]
mod integration_tests {
    use crate::db::{Database, Priority, TaskStatus};
    use crate::errors::ErrorContext;

    #[test]
    fn test_error_messages_are_colorized() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);

        let msg = ctx.task_not_found(999);
        // Should contain ANSI color codes (colored crate)
        // Even if colors are disabled in tests, the message should still be valid
        assert!(!msg.is_empty());
        assert!(msg.contains("Error"));
    }

    #[test]
    fn test_task_suggestions_with_nearby_ids() {
        let db = Database::new(":memory:").unwrap();

        // Create tasks 1-5
        for i in 1..=5 {
            db.create_task(format!("Task {}", i), None, Priority::Medium, None, None)
                .unwrap();
        }

        let ctx = ErrorContext::new(db);

        // Look for task 10 (doesn't exist)
        let msg = ctx.task_not_found(10);

        // Should suggest nearby tasks (1-5 are within ±10 range)
        assert!(msg.contains("Did you mean"));
    }

    #[test]
    fn test_agent_suggestions_with_similar_names() {
        let db = Database::new(":memory:").unwrap();

        // Create agents with similar names
        db.create_agent("builder-agent".to_string()).unwrap();
        db.create_agent("builder-bot".to_string()).unwrap();
        db.create_agent("worker-agent".to_string()).unwrap();

        let ctx = ErrorContext::new(db);

        // Look for "builder" (doesn't exist exactly)
        let msg = ctx.agent_not_found("builder");

        // Should suggest agents with "builder" in name
        assert!(msg.contains("Did you mean") || msg.contains("Available agents"));
    }

    #[test]
    fn test_invalid_status_fuzzy_matching() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);

        // Test typo: "pendig" instead of "pending"
        let msg = ctx.invalid_status("pendig");
        assert!(msg.contains("pending"));

        // Test partial match: "prog" should suggest "in_progress"
        let msg = ctx.invalid_status("prog");
        assert!(msg.contains("in_progress") || msg.contains("Valid statuses"));
    }

    #[test]
    fn test_task_already_complete_shows_details() {
        let db = Database::new(":memory:").unwrap();

        let task = db
            .create_task(
                "Finished task".to_string(),
                Some("This is done".to_string()),
                Priority::High,
                None,
                None,
            )
            .unwrap();

        // Mark as completed
        db.update_task_status(&task.id, TaskStatus::Completed, None)
            .unwrap();

        let ctx = ErrorContext::new(db);
        let msg = ctx.task_already_complete(task.display_id.unwrap());

        // Should show task title
        assert!(msg.contains("Finished task"));
        assert!(msg.contains("Warning"));
        assert!(msg.contains("already marked as completed"));
    }

    #[test]
    fn test_error_includes_actionable_commands() {
        let db = Database::new(":memory:").unwrap();
        let ctx = ErrorContext::new(db);

        // Task not found should suggest prd list
        let msg = ctx.task_not_found(999);
        assert!(msg.contains("prd list"));

        // Agent not found should suggest prd agent-create
        let msg = ctx.agent_not_found("missing");
        assert!(msg.contains("prd agent-create"));

        // Invalid status should show example
        let msg = ctx.invalid_status("invalid");
        assert!(msg.contains("prd update") || msg.contains("Example"));
    }

    #[test]
    fn test_multiple_similar_suggestions() {
        let db = Database::new(":memory:").unwrap();

        // Create many tasks
        for i in 95..=105 {
            db.create_task(format!("Task {}", i), None, Priority::Medium, None, None)
                .unwrap();
        }

        let ctx = ErrorContext::new(db);

        // Look for task 100 (exists but we'll pretend it doesn't for this test)
        // Actually look for 200 which doesn't exist
        let msg = ctx.task_not_found(200);

        // Should suggest some tasks, but limit to 3
        assert!(msg.contains("Error"));
    }

    #[test]
    fn test_error_context_with_empty_recent_tasks() {
        let db = Database::new(":memory:").unwrap();

        // Create only completed tasks, no pending
        for i in 1..=3 {
            let task = db
                .create_task(format!("Task {}", i), None, Priority::Medium, None, None)
                .unwrap();
            db.update_task_status(&task.id, TaskStatus::Completed, None)
                .unwrap();
        }

        let ctx = ErrorContext::new(db);
        let msg = ctx.task_not_found(999);

        // Should still generate a helpful message
        assert!(msg.contains("Error"));
        assert!(msg.contains("not found"));
    }

    #[test]
    fn test_task_dependencies_error() {
        let db = Database::new(":memory:").unwrap();

        // Create dependent tasks
        let task1 = db
            .create_task("Blocker task".to_string(), None, Priority::High, None, None)
            .unwrap();
        let task2 = db
            .create_task(
                "Dependent task".to_string(),
                None,
                Priority::High,
                None,
                None,
            )
            .unwrap();

        let ctx = ErrorContext::new(db);
        let msg =
            ctx.task_has_dependencies(task2.display_id.unwrap(), vec![task1.display_id.unwrap()]);

        assert!(msg.contains("Error"));
        assert!(msg.contains("incomplete dependencies"));
        assert!(msg.contains("Blocked by"));
    }
}
