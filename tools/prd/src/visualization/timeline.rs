use crate::db::{Database, Sprint, Task, TaskStatus};
use anyhow::Result;
use chrono::{Datelike, Duration, NaiveDate, Utc};
use colored::Colorize;
use std::collections::HashMap;

pub struct TimelineRenderer {
    db: Database,
}

impl TimelineRenderer {
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    pub fn render(&self) -> Result<String> {
        let mut output = String::new();

        output.push_str(&format!(
            "{}\n\n",
            "Project Progress Timeline".bold().cyan()
        ));

        // Get or infer sprints
        let sprints = self.get_or_infer_sprints()?;

        if sprints.is_empty() {
            output.push_str("No sprint data available\n");
            output.push_str("Tasks haven't been organized into sprints yet.\n\n");
            return Ok(output);
        }

        // Render each sprint
        for sprint_info in &sprints {
            output.push_str(&self.render_sprint(sprint_info)?);
        }

        // Overall velocity
        output.push_str(&self.render_velocity(&sprints)?);

        // Burndown chart
        output.push_str(&self.render_burndown()?);

        Ok(output)
    }

    fn render_sprint(&self, sprint_info: &SprintInfo) -> Result<String> {
        let mut output = String::new();

        let status = if sprint_info.is_complete {
            "Complete ✓".green()
        } else if sprint_info.is_current {
            "In Progress ⋯".yellow()
        } else {
            "Future".dimmed()
        };

        output.push_str(&format!(
            "Sprint {} ({} - {}) {}\n",
            sprint_info.number.to_string().bold(),
            sprint_info.start_date,
            sprint_info.end_date,
            status
        ));

        // Progress bar
        let percent = if sprint_info.total_tasks > 0 {
            (sprint_info.completed_tasks * 100) / sprint_info.total_tasks
        } else {
            0
        };

        let bar_width = 40;
        let filled = (percent as usize * bar_width / 100).min(bar_width);
        let empty = bar_width - filled;

        output.push_str("┌─────────────────────────────────────────────┐\n");
        output.push_str(&format!(
            "│ {}{} {}/{} tasks │ {}%\n",
            "█".repeat(filled).green(),
            "░".repeat(empty).dimmed(),
            sprint_info.completed_tasks,
            sprint_info.total_tasks,
            percent
        ));

        // Agent breakdown
        if !sprint_info.agent_tasks.is_empty() {
            output.push_str("├─────────────────────────────────────────────┤\n");
            for (agent_id, count) in &sprint_info.agent_tasks {
                let bar_len = (*count as usize * 2).min(20);
                output.push_str(&format!(
                    "│ {:8} {} {} tasks\n",
                    agent_id.cyan(),
                    "█".repeat(bar_len).blue(),
                    count
                ));
            }
        }

        output.push_str("└─────────────────────────────────────────────┘\n\n");

        Ok(output)
    }

    fn render_velocity(&self, sprints: &[SprintInfo]) -> Result<String> {
        let mut output = String::new();

        output.push_str(&format!("{}\n", "━".repeat(47).dimmed()));
        output.push_str(&format!("{}\n", "Velocity Metrics".bold().yellow()));
        output.push_str(&format!("{}\n", "━".repeat(47).dimmed()));

        let completed_sprints: Vec<_> = sprints.iter().filter(|s| s.is_complete).collect();

        if completed_sprints.is_empty() {
            output.push_str("No completed sprints yet\n\n");
            return Ok(output);
        }

        let total_tasks: i32 = completed_sprints.iter().map(|s| s.completed_tasks).sum();

        let avg_velocity = total_tasks as f64 / completed_sprints.len() as f64;

        output.push_str(&format!(
            "Average velocity: {:.1} tasks/sprint\n",
            avg_velocity.to_string().green().bold()
        ));

        // Trend
        if completed_sprints.len() >= 2 {
            let recent = completed_sprints[completed_sprints.len() - 1].completed_tasks;
            let previous = completed_sprints[completed_sprints.len() - 2].completed_tasks;

            let trend = if recent > previous {
                format!("↑ Accelerating (+{} tasks)", recent - previous).green()
            } else if recent < previous {
                format!("↓ Slowing ({} tasks)", previous - recent).red()
            } else {
                "→ Stable".yellow()
            };

            output.push_str(&format!("Trend: {}\n", trend));
        }

        // Estimate completion
        let all_tasks = self.db.get_all_tasks()?;
        let completed_count = all_tasks
            .iter()
            .filter(|t| t.status == TaskStatus::Completed)
            .count();
        let remaining = all_tasks.len() - completed_count;

        if remaining > 0 && avg_velocity > 0.0 {
            let remaining_sprints = (remaining as f64 / avg_velocity).ceil();
            let completion_date = Utc::now() + Duration::weeks((remaining_sprints * 2.0) as i64);

            output.push_str(&format!(
                "Estimated completion: {} ({:.0} sprints, ~{})\n",
                completion_date.format("%Y-%m-%d").to_string().cyan(),
                remaining_sprints,
                completion_date.format("%b %d, %Y")
            ));
        }

        output.push('\n');

        Ok(output)
    }

