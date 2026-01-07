use anyhow::Result;
use chrono::{DateTime, Utc};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskDependency {
    pub id: i32,
    pub task_display_id: i32,
    pub depends_on_display_id: i32,
    pub dependency_type: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AcceptanceCriterion {
    pub id: i32,
    pub task_display_id: i32,
    pub criterion: String,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
}

pub trait DependencyOps {
    fn add_dependency(&self, task_id: i32, depends_on_id: i32, dep_type: &str) -> Result<()>;
    fn get_dependencies(&self, task_id: i32) -> Result<Vec<i32>>;
    fn get_blocking_tasks(&self, task_id: i32) -> Result<Vec<i32>>;
    fn check_circular_dependency(&self, task_id: i32, depends_on_id: i32) -> Result<bool>;
    fn get_ready_tasks(&self) -> Result<Vec<i32>>;
}

pub trait AcceptanceCriteriaOps {
    fn add_criterion(&self, task_id: i32, criterion: String) -> Result<i32>;
    fn list_criteria(&self, task_id: i32) -> Result<Vec<AcceptanceCriterion>>;
    fn check_criterion(&self, criterion_id: i32) -> Result<()>;
    fn uncheck_criterion(&self, criterion_id: i32) -> Result<()>;
    fn all_criteria_met(&self, task_id: i32) -> Result<bool>;
}

impl DependencyOps for Connection {
    fn add_dependency(&self, task_id: i32, depends_on_id: i32, dep_type: &str) -> Result<()> {
        // Check for circular dependencies
        if self.check_circular_dependency(task_id, depends_on_id)? {
            return Err(anyhow::anyhow!("Circular dependency detected!"));
        }

        self.execute(
            "INSERT OR IGNORE INTO task_dependencies (task_display_id, depends_on_display_id, dependency_type, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            params![task_id, depends_on_id, dep_type, Utc::now().to_rfc3339()],
        )?;
        Ok(())
    }

    fn get_dependencies(&self, task_id: i32) -> Result<Vec<i32>> {
        let mut stmt = self.prepare(
            "SELECT depends_on_display_id FROM task_dependencies WHERE task_display_id = ?1",
        )?;
        let deps = stmt
            .query_map([task_id], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(deps)
    }

    fn get_blocking_tasks(&self, task_id: i32) -> Result<Vec<i32>> {
        let mut stmt = self.prepare(
            "SELECT task_display_id FROM task_dependencies WHERE depends_on_display_id = ?1",
        )?;
        let blocking = stmt
            .query_map([task_id], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(blocking)
    }

    fn check_circular_dependency(&self, task_id: i32, depends_on_id: i32) -> Result<bool> {
        // Simple BFS to detect cycles
        let mut visited = std::collections::HashSet::new();
        let mut queue = std::collections::VecDeque::new();
        queue.push_back(depends_on_id);

        while let Some(current) = queue.pop_front() {
            if current == task_id {
                return Ok(true); // Cycle detected
            }

            if visited.contains(&current) {
                continue;
            }
            visited.insert(current);

            let deps = self.get_dependencies(current)?;
            for dep in deps {
                queue.push_back(dep);
            }
        }

        Ok(false)
    }

    fn get_ready_tasks(&self) -> Result<Vec<i32>> {
        // Tasks with all dependencies completed or no dependencies
        let mut stmt = self.prepare(
            "SELECT t.display_id FROM tasks t
             WHERE t.status != 'completed' AND t.status != 'cancelled'
             AND NOT EXISTS (
                 SELECT 1 FROM task_dependencies td
                 JOIN tasks dep ON dep.display_id = td.depends_on_display_id
                 WHERE td.task_display_id = t.display_id
                 AND dep.status != 'completed'
             )
             ORDER BY t.priority DESC, t.created_at ASC",
        )?;

        let ready = stmt
            .query_map([], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(ready)
    }
}

impl AcceptanceCriteriaOps for Connection {
    fn add_criterion(&self, task_id: i32, criterion: String) -> Result<i32> {
        self.execute(
            "INSERT INTO acceptance_criteria (task_display_id, criterion, completed, created_at)
             VALUES (?1, ?2, 0, ?3)",
            params![task_id, criterion, Utc::now().to_rfc3339()],
        )?;
        Ok(self.last_insert_rowid() as i32)
    }

    fn list_criteria(&self, task_id: i32) -> Result<Vec<AcceptanceCriterion>> {
        let mut stmt = self.prepare(
            "SELECT id, task_display_id, criterion, completed, created_at, completed_at
             FROM acceptance_criteria WHERE task_display_id = ?1 ORDER BY id ASC",
        )?;

        let criteria = stmt
            .query_map([task_id], |row| {
                Ok(AcceptanceCriterion {
                    id: row.get(0)?,
                    task_display_id: row.get(1)?,
                    criterion: row.get(2)?,
                    completed: row.get(3)?,
                    created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(4)?)
                        .unwrap()
                        .with_timezone(&Utc),
                    completed_at: row.get::<_, Option<String>>(5)?.map(|s| {
                        DateTime::parse_from_rfc3339(&s)
                            .unwrap()
                            .with_timezone(&Utc)
                    }),
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(criteria)
    }

    fn check_criterion(&self, criterion_id: i32) -> Result<()> {
        self.execute(
            "UPDATE acceptance_criteria SET completed = 1, completed_at = ?1 WHERE id = ?2",
            params![Utc::now().to_rfc3339(), criterion_id],
        )?;
        Ok(())
    }

    fn uncheck_criterion(&self, criterion_id: i32) -> Result<()> {
        self.execute(
            "UPDATE acceptance_criteria SET completed = 0, completed_at = NULL WHERE id = ?1",
            params![criterion_id],
        )?;
        Ok(())
    }

    fn all_criteria_met(&self, task_id: i32) -> Result<bool> {
        let count: i32 = self.query_row(
            "SELECT COUNT(*) FROM acceptance_criteria
             WHERE task_display_id = ?1 AND completed = 0",
            [task_id],
            |row| row.get(0),
        )?;
        Ok(count == 0)
    }
}
