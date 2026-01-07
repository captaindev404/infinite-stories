#[cfg(test)]
mod tests {
    use crate::batch::complete::{
        complete_batch, parse_cli_args, parse_csv_file, parse_json_file, CompletionRecord,
    };
    use crate::db::{Database, Priority, TaskStatus};
    use chrono::Utc;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_parse_cli_args() {
        let tasks = "33,34,35";
        let agent_map = "33:A11,34:A11,35:A12";

        let records = parse_cli_args(tasks, agent_map).unwrap();

        assert_eq!(records.len(), 3);
        assert_eq!(records[0].task, "33");
        assert_eq!(records[0].agent, "A11");
        assert_eq!(records[1].task, "34");
        assert_eq!(records[1].agent, "A11");
        assert_eq!(records[2].task, "35");
        assert_eq!(records[2].agent, "A12");
    }

    #[test]
    fn test_parse_cli_args_with_spaces() {
        let tasks = " 33 , 34 , 35 ";
        let agent_map = " 33:A11 , 34:A11 , 35:A12 ";

        let records = parse_cli_args(tasks, agent_map).unwrap();

        assert_eq!(records.len(), 3);
        assert_eq!(records[0].task, "33");
        assert_eq!(records[0].agent, "A11");
    }

    #[test]
    fn test_parse_cli_args_missing_agent() {
        let tasks = "33,34,35";
        let agent_map = "33:A11,34:A11"; // Missing mapping for 35

        let result = parse_cli_args(tasks, agent_map);
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("No agent specified"));
    }

    #[test]
    fn test_parse_cli_args_invalid_format() {
        let tasks = "33,34";
        let agent_map = "33=A11,34=A11"; // Wrong delimiter

        let result = parse_cli_args(tasks, agent_map);
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_json_file() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let json_content = r#"[
            {
                "task": "33",
                "agent": "A11",
                "timestamp": "2025-10-13T10:30:00Z"
            },
            {
                "task": "34",
                "agent": "A11"
            }
        ]"#;

        temp_file.write_all(json_content.as_bytes()).unwrap();
        temp_file.flush().unwrap();

        let records = parse_json_file(temp_file.path()).unwrap();

        assert_eq!(records.len(), 2);
        assert_eq!(records[0].task, "33");
        assert_eq!(records[0].agent, "A11");
        assert_eq!(records[1].task, "34");
    }

    #[test]
    fn test_parse_json_file_empty() {
        let mut temp_file = NamedTempFile::new().unwrap();
        temp_file.write_all(b"[]").unwrap();
        temp_file.flush().unwrap();

        let result = parse_json_file(temp_file.path());
        assert!(result.is_err());
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("contains no records"));
    }

    #[test]
    fn test_parse_csv_file() {
        let mut temp_file = NamedTempFile::new().unwrap();
        let csv_content =
            "task,agent,timestamp\n33,A11,2025-10-13T10:30:00Z\n34,A11,2025-10-13T11:00:00Z";

        temp_file.write_all(csv_content.as_bytes()).unwrap();
        temp_file.flush().unwrap();

        let records = parse_csv_file(temp_file.path()).unwrap();

        assert_eq!(records.len(), 2);
        assert_eq!(records[0].task, "33");
        assert_eq!(records[0].agent, "A11");
        assert_eq!(records[1].task, "34");
    }

    #[test]
    fn test_parse_csv_file_empty() {
        let mut temp_file = NamedTempFile::new().unwrap();
        temp_file.write_all(b"task,agent,timestamp\n").unwrap();
        temp_file.flush().unwrap();

        let result = parse_csv_file(temp_file.path());
        assert!(result.is_err());
    }

    #[test]
    fn test_complete_batch_atomicity() {
        let temp_db = NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create test tasks
        let task1 = db
            .create_task("Task 1".to_string(), None, Priority::Medium, None, None)
            .unwrap();
        let task2 = db
            .create_task("Task 2".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        // Create agent
        db.create_agent("TestAgent".to_string()).unwrap();

        // Prepare records (one valid, one invalid)
        let records = vec![
            CompletionRecord {
                task: task1.display_id.unwrap().to_string(),
                agent: "A1".to_string(),
                timestamp: Utc::now(),
            },
            CompletionRecord {
                task: "999".to_string(), // Invalid task
                agent: "A1".to_string(),
                timestamp: Utc::now(),
            },
        ];

        // Run batch (should fail due to validation)
        let result = complete_batch(&db, records);

        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("not found"));

        // Verify NO tasks were completed (atomicity)
        let task1_after = db.get_task(&task1.id).unwrap().unwrap();
        assert_ne!(task1_after.status, TaskStatus::Completed);
    }

    #[test]
    fn test_complete_batch_success() {
        let temp_db = NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create test tasks
        let task1 = db
            .create_task("Task 1".to_string(), None, Priority::Medium, None, None)
            .unwrap();
        let task2 = db
            .create_task("Task 2".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        // Create agent
        let agent = db.create_agent("TestAgent".to_string()).unwrap();

        // Prepare records
        let records = vec![
            CompletionRecord {
                task: task1.display_id.unwrap().to_string(),
                agent: agent.display_id.map(|id| format!("A{}", id)).unwrap(),
                timestamp: Utc::now(),
            },
            CompletionRecord {
                task: task2.display_id.unwrap().to_string(),
                agent: agent.display_id.map(|id| format!("A{}", id)).unwrap(),
                timestamp: Utc::now(),
            },
        ];

        // Run batch
        let result = complete_batch(&db, records).unwrap();

        // Verify success
        assert_eq!(result.completed, 2);
        assert!(result.failed.is_empty());

        // Verify tasks completed
        let task1_after = db.get_task(&task1.id).unwrap().unwrap();
        let task2_after = db.get_task(&task2.id).unwrap().unwrap();
        assert_eq!(task1_after.status, TaskStatus::Completed);
        assert_eq!(task2_after.status, TaskStatus::Completed);
        assert!(task1_after.completed_at.is_some());
        assert!(task2_after.completed_at.is_some());
    }

    #[test]
    fn test_complete_batch_creates_agent_if_needed() {
        let temp_db = NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create test task
        let task1 = db
            .create_task("Task 1".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        // Prepare records with non-existent agent
        let records = vec![CompletionRecord {
            task: task1.display_id.unwrap().to_string(),
            agent: "NewAgent".to_string(),
            timestamp: Utc::now(),
        }];

        // Run batch
        let result = complete_batch(&db, records).unwrap();

        // Verify success
        assert_eq!(result.completed, 1);
        assert!(result.failed.is_empty());

        // Verify agent was created
        let agents = db.list_agents().unwrap();
        assert_eq!(agents.len(), 1);
        assert_eq!(agents[0].name, "NewAgent");
    }

    #[test]
    fn test_complete_batch_performance() {
        let temp_db = NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create 100 tasks
        let mut records = Vec::new();
        for i in 1..=100 {
            let task = db
                .create_task(format!("Task {}", i), None, Priority::Medium, None, None)
                .unwrap();

            records.push(CompletionRecord {
                task: task.display_id.unwrap().to_string(),
                agent: "TestAgent".to_string(),
                timestamp: Utc::now(),
            });
        }

        // Run batch
        let start = std::time::Instant::now();
        let result = complete_batch(&db, records).unwrap();
        let duration = start.elapsed();

        // Verify success
        assert_eq!(result.completed, 100);
        assert!(result.failed.is_empty());

        // Verify performance (should complete in <3 seconds)
        assert!(
            duration.as_secs() < 3,
            "Batch completion took too long: {:?}",
            duration
        );
    }

    #[test]
    fn test_complete_batch_with_hash_ids() {
        let temp_db = NamedTempFile::new().unwrap();
        let db = Database::new(temp_db.path().to_str().unwrap()).unwrap();

        // Create test task
        let task1 = db
            .create_task("Task 1".to_string(), None, Priority::Medium, None, None)
            .unwrap();

        // Prepare records with # prefix
        let records = vec![CompletionRecord {
            task: format!("#{}", task1.display_id.unwrap()),
            agent: "A1".to_string(),
            timestamp: Utc::now(),
        }];

        // Run batch
        let result = complete_batch(&db, records).unwrap();

        // Verify success
        assert_eq!(result.completed, 1);
        assert!(result.failed.is_empty());
    }
}