    fn render_burndown(&self) -> Result<String> {
        let mut output = String::new();

        output.push_str(&format!("{}\n", "━".repeat(47).dimmed()));
        output.push_str(&format!("{}\n", "Burndown Chart".bold().yellow()));
        output.push_str(&format!("{}\n", "━".repeat(47).dimmed()));

        let snapshots = self.get_daily_snapshots()?;
        if snapshots.len() < 2 {
            output.push_str("Not enough data for burndown chart\n");
            output.push_str("(Need at least 2 days of task completion history)\n\n");
            return Ok(output);
        }

        let max_tasks = snapshots.first().map(|s| s.remaining_tasks).unwrap_or(0);
        let height = 10;
        let width = 50.min(snapshots.len());

        // Render chart
        for y in (0..=height).rev() {
            let threshold = (y as f64 / height as f64) * max_tasks as f64;
            output.push_str(&format!("{:3}│", threshold as usize));

            for i in 0..width {
                let idx = (i as f64 / width as f64 * snapshots.len() as f64) as usize;
                let snapshot = &snapshots[idx.min(snapshots.len() - 1)];

                let char = if snapshot.remaining_tasks as f64 <= threshold + 1.0 {
                    "●"
                } else {
                    " "
                };
                output.push_str(char);
            }

            // Legend
            if y == height {
                output.push_str("  Actual ●");
            } else if y == height / 2 {
                output.push_str("  Ideal ⋯");
            }

            output.push('\n');
        }

        output.push_str(&format!("   └{}\n", "─".repeat(width)));

        let first_date = snapshots.first().map(|s| &s.date).unwrap();
        let last_date = snapshots.last().map(|s| &s.date).unwrap();

        output.push_str(&format!(
            "    {}{}  {}\n\n",
            first_date,
            " ".repeat(width.saturating_sub(first_date.len() + last_date.len())),
            last_date
        ));

        Ok(output)
    }

    fn get_or_infer_sprints(&self) -> Result<Vec<SprintInfo>> {
        // Try database first
        if let Ok(sprints) = self.db.get_all_sprints() {
            if !sprints.is_empty() {
                return self.sprints_with_info(sprints);
            }
        }

        // Infer from task completion dates
        self.infer_sprints_from_tasks()
    }

    fn sprints_with_info(&self, sprints: Vec<Sprint>) -> Result<Vec<SprintInfo>> {
        let mut sprint_infos = Vec::new();

        for sprint in sprints {
            let tasks = self.db.get_sprint_tasks(sprint.id)?;

            let completed_tasks = tasks
                .iter()
                .filter(|t| t.status == TaskStatus::Completed)
                .count() as i32;
            let total_tasks = tasks.len() as i32;

            // Agent breakdown
            let mut agent_tasks: HashMap<String, i32> = HashMap::new();
            for task in &tasks {
                if let Some(agent_id) = &task.assigned_agent {
                    // Get agent display ID
                    if let Ok(Some(agent)) = self.db.get_agent(agent_id) {
                        let display = agent
                            .display_id
                            .map(|id| format!("A{}", id))
                            .unwrap_or_else(|| agent_id[..6].to_string());
                        *agent_tasks.entry(display).or_insert(0) += 1;
                    }
                }
            }

            let now = Utc::now().format("%Y-%m-%d").to_string();
            let is_complete = sprint.end_date < now;
            let is_current = sprint.start_date <= now && sprint.end_date >= now;

            sprint_infos.push(SprintInfo {
                number: sprint.number,
                start_date: sprint.start_date,
                end_date: sprint.end_date,
                completed_tasks,
                total_tasks,
                agent_tasks: agent_tasks.into_iter().collect(),
                is_complete,
                is_current,
            });
        }

        Ok(sprint_infos)
    }

