use crate::db::{Agent, AgentMetrics, AgentStatus, Database, Task};
use anyhow::Result;
use colored::Colorize;

pub struct AgentMatcher {
    db: Database,
}

#[derive(Debug, Clone)]
pub struct AgentRecommendation {
    pub agent: Agent,
    pub score: f64,
    pub reasons: Vec<String>,
    pub specialization_score: f64,
    pub performance_score: f64,
    pub experience_score: f64,
    pub availability_score: f64,
}

impl AgentMatcher {
    pub fn new(db: Database) -> Self {
        Self { db }
    }

    pub fn suggest_agents(&self, task: &Task, count: usize) -> Result<Vec<AgentRecommendation>> {
        let all_agents = self.db.get_all_agents()?;

        let mut recommendations: Vec<AgentRecommendation> = all_agents
            .into_iter()
            .map(|agent| self.score_agent(&agent, task))
            .collect::<Result<Vec<_>>>()?;

        recommendations.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());

        Ok(recommendations.into_iter().take(count).collect())
    }

    fn score_agent(&self, agent: &Agent, task: &Task) -> Result<AgentRecommendation> {
        let mut reasons = Vec::new();

        // 1. Specialization match (40% weight)
        let spec_score = self.specialization_score(agent, task)?;
        if spec_score > 0.7 {
            reasons.push(format!("Specialization match: {:.0}%", spec_score * 100.0));
        } else if spec_score > 0.3 {
            reasons.push(format!(
                "Partial specialization match: {:.0}%",
                spec_score * 100.0
            ));
        }

        // 2. Past performance (30% weight)
        let perf_score = self.performance_score(agent)?;
        if perf_score > 0.8 {
            reasons.push(format!(
                "Excellent track record: {:.0}% success rate",
                perf_score * 100.0
            ));
        } else if perf_score > 0.5 {
            reasons.push(format!(
                "Good track record: {:.0}% success rate",
                perf_score * 100.0
            ));
        }

        // 3. Similar task experience (20% weight)
        let exp_score = self.experience_score(agent, task)?;
        if exp_score > 0.5 {
            let similar_count = (exp_score * 10.0) as usize;
            reasons.push(format!("Completed {} similar tasks", similar_count));
        }

        // 4. Availability (10% weight)
        let avail_score = self.availability_score(agent);
        match agent.status {
            AgentStatus::Idle => reasons.push("Available immediately".to_string()),
            AgentStatus::Working => {
                if let Some(task_id) = &agent.current_task_id {
                    // Try to get task display ID
                    if let Ok(Some(t)) = self.db.get_task(task_id) {
                        if let Some(display_id) = t.display_id {
                            reasons.push(format!("Currently working on task #{}", display_id));
                        }
                    }
                }
            }
            _ => {}
        }

        let total_score =
            (spec_score * 0.4) + (perf_score * 0.3) + (exp_score * 0.2) + (avail_score * 0.1);

        Ok(AgentRecommendation {
            agent: agent.clone(),
            score: total_score,
            reasons,
            specialization_score: spec_score,
            performance_score: perf_score,
            experience_score: exp_score,
            availability_score: avail_score,
        })
    }

    fn specialization_score(&self, agent: &Agent, task: &Task) -> Result<f64> {
        let agent_specs = self.db.get_agent_specializations(&agent.id)?;
        if agent_specs.is_empty() {
            return Ok(0.3); // Neutral score for agents without specializations
        }

        let task_keywords = self.extract_task_keywords(task);
        if task_keywords.is_empty() {
            return Ok(0.5); // Neutral if task has no clear keywords
        }

        let matches = task_keywords
            .iter()
            .filter(|keyword| {
                agent_specs.iter().any(|spec| {
                    let spec_lower = spec.to_lowercase();
                    let keyword_lower = keyword.to_lowercase();
                    spec_lower.contains(&keyword_lower) || keyword_lower.contains(&spec_lower)
                })
            })
            .count();

        Ok((matches as f64 / task_keywords.len() as f64).min(1.0))
    }

    fn performance_score(&self, agent: &Agent) -> Result<f64> {
        let metrics = self.db.get_agent_metrics(&agent.id)?;

        if metrics.total_tasks == 0 {
            return Ok(0.5); // Neutral score for new agents
        }

        let success_rate = metrics.completed_tasks as f64 / metrics.total_tasks as f64;
        Ok(success_rate)
    }

    fn experience_score(&self, agent: &Agent, task: &Task) -> Result<f64> {
        // Get all tasks completed by this agent
        let agent_tasks: Vec<Task> = self
            .db
            .get_all_tasks()?
            .into_iter()
            .filter(|t| {
                t.assigned_agent.as_deref() == Some(&agent.id)
                    && t.status == crate::db::TaskStatus::Completed
            })
            .collect();

        let task_keywords = self.extract_task_keywords(task);
        if task_keywords.is_empty() {
            return Ok(0.0);
        }

        let similar_count = agent_tasks
            .iter()
            .filter(|t| {
                let t_keywords = self.extract_task_keywords(t);
                t_keywords.iter().any(|k| task_keywords.contains(k))
            })
            .count();

        Ok((similar_count as f64 / 10.0).min(1.0))
    }

    fn availability_score(&self, agent: &Agent) -> f64 {
        match agent.status {
            AgentStatus::Idle => 1.0,
            AgentStatus::Working => 0.5,
            AgentStatus::Blocked => 0.0,
            AgentStatus::Offline => 0.0,
        }
    }

    fn extract_task_keywords(&self, task: &Task) -> Vec<String> {
        let text = format!(
            "{} {}",
            task.title,
            task.description.as_deref().unwrap_or("")
        );
        let text_lower = text.to_lowercase();

        let common_keywords = vec![
            "ui",
            "ux",
            "frontend",
            "backend",
            "api",
            "database",
            "db",
            "testing",
            "test",
            "validation",
            "form",
            "component",
            "auth",
            "authentication",
            "authorization",
            "design",
            "layout",
            "responsive",
            "accessibility",
            "a11y",
            "performance",
            "perf",
            "optimization",
            "optimize",
            "refactor",
            "bug",
            "fix",
            "feature",
            "enhancement",
            "security",
            "integration",
            "deployment",
            "migration",
            "documentation",
            "docs",
            "cli",
            "command",
            "error",
            "message",
            "suggest",
            "agent",
            "matcher",
            "scoring",
            "algorithm",
            "recommendation",
            "metric",
            "progress",
            "timeline",
            "visual",
        ];

        common_keywords
            .into_iter()
            .filter(|&keyword| text_lower.contains(keyword))
            .map(|s| s.to_string())
            .collect()
    }

    pub fn format_recommendations(&self, recommendations: &[AgentRecommendation]) -> String {
        let mut output = String::new();

        for (i, rec) in recommendations.iter().enumerate() {
            let medal = match i {
                0 => "🥇",
                1 => "🥈",
                2 => "🥉",
                _ => "•",
            };

            let score_str = format!("{:.0}%", rec.score * 100.0);
            let score_colored = if rec.score > 0.8 {
                score_str.green()
            } else if rec.score > 0.6 {
                score_str.yellow()
            } else {
                score_str.dimmed()
            };

            let agent_display_id = rec
                .agent
                .display_id
                .map(|id| format!("A{}", id))
                .unwrap_or_else(|| rec.agent.id[..8].to_string());

            output.push_str(&format!(
                "{} {} ({}) - {} match",
                medal,
                agent_display_id.bold(),
                rec.agent.name.dimmed(),
                score_colored
            ));

            if i == 0 && rec.score > 0.7 {
                output.push_str(&format!(" {}", "⭐ RECOMMENDED".green().bold()));
            }

            output.push('\n');

            // Status
            let status_str = match rec.agent.status {
                AgentStatus::Idle => "Idle (available now)".green(),
                AgentStatus::Working => {
                    if let Some(task_id) = &rec.agent.current_task_id {
                        if let Ok(Some(t)) = self.db.get_task(task_id) {
                            if let Some(display_id) = t.display_id {
                                format!("Working on task #{}", display_id).yellow()
                            } else {
                                "Working".yellow()
                            }
                        } else {
                            "Working".yellow()
                        }
                    } else {
                        "Working".yellow()
                    }
                }
                AgentStatus::Blocked => "Blocked".red(),
                AgentStatus::Offline => "Offline".dimmed(),
            };
            output.push_str(&format!("  Status: {}\n", status_str));

            // Breakdown
            output.push_str(&format!(
                "  Scores: Spec:{:.0}% Perf:{:.0}% Exp:{:.0}% Avail:{:.0}%\n",
                rec.specialization_score * 100.0,
                rec.performance_score * 100.0,
                rec.experience_score * 100.0,
                rec.availability_score * 100.0
            ));

            // Reasons
            if !rec.reasons.is_empty() {
                output.push_str(&format!("  Why: {}\n", rec.reasons.join(", ").dimmed()));
            }

            output.push('\n');
        }

        output
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Priority;

    #[test]
    fn test_extract_keywords() -> Result<()> {
        let db = Database::new(":memory:")?;
        let matcher = AgentMatcher::new(db);

        let task = Task {
            id: "test-1".to_string(),
            display_id: Some(1),
            title: "Build UI component with React".to_string(),
            description: Some("Frontend work".to_string()),
            status: crate::db::TaskStatus::Pending,
            priority: Priority::Medium,
            parent_id: None,
            assigned_agent: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            completed_at: None,
            estimated_duration: None,
            actual_duration: None,
            epic_name: None,
        };

        let keywords = matcher.extract_task_keywords(&task);
        assert!(keywords.contains(&"ui".to_string()));
        assert!(keywords.contains(&"frontend".to_string()));
        assert!(keywords.contains(&"component".to_string()));

        Ok(())
    }

    #[test]
    fn test_scoring_algorithm() -> Result<()> {
        let db = Database::new(":memory:")?;

        // Create test agent
        let agent = db.create_agent("test-agent".to_string())?;

        // Add specializations
        db.add_agent_specialization(&agent.id, "frontend")?;
        db.add_agent_specialization(&agent.id, "ui")?;

        // Create test task
        let task = Task {
            id: "test-1".to_string(),
            display_id: Some(1),
            title: "Build UI component".to_string(),
            description: Some("Frontend work".to_string()),
            status: crate::db::TaskStatus::Pending,
            priority: Priority::Medium,
            parent_id: None,
            assigned_agent: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            completed_at: None,
            estimated_duration: None,
            actual_duration: None,
            epic_name: None,
        };

        let matcher = AgentMatcher::new(db);
        let result = matcher.score_agent(&agent, &task)?;

        // Scores should be in 0-1 range
        assert!(result.score >= 0.0 && result.score <= 1.0);
        assert!(result.specialization_score >= 0.0 && result.specialization_score <= 1.0);
        assert!(result.performance_score >= 0.0 && result.performance_score <= 1.0);
        assert!(result.experience_score >= 0.0 && result.experience_score <= 1.0);
        assert!(result.availability_score >= 0.0 && result.availability_score <= 1.0);

        // With matching specializations, spec score should be good
        assert!(result.specialization_score > 0.5);

        Ok(())
    }

    #[test]
    fn test_suggest_agents_ordering() -> Result<()> {
        let db = Database::new(":memory:")?;

        // Create multiple agents with different profiles
        let agent1 = db.create_agent("expert".to_string())?;
        db.add_agent_specialization(&agent1.id, "frontend")?;
        db.add_agent_specialization(&agent1.id, "ui")?;

        let agent2 = db.create_agent("generalist".to_string())?;

        let agent3 = db.create_agent("backend-dev".to_string())?;
        db.add_agent_specialization(&agent3.id, "backend")?;
        db.add_agent_specialization(&agent3.id, "database")?;

        // Create a frontend task
        let task = Task {
            id: "test-1".to_string(),
            display_id: Some(1),
            title: "Build UI component".to_string(),
            description: Some("Frontend work".to_string()),
            status: crate::db::TaskStatus::Pending,
            priority: Priority::Medium,
            parent_id: None,
            assigned_agent: None,
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            completed_at: None,
            estimated_duration: None,
            actual_duration: None,
            epic_name: None,
        };

        let matcher = AgentMatcher::new(db);
        let recommendations = matcher.suggest_agents(&task, 3)?;

        assert_eq!(recommendations.len(), 3);

        // Agent1 (frontend expert) should be ranked first
        assert_eq!(recommendations[0].agent.name, "expert");

        // Scores should be descending
        assert!(recommendations[0].score >= recommendations[1].score);
        assert!(recommendations[1].score >= recommendations[2].score);

        Ok(())
    }

    #[test]
    fn test_availability_scoring() -> Result<()> {
        let db = Database::new(":memory:")?;

        let idle_agent = db.create_agent("idle-agent".to_string())?;
        let working_agent = db.create_agent("working-agent".to_string())?;

        // Set working agent status
        db.update_agent_status(&working_agent.id, AgentStatus::Working, None)?;

        // Get updated agents
        let idle = db.get_agent(&idle_agent.id)?.unwrap();
        let working = db.get_agent(&working_agent.id)?.unwrap();

        let matcher = AgentMatcher::new(db);
        let idle_avail = matcher.availability_score(&idle);
        let working_avail = matcher.availability_score(&working);

        assert_eq!(idle_avail, 1.0);
        assert_eq!(working_avail, 0.5);

        Ok(())
    }
}
