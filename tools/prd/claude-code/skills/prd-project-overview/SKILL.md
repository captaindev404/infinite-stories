---
name: prd-project-overview
description: View project statistics, epic progress, and overall task summaries using PRD Tool. Use when checking project status, epic completion rates, or getting an overview of all development work.
allowed-tools: Bash
---

# PRD Project Overview

This skill helps you view project statistics and progress using the PRD Tool.

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

## Project Statistics

### Overall Stats
```bash
prd stats
```

Shows:
- Total tasks by status (pending, in_progress, completed, etc.)
- Total agents
- Overall completion rate
- Active tasks count
- Blocked tasks count

### Epic Progress
```bash
prd epics
```

Shows for each epic:
- Epic name
- Total tasks in epic
- Completed tasks
- Completion percentage
- Status breakdown

## Viewing Tasks

### All Tasks Summary
```bash
# All tasks
prd list

# By status
prd list --status pending
prd list --status in_progress
prd list --status completed
prd list --status blocked

# By priority
prd list --priority critical
prd list --priority high
prd list --priority medium
prd list --priority low
```

### Ready Tasks
```bash
prd ready
```

Shows tasks that:
- Have all dependencies met
- Are not blocked
- Are ready to be worked on

### Next Available Task
```bash
# Next task overall
prd next

# Next by priority
prd next --priority high
prd next --priority critical

# Next for specific epic
prd next --epic "Backend"

# Next for agent
prd next --agent A1
```

## Filtering and Searching

### Filter by Epic
```bash
# All tasks in epic
prd list --epic "Backend"

# Completed tasks in epic
prd list --epic "Backend" --status completed

# Pending tasks in epic
prd list --epic "Backend" --status pending
```

### Filter by Agent
```bash
# Tasks assigned to agent
prd list --agent A1

# Unassigned tasks
prd list --no-agent

# Unassigned high-priority tasks
prd list --no-agent --priority high
```

### Combined Filters
```bash
# High-priority backend tasks in progress
prd list --epic "Backend" --priority high --status in_progress

# Critical unassigned tasks
prd list --no-agent --priority critical

# Completed tasks by specific agent
prd list --agent A1 --status completed
```

## Output Formats

### JSON Output
```bash
# All tasks as JSON
prd list --json

# Filtered tasks as JSON
prd list --status completed --json > completed.json
```

### Pagination
```bash
# First 10 tasks
prd list --limit 10

# Skip first 20, show next 10
prd list --limit 10 --offset 20
```

## Agent Status

### View All Agents
```bash
prd agent-list
prd agents  # Shorthand
```

Shows:
- Agent ID
- Agent name
- Current status (idle, working, blocked, offline)
- Current task (if working)
- Specializations

### Agent Status Overview
```bash
prd agent-status
```

Shows quick overview of all agent statuses.

## Live Dashboard

### Watch Mode
```bash
# Start live dashboard
prd watch

# Custom refresh interval (seconds)
prd watch --refresh-interval 5
```

**Features**:
- Real-time agent progress monitoring
- Auto-refreshing task status updates
- Live statistics and epic progress
- Interactive terminal dashboard
- Refresh interval configurable (default: 2 seconds)

**Use Cases**:
- Monitor team progress during sprints
- Track agent work in real-time
- Live status boards for standups
- Continuous project health monitoring

**Keyboard Controls**:
- Press `Ctrl+C` to exit watch mode

## Examples

### Daily Standup
```bash
# What's in progress?
prd list --status in_progress

# What's blocked?
prd list --status blocked

# Who's working on what?
prd agent-list

# What's ready to pick up?
prd ready
```

### Epic Review
```bash
# Check epic progress
prd epics

# Dive into specific epic
prd list --epic "Authentication"

# See what's left
prd list --epic "Authentication" --status pending

# See what's done
prd list --epic "Authentication" --status completed
```

### Sprint Planning
```bash
# Overall project stats
prd stats

# High-priority work
prd list --priority high
prd list --priority critical

# Unassigned work
prd list --no-agent --priority high

# Ready to start
prd ready
```

### Team Coordination
```bash
# Who's working?
prd agent-status

# What's each person doing?
prd list --agent backend-dev
prd list --agent frontend-dev
prd list --agent qa-engineer

# What's blocked?
prd list --status blocked

# What can we pick up?
prd ready
```

### Export for Reporting
```bash
# Export completed tasks
prd list --status completed --json > weekly-completed.json

# Export epic progress
prd epics > epic-status.txt

# Export overall stats
prd stats > project-stats.txt
```

## Task Counts by Status

To get counts for different statuses:

```bash
# Pending tasks
prd list --status pending | grep -c "#"

# In progress
prd list --status in_progress | grep -c "#"

# Completed
prd list --status completed | grep -c "#"
```

Or use `prd stats` for automatic counts.

## Best Practices

1. **Regular Reviews**: Check `prd stats` and `prd epics` regularly
2. **Daily Standups**: Use `prd list --status in_progress` and `prd ready`
3. **Track Blockers**: Monitor `prd list --status blocked`
4. **Epic Focus**: Use epic filtering to track feature progress
5. **Unassigned Work**: Regular `prd list --no-agent` to find orphaned tasks
6. **Export Data**: Use JSON output for custom reporting

## Quick Reference

```bash
# Project health check
prd stats
prd epics
prd list --status blocked
prd ready

# What's happening now?
prd agent-status
prd list --status in_progress

# What's next?
prd ready
prd list --no-agent --priority high

# Epic status
prd epics
prd list --epic "EpicName"

# Export
prd list --json
prd stats > report.txt
```

## Integration Notes

- Statistics are calculated in real-time from the database
- Epic progress includes all task statuses
- Ready tasks exclude blocked and completed tasks
- Agent status reflects current task assignments
- All commands support filtering for targeted views
