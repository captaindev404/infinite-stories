---
name: prd-task-management
description: Create, update, and manage development tasks using the PRD Tool CLI. Use when the user needs to create tasks, update task status, add acceptance criteria, or view task details. Supports task priorities (low, medium, high, critical) and statuses (pending, in_progress, blocked, review, completed, cancelled).
allowed-tools: Bash
---

# PRD Task Management

This skill helps you create and manage development tasks using the PRD Tool located in `tools/prd/`.

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

For brevity in examples below, we'll use `prd` but you must always use the full relative path with `--database tools/prd.db`.

## Creating Tasks

### Basic Task Creation
```bash
prd create "Task title" [--epic "Epic Name"] [--priority high]
```

**Priorities**: `low`, `medium`, `high`, `critical`

**Example**:
```bash
prd create "Implement Firebase Authentication" --epic "Backend" --priority high
```

### With Parent Task (Subtasks)
```bash
prd create "Subtask title" --parent "#42"
```

## Viewing Tasks

### Show Task Details
```bash
# Basic details
prd show "#42"

# With activity logs
prd show "#42" --logs
```

### List Tasks
```bash
# All tasks
prd list

# Filter by status
prd list --status pending
prd list --status in_progress
prd list --status completed

# Filter by priority
prd list --priority high
prd list --priority critical

# Filter by epic
prd list --epic "Backend"

# Combine filters
prd list --status pending --priority high --epic "Backend"

# Pagination
prd list --limit 10 --offset 20

# JSON output
prd list --json
```

## Updating Tasks

### Update Status
```bash
# Change status
prd update "#42" in_progress
prd update "#42" completed
prd update "#42" blocked
prd update "#42" review
prd update "#42" cancelled

# Quick complete
prd complete "#42"

# Cancel with reason
prd cancel "#42" --reason "Duplicate task"
```

**Valid Statuses**: `pending`, `in_progress`, `blocked`, `review`, `completed`, `cancelled`

## Acceptance Criteria

### Add Criteria
```bash
prd ac "#42" add "All unit tests pass"
prd ac "#42" add "Security review completed"
prd ac "#42" add "Documentation updated"
```

### List Criteria
```bash
prd ac "#42" list
```

### Check/Uncheck Criteria
```bash
# Mark criterion complete (by position)
prd ac "#42" check 1
prd ac "#42" check 2

# Mark criterion incomplete
prd ac "#42" uncheck 1
```

## Finding Tasks to Work On

### Ready Tasks
Show tasks with all dependencies met:
```bash
prd ready
```

### Next Task
Get the next task for an agent:
```bash
prd next --agent A1
prd next --priority high
prd next --epic "Backend"
prd next --agent A1 --sync  # Auto-assign and start
```

## Batch Operations

### Update Multiple Tasks
```bash
prd batch-update "#1,#2,#3" completed
```

### Assign Multiple Tasks
```bash
prd batch-assign "#10,#11,#12" A1
```

## Time Tracking

```bash
prd duration "#42" --estimated 120 --actual 95
```

## Task Breakdown

### Break Task into Subtasks
```bash
# Break down a task interactively
prd breakdown "#42" --interactive

# Basic breakdown (prompts for subtasks)
prd breakdown "#42"
```

**Interactive Mode**:
- Creates multiple subtasks under a parent task
- Each subtask inherits the epic from parent
- Subtasks are automatically linked to parent with `--parent` relationship

**Example**:
```bash
# Break down epic task
prd breakdown "#10"
# Prompts for:
# - Number of subtasks
# - Title for each subtask
# - Priority for each subtask
```

## Batch Complete

### Complete Multiple Tasks
```bash
# Complete multiple tasks at once
prd complete-batch "#1,#2,#3"

# With task list
prd complete-batch "#10" "#11" "#12"
```

**Use Cases**:
- Bulk task completion after sprint review
- Closing related tasks simultaneously
- Cleanup of completed work

## Best Practices

1. **Use Epics**: Group related tasks under epics for better organization
2. **Set Priorities**: Mark urgent work as `high` or `critical`
3. **Add Acceptance Criteria**: Define "done" clearly before starting work
4. **Update Status**: Keep task status current for team coordination
5. **Use Task IDs**: Reference tasks by `#42` format for clarity

## Task ID Format

- Use `#42` or just `42` in commands
- Display IDs are assigned sequentially starting from 1
- The `#` prefix is optional but recommended for clarity

## Examples

### Complete Workflow
```bash
# 1. Create task
prd create "Build user authentication" --epic "Auth System" --priority critical
# Output: ID: #1

# 2. Add acceptance criteria
prd ac "#1" add "All tests pass"
prd ac "#1" add "Security audit complete"

# 3. View task
prd show "#1"

# 4. Start work (see prd-agent-management skill)
prd sync A1 "#1"

# 5. Mark criteria complete
prd ac "#1" check 1
prd ac "#1" check 2

# 6. Complete task
prd complete "#1"
```

### Finding Work
```bash
# Show unassigned high-priority tasks
prd list --priority high --no-agent

# Find tasks ready to work on
prd ready

# Get next task for backend agent
prd next --agent backend-dev --priority high
```

## Integration Notes

- PRD database is stored at `tools/prd.db`
- All task changes are logged in activity history
- Use `prd show "#X" --logs` to see complete audit trail
- Tasks can be linked to git commits for traceability
