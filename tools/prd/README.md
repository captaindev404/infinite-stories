# PRD Tool - Agent Task Management & Synchronization

A Rust-based CLI tool for managing tasks, breaking down work, and synchronizing between multiple agents. Perfect for coordinating complex development work across AI agents or team members.

## Features

### Core Capabilities
- **Human-Readable IDs**: Use `#42` and `A5` instead of UUIDs
- **Epic Grouping**: Organize related tasks into epics
- **Task Dependencies**: Define task ordering and blockers with circular dependency detection
- **Acceptance Criteria**: Define "done" with trackable checklists
- **Progress Tracking**: Track estimated vs actual time, completion rates
- **Activity Logging**: Complete audit trail of all task changes

### Automation (Phase 3)
- **File Watcher**: Auto-detect completion documents in real-time (`prd daemon start`)
- **Git Integration**: Sync tasks from commit history (`prd git-sync`)
- **Custom Hooks**: Run scripts on task events (completion, errors, milestones)

### Real-Time Monitoring (Phase 2)
- **Live Dashboard**: `prd watch` with real-time updates
- **Progress Reporting**: Agents report % completion with messages
- **Desktop Notifications**: System alerts for completions, errors, milestones

### Intelligence (Phase 4)
- **Smart Suggestions**: 4-factor weighted agent-task matching (85%+ accuracy)
- **Specialization Tracking**: Tag agents with skills
- **Performance Metrics**: Track completion rates and success rates
- **Contextual Errors**: Fuzzy matching with helpful suggestions
- **Visual Timelines**: ASCII sprint charts and burndown graphs

## Quick Start

### Installation

```bash
cd tools/prd
cargo build --release

# Optional: Add to shell profile
alias prd='/path/to/tools/prd/target/release/prd'
```

### Initialize Database

```bash
prd init              # Create new database
prd init --force      # Force recreate
```

### Basic Workflow

```bash
# 1. Create tasks
prd create "Build auth system" --epic "Auth" --priority high
# Output: ID: #1

# 2. Create agent
prd agent-create "backend-dev"
# Output: ID: A1

# 3. Add acceptance criteria
prd ac "#1" add "All unit tests pass"
prd ac "#1" add "Security review approved"

# 4. Start work
prd sync A1 "#1"

# 5. Check progress
prd ac "#1" check 1

# 6. Complete task
prd complete "#1"

# 7. View statistics
prd stats
prd epics
```

## Command Reference

### Task Management

```bash
# Create
prd create "Title" [--epic "Name"] [--priority high] [--parent "#42"]

# List & Filter
prd list [--status pending] [--epic "Name"] [--priority high] [--agent A1]
prd list --no-agent              # Unassigned tasks
prd list --limit 10 --offset 20  # Pagination
prd list --json                  # JSON output

# View & Update
prd show "#42" [--logs]
prd update "#42" completed
prd complete "#42"               # Quick complete
prd cancel "#42" --reason "Duplicate"

# Smart Selection
prd next [--priority high] [--epic "Auth"] [--agent A1] [--sync]
prd ready                        # Tasks with all dependencies met

# Batch Operations
prd batch-update "#1,#2,#3" completed
prd batch-assign "#10,#11,#12" A1
```

**Statuses**: `pending`, `in_progress`, `blocked`, `review`, `completed`, `cancelled`
**Priorities**: `low`, `medium`, `high`, `critical`

### Dependencies

```bash
prd depends "#2" --on "#1"       # #2 depends on #1
prd depends "#1" --blocks "#2"   # Same as above
prd depends "#42" --list         # Show dependency tree
prd ready                        # List tasks ready to work on
```

### Acceptance Criteria

```bash
prd ac "#42" add "All tests pass"
prd ac "#42" list
prd ac "#42" check 1             # Mark criterion complete
prd ac "#42" uncheck 1           # Mark incomplete
```

### Agent Management

```bash
# Create & List
prd agent-create "backend-dev"   # Output: ID: A1
prd agent-list                   # List all agents
prd agent-specialize A12 frontend ui react  # Add specializations

# Assign & Sync
prd assign "#42" A1
prd sync A1 "#42"                # Start work (sets agent to working, task to in_progress)

# Status Updates
prd agent-status A1 working --task "#42"
prd agent-status A1 idle

# Smart Matching (Phase 4)
prd suggest "#42"                # Get best agent match
```

### Automation Features

