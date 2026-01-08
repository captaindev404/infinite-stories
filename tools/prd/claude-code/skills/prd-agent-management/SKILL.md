---
name: prd-agent-management
description: Manage development agents (AI agents or team members) using PRD Tool. Use when creating agents, assigning tasks to agents, syncing agent work, or checking agent status. Supports agent statuses (idle, working, blocked, offline).
allowed-tools: Bash
---

# PRD Agent Management

This skill helps you create and manage agents (AI agents or team members) using the PRD Tool.

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

## Creating Agents

### Create New Agent
```bash
prd agent-create "agent-name"
```

**Example**:
```bash
prd agent-create "backend-dev"    # Output: ID: A1
prd agent-create "frontend-dev"   # Output: ID: A2
prd agent-create "qa-engineer"    # Output: ID: A3
```

## Viewing Agents

### List All Agents
```bash
prd agent-list
prd agents  # Shorthand
```

### Agent Status
```bash
# View all agent statuses
prd agent-status
```

## Assigning Work

### Assign Task to Agent
```bash
# Simple assignment
prd assign "#42" A1

# Sync (assign + start work)
prd sync A1 "#42"
```

**Important**: `prd sync` does two things:
1. Sets agent status to `working`
2. Sets task status to `in_progress`
3. Links agent and task together

### Update Agent Status
```bash
# Set agent to working
prd agent-status A1 working --task "#42"

# Set agent to idle
prd agent-status A1 idle

# Set agent to blocked
prd agent-status A1 blocked

# Set agent to offline
prd agent-status A1 offline
```

**Valid Statuses**: `idle`, `working`, `blocked`, `offline`

## Agent Workflows

### Start Work
```bash
# Method 1: Sync (recommended)
prd sync A1 "#42"

# Method 2: Manual
prd assign "#42" A1
prd update "#42" in_progress
prd agent-status A1 working --task "#42"
```

### Complete Work
```bash
# Complete the task
prd complete "#42"

# Agent automatically returns to idle
```

### Get Next Task for Agent
```bash
# Find next task for agent
prd next --agent A1

# Auto-assign and start
prd next --agent A1 --sync

# Filter by priority
prd next --agent A1 --priority high --sync
```

## Batch Operations

### Assign Multiple Tasks
```bash
prd batch-assign "#10,#11,#12" A1
```

## Progress Reporting

### Report Progress
```bash
prd report-progress A1 "#42" 75 "Almost done with testing"
```

**Parameters**:
- Agent ID: `A1`
- Task ID: `#42`
- Progress %: `75`
- Message: `"Almost done with testing"`

## Viewing Agent Work

### List Tasks for Agent
```bash
# All tasks for agent
prd list --agent A1

# Filter by status
prd list --agent A1 --status in_progress
prd list --agent A1 --status completed

# Filter by epic
prd list --agent A1 --epic "Backend"
```

### View Unassigned Tasks
```bash
prd list --no-agent
prd list --no-agent --priority high
```

## Agent ID Format

- Use `A1`, `A2`, etc. in commands
- Display IDs are assigned sequentially starting from A1
- Can also use agent name in some commands

## Examples

### Complete Agent Workflow
```bash
# 1. Create agent
prd agent-create "backend-specialist"
# Output: ID: A1

# 2. Find and assign work
prd next --agent A1 --priority high --sync
# Auto-assigns next high-priority task

# 3. Report progress
prd report-progress A1 "#42" 50 "Completed auth setup"

# 4. Complete task
prd complete "#42"

# Agent automatically returns to idle
```

### Multi-Agent Coordination
```bash
# Create multiple agents
prd agent-create "backend-dev"   # A1
prd agent-create "frontend-dev"  # A2

# Assign different tasks
prd sync A1 "#10"  # Backend work
prd sync A2 "#11"  # Frontend work

# Check agent status
prd agent-list

# View each agent's tasks
prd list --agent A1
prd list --agent A2
```

### Finding Work
```bash
# Show what each agent is working on
prd agent-status

# Find unassigned critical tasks
prd list --no-agent --priority critical

# Get next task for agent
prd next --agent A1 --priority high
```

## Best Practices

1. **Use Sync**: Prefer `prd sync A1 "#42"` over manual assignment
2. **Report Progress**: Use progress reporting for long-running tasks
3. **Track Status**: Keep agent status updated for coordination
4. **Use Next Command**: Use `prd next --agent A1` for intelligent task assignment
5. **Monitor Workload**: Check `prd agent-status` to balance work across agents

## Integration Notes

- Agent work is tracked in activity logs
- Agent metrics are calculated based on completion history
- Agent status affects task suggestions and workload balancing
- Progress reporting provides real-time task updates
- Use `prd next` for intelligent task-to-agent matching