    fn infer_sprints_from_tasks(&self) -> Result<Vec<SprintInfo>> {
        let tasks = self.db.get_all_tasks()?;

        // Group by week
        let mut weeks: HashMap<String, Vec<Task>> = HashMap::new();

        for task in tasks {
            if task.status == TaskStatus::Completed {
                if let Some(completed_at) = task.completed_at {
                    let date = completed_at.date_naive();
                    let week_start =
                        date - Duration::days(date.weekday().num_days_from_monday() as i64);
                    let week_key = week_start.format("%Y-%m-%d").to_string();
                    weeks.entry(week_key).or_insert_with(Vec::new).push(task);
                }
            }
        }

        if weeks.is_empty() {
            return Ok(Vec::new());
        }

        // Convert to sprint infos
        let mut sprint_infos: Vec<SprintInfo> = weeks
            .into_iter()
            .enumerate()
            .map(|(i, (start, tasks))| {
                let start_date = NaiveDate::parse_from_str(&start, "%Y-%m-%d").unwrap();
                let end_date = start_date + Duration::days(6);

                let completed = tasks
                    .iter()
                    .filter(|t| t.status == TaskStatus::Completed)
                    .count() as i32;

                let mut agent_tasks: HashMap<String, i32> = HashMap::new();
                for task in &tasks {
                    if let Some(agent_id) = &task.assigned_agent {
                        if let Ok(Some(agent)) = self.db.get_agent(agent_id) {
                            let display = agent
                                .display_id
                                .map(|id| format!("A{}", id))
                                .unwrap_or_else(|| agent_id[..6].to_string());
                            *agent_tasks.entry(display).or_insert(0) += 1;
                        }
                    }
                }

                let now = Utc::now().date_naive();
                let is_complete = end_date < now;
                let is_current = start_date <= now && end_date >= now;

                SprintInfo {
                    number: (i + 1) as i32,
                    start_date: start,
                    end_date: end_date.format("%Y-%m-%d").to_string(),
                    completed_tasks: completed,
                    total_tasks: tasks.len() as i32,
                    agent_tasks: agent_tasks.into_iter().collect(),
                    is_complete,
                    is_current,
                }
            })
            .collect();

        sprint_infos.sort_by_key(|s| s.number);

        Ok(sprint_infos)
    }

    fn get_daily_snapshots(&self) -> Result<Vec<ProgressSnapshot>> {
        let tasks = self.db.get_all_tasks()?;

        let mut date_map: HashMap<String, usize> = HashMap::new();

        // Count completed tasks per day
        for task in &tasks {
            if task.status == TaskStatus::Completed {
                if let Some(completed_at) = task.completed_at {
                    let date = completed_at.date_naive();
                    let date_str = date.format("%Y-%m-%d").to_string();
                    *date_map.entry(date_str).or_insert(0) += 1;
                }
            }
        }

        if date_map.is_empty() {
            return Ok(vec![]);
        }

        // Calculate remaining per day
        let mut dates: Vec<String> = date_map.keys().cloned().collect();
        dates.sort();

        let total_tasks = tasks.len();
        let mut cumulative_completed = 0;
        let mut snapshots = Vec::new();

        // Add initial snapshot (all tasks remaining)
        if let Some(first_date) = dates.first() {
            let first_date_obj = NaiveDate::parse_from_str(first_date, "%Y-%m-%d").unwrap();
            let day_before = first_date_obj - Duration::days(1);
            snapshots.push(ProgressSnapshot {
                date: day_before.format("%Y-%m-%d").to_string(),
                remaining_tasks: total_tasks,
            });
        }

        for date in dates {
            cumulative_completed += date_map[&date];
            snapshots.push(ProgressSnapshot {
                date: date.clone(),
                remaining_tasks: total_tasks - cumulative_completed,
            });
        }

        Ok(snapshots)
    }
}

#[derive(Debug)]
struct SprintInfo {
    number: i32,
    start_date: String,
    end_date: String,
    completed_tasks: i32,
    total_tasks: i32,
    agent_tasks: Vec<(String, i32)>,
    is_complete: bool,
    is_current: bool,
}

#[derive(Debug)]
struct ProgressSnapshot {
    date: String,
    remaining_tasks: usize,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Priority;

    #[test]
    fn test_timeline_renderer_empty() -> Result<()> {
        let db = Database::new(":memory:")?;
        let renderer = TimelineRenderer::new(db);
        let output = renderer.render()?;
        assert!(output.contains("No sprint data available"));
        Ok(())
    }

    #[test]
    fn test_sprint_inference() -> Result<()> {
        let db = Database::new(":memory:")?;

        // Create some tasks with completion dates
        let agent = db.create_agent("test-agent".to_string())?;
        let task1 = db.create_task("Task 1".to_string(), None, Priority::Medium, None, None)?;

        // Mark as completed
        db.update_task_status(&task1.id, TaskStatus::Completed, Some(&agent.id))?;

        let renderer = TimelineRenderer::new(db);
        let sprints = renderer.infer_sprints_from_tasks()?;

        assert!(!sprints.is_empty());
        Ok(())
    }

    #[test]
    fn test_burndown_chart() -> Result<()> {
        let db = Database::new(":memory:")?;
        let agent = db.create_agent("test-agent".to_string())?;

        // Create and complete several tasks
        for i in 1..=5 {
            let task = db.create_task(format!("Task {}", i), None, Priority::Medium, None, None)?;
            db.update_task_status(&task.id, TaskStatus::Completed, Some(&agent.id))?;
        }

        let renderer = TimelineRenderer::new(db);
        let output = renderer.render_burndown()?;
        assert!(output.contains("Burndown Chart"));
        Ok(())
    }
}