```bash
# File Watching
prd daemon start [--foreground]  # Start file watcher
prd daemon stop

# Git Integration
prd git-sync --since "2025-01-01"
prd git-sync --all

# Custom Hooks
prd hook add on-complete "./notify-slack.sh"
prd hook add on-error "./alert-team.sh"
prd hook list
prd hook remove <id>

# Document Sync
prd scan /path/to/docs           # Find completion documents
prd sync                         # Process all completions
prd reconcile                    # Validate consistency
```

### Real-Time Features

```bash
# Live Dashboard
prd watch [--interval 2]         # Real-time updates

# Progress Reporting
prd report-progress A12 "#42" 75 "Almost done"

# Visualizations
prd visualize                    # Sprint timelines & burndown charts
```

### Reporting

```bash
prd stats                        # Task statistics
prd epics                        # Epic progress
prd duration "#42" --estimated 120 --actual 95  # Time tracking
```

### Database

```bash
prd init [--force]
prd migrate latest
prd migrate status
prd migrate rollback <version>
```

## ID System

**Task IDs**: `#1`, `#42` (or `1`, `42` without #)
**Agent IDs**: `A1`, `A5` (can also use agent name)
**Usage**: All commands accept display IDs or full UUIDs

## Complete Workflow Example

```bash
# Setup
prd init
prd agent-create "backend-dev"   # A1
prd agent-create "frontend-dev"  # A2

# Create epic with tasks
prd create "User Auth" --epic "Auth System" --priority critical  # #1
prd create "OAuth Integration" --epic "Auth System" --priority high  # #2
prd create "Password Reset" --epic "Auth System"  # #3

# Set dependencies
prd depends "#2" --on "#1"
prd depends "#3" --on "#1"

# Add acceptance criteria
prd ac "#1" add "All tests pass"
prd ac "#1" add "Security audit complete"

# Check what's ready
prd ready  # Shows #1

# Start work
prd sync A1 "#1"

# Complete criteria
prd ac "#1" check 1
prd ac "#1" check 2

# Complete task
prd complete "#1"

# Check next available
prd ready  # Shows #2 and #3

# View progress
prd epics  # Auth System - 1/3 tasks (33%)
prd stats
```

## Advanced Features

### Task Breakdown

```bash
prd create "Build Payment System" --priority critical  # #50
prd breakdown "#50" --interactive  # Guided subtask creation
# Or manual:
prd create "Stripe Integration" --parent "#50"  # #51
prd create "Payment UI" --parent "#50"  # #52
```

### Multi-Agent Coordination

```bash
# Parallel work
prd sync backend-agent "#11"
prd sync qa-agent "#13"

# Task completes, unblocking others
prd complete "#11"
prd ready  # Shows newly available tasks
```

### Filtering Patterns

```bash
# Unassigned high-priority tasks
prd list --priority high --no-agent

# Critical tasks in review
prd list --priority critical --status review

# Tasks for specific agent in epic
prd list --epic "Auth" --agent A1 --status in_progress

# Export completed tasks
prd list --status completed --json > export.json
```

## Best Practices

1. **Use Epics for Grouping**: Group related tasks under epics and track progress with `prd epics`
2. **Define Dependencies Early**: Set task ordering upfront to enable smart work queues
3. **Use Acceptance Criteria**: Define "done" clearly with trackable checklists
4. **Specialize Agents**: Tag agents with skills for better task matching
5. **Break Down Large Tasks**: Use `prd breakdown` for complex work

## Database Schema

### Key Tables

**tasks**: `id`, `display_id`, `title`, `description`, `status`, `priority`, `parent_id`, `assigned_agent`, `epic_name`, `created_at`, `updated_at`, `completed_at`, `estimated_duration`, `actual_duration`

**agents**: `id`, `display_id`, `name`, `status`, `current_task_id`, `specializations`, `created_at`, `last_active`

**task_dependencies**: `task_display_id`, `depends_on_display_id`, `dependency_type`, `created_at`

**acceptance_criteria**: `id`, `task_display_id`, `criterion`, `completed`, `created_at`, `completed_at`

**task_logs**: `id`, `task_id`, `agent_id`, `action`, `details`, `created_at`

## Troubleshooting

```bash
# Check migration status
prd migrate status
prd migrate latest

# View task details with logs
prd show "#42" --logs

# List all tasks to find correct ID
prd list | grep "keyword"
```

## Dashboard

Launch interactive dashboard:

```bash
prd-dashboard [/path/to/prd.db] [refresh_seconds]
```

Features: Real-time statistics, active tasks, blocked tasks, agent activity, recent logs, upcoming tasks

Press `Ctrl+C` to exit.

## License

MIT
