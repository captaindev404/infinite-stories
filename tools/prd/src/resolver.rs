use anyhow::{Context, Result};
use rusqlite::Connection;

/// Resolves various ID formats to their full UUID
/// Accepts: #42, 42, uuid-prefix, or full-uuid
pub fn resolve_task_id(conn: &Connection, id_input: &str) -> Result<String> {
    let cleaned = id_input.trim().trim_start_matches('#');

    // Try as display_id first (most common case)
    if let Ok(display_id) = cleaned.parse::<i32>() {
        let uuid: Result<String, _> = conn.query_row(
            "SELECT id FROM tasks WHERE display_id = ?1",
            [display_id],
            |row| row.get(0),
        );

        if let Ok(uuid) = uuid {
            return Ok(uuid);
        }
    }

    // Try as UUID prefix or full UUID
    let uuid_result: Result<Vec<String>, _> = conn
        .prepare("SELECT id FROM tasks WHERE id LIKE ?1 || '%'")?
        .query_map([cleaned], |row| row.get(0))?
        .collect();

    match uuid_result {
        Ok(matches) if matches.len() == 1 => Ok(matches[0].clone()),
        Ok(matches) if matches.len() > 1 => Err(anyhow::anyhow!(
            "Ambiguous ID '{}': matches {} tasks. Please be more specific.",
            id_input,
            matches.len()
        )),
        _ => Err(anyhow::anyhow!("Task not found: {}", id_input)),
    }
}

/// Resolves agent ID formats to their full UUID
/// Accepts: A5, #5, 5, uuid-prefix, or full-uuid
pub fn resolve_agent_id(conn: &Connection, id_input: &str) -> Result<String> {
    let cleaned = id_input
        .trim()
        .trim_start_matches('#')
        .trim_start_matches('A')
        .trim_start_matches('a');

    // Try as display_id first
    if let Ok(display_id) = cleaned.parse::<i32>() {
        let uuid: Result<String, _> = conn.query_row(
            "SELECT id FROM agents WHERE display_id = ?1",
            [display_id],
            |row| row.get(0),
        );

        if let Ok(uuid) = uuid {
            return Ok(uuid);
        }
    }

    // Try as agent name
    let by_name: Result<String, _> = conn.query_row(
        "SELECT id FROM agents WHERE name = ?1",
        [id_input.trim()],
        |row| row.get(0),
    );

    if let Ok(uuid) = by_name {
        return Ok(uuid);
    }

    // Try as UUID prefix
    let uuid_result: Result<Vec<String>, _> = conn
        .prepare("SELECT id FROM agents WHERE id LIKE ?1 || '%'")?
        .query_map([cleaned], |row| row.get(0))?
        .collect();

    match uuid_result {
        Ok(matches) if matches.len() == 1 => Ok(matches[0].clone()),
        Ok(matches) if matches.len() > 1 => Err(anyhow::anyhow!(
            "Ambiguous ID '{}': matches {} agents. Please be more specific.",
            id_input,
            matches.len()
        )),
        _ => Err(anyhow::anyhow!("Agent not found: {}", id_input)),
    }
}

/// Formats a task ID for display (shows display_id instead of UUID)
pub fn format_task_id(conn: &Connection, uuid: &str) -> String {
    let display_id: Result<i32, _> = conn.query_row(
        "SELECT display_id FROM tasks WHERE id = ?1",
        [uuid],
        |row| row.get(0),
    );

    match display_id {
        Ok(id) => format!("#{}", id),
        Err(_) => uuid[..8].to_string(),
    }
}

/// Formats an agent ID for display (shows display_id instead of UUID)
pub fn format_agent_id(conn: &Connection, uuid: &str) -> String {
    let display_id: Result<i32, _> = conn.query_row(
        "SELECT display_id FROM agents WHERE id = ?1",
        [uuid],
        |row| row.get(0),
    );

    match display_id {
        Ok(id) => format!("A{}", id),
        Err(_) => uuid[..8].to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    fn setup_test_db() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(
            "CREATE TABLE tasks (id TEXT PRIMARY KEY, display_id INTEGER, title TEXT);
             CREATE TABLE agents (id TEXT PRIMARY KEY, display_id INTEGER, name TEXT);
             INSERT INTO tasks VALUES ('uuid-task-1', 1, 'Task 1');
             INSERT INTO tasks VALUES ('uuid-task-2', 2, 'Task 2');
             INSERT INTO agents VALUES ('uuid-agent-1', 1, 'test-agent');
             INSERT INTO agents VALUES ('uuid-agent-2', 2, 'other-agent');",
        )
        .unwrap();
        conn
    }

    #[test]
    fn test_resolve_task_by_display_id() {
        let conn = setup_test_db();
        assert_eq!(resolve_task_id(&conn, "1").unwrap(), "uuid-task-1");
        assert_eq!(resolve_task_id(&conn, "#1").unwrap(), "uuid-task-1");
        assert_eq!(resolve_task_id(&conn, "2").unwrap(), "uuid-task-2");
    }

    #[test]
    fn test_resolve_task_by_uuid_prefix() {
        let conn = setup_test_db();
        assert_eq!(
            resolve_task_id(&conn, "uuid-task-1").unwrap(),
            "uuid-task-1"
        );
    }

    #[test]
    fn test_resolve_agent_by_display_id() {
        let conn = setup_test_db();
        assert_eq!(resolve_agent_id(&conn, "1").unwrap(), "uuid-agent-1");
        assert_eq!(resolve_agent_id(&conn, "A1").unwrap(), "uuid-agent-1");
        assert_eq!(resolve_agent_id(&conn, "#1").unwrap(), "uuid-agent-1");
    }

    #[test]
    fn test_resolve_agent_by_name() {
        let conn = setup_test_db();
        assert_eq!(
            resolve_agent_id(&conn, "test-agent").unwrap(),
            "uuid-agent-1"
        );
    }

    #[test]
    fn test_format_ids() {
        let conn = setup_test_db();
        assert_eq!(format_task_id(&conn, "uuid-task-1"), "#1");
        assert_eq!(format_agent_id(&conn, "uuid-agent-2"), "A2");
    }
}
