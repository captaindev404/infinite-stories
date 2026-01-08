---
name: prd-dependencies
description: Manage task dependencies and blockers using PRD Tool. Use when tasks need to be ordered, when defining task prerequisites, or when checking which tasks are blocked or ready to work on. Includes circular dependency detection.
allowed-tools: Bash
---

# PRD Task Dependencies

This skill helps you manage task dependencies and ordering using the PRD Tool.

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

## Creating Dependencies

### Basic Dependency
```bash
# Task #2 depends on Task #1
prd depends "#2" --on "#1"

# Alternative syntax: Task #1 blocks Task #2
prd depends "#1" --blocks "#2"
```

**Both commands create the same dependency**: #2 cannot start until #1 is completed.

### Multiple Dependencies
```bash
# Task #5 depends on both #3 and #4
prd depends "#5" --on "#3"
prd depends "#5" --on "#4"
```

## Viewing Dependencies

### List Dependencies for a Task
```bash
# Show what task depends on
prd depends "#5" --list
```

Output shows:
- Tasks that must be completed first (dependencies)
- Tasks that are blocked by this task (blockers)

### View Dependency Tree
```bash
# Show task with dependencies
prd show "#5"
```

The task details include dependency information.

## Finding Work

### Ready Tasks
Show tasks with all dependencies met and ready to work on:
```bash
prd ready
```

This command:
- Filters out blocked tasks
- Shows only tasks where all dependencies are completed
- Uses circular dependency detection
- Perfect for finding next available work

### Next Task with Dependencies
```bash
# Get next ready task for agent
prd next --agent A1

# Filter by priority (only ready tasks)
prd next --priority high

# Auto-assign ready task
prd next --agent A1 --sync
```

## Dependency Patterns

### Sequential Tasks
```bash
# Create a sequence: #1 → #2 → #3
prd depends "#2" --on "#1"
prd depends "#3" --on "#2"

# Check what's ready
prd ready  # Shows only #1
```

### Parallel Tasks with Common Dependency
```bash
# Both #2 and #3 depend on #1
prd depends "#2" --on "#1"
prd depends "#3" --on "#1"

# After #1 completes:
prd complete "#1"
prd ready  # Shows both #2 and #3
```

### Diamond Pattern
```bash
# #1 → #2 and #3 → #4
prd depends "#2" --on "#1"
prd depends "#3" --on "#1"
prd depends "#4" --on "#2"
prd depends "#4" --on "#3"

# #4 only becomes ready after both #2 and #3 complete
```

## Circular Dependency Detection

The system automatically detects circular dependencies:

```bash
prd depends "#1" --on "#2"
prd depends "#2" --on "#3"
prd depends "#3" --on "#1"  # Error: Creates circular dependency
```

You'll receive an error if a dependency would create a cycle.

## Examples

### Feature Development Flow
```bash
# Create tasks
prd create "Design API schema" --epic "API" --priority high      # #1
prd create "Implement endpoints" --epic "API" --priority high    # #2
prd create "Add tests" --epic "API" --priority medium            # #3
prd create "Deploy to staging" --epic "API" --priority medium    # #4

# Set dependencies
prd depends "#2" --on "#1"  # Implementation needs design
prd depends "#3" --on "#2"  # Tests need implementation
prd depends "#4" --on "#3"  # Deploy needs tests

# Find ready work
prd ready  # Shows only #1

# Complete work in order
prd sync A1 "#1"
prd complete "#1"
prd ready  # Now shows #2

prd sync A1 "#2"
prd complete "#2"
prd ready  # Now shows #3
```

### Parallel Development
```bash
# Create tasks
prd create "Backend API" --epic "Feature X"        # #10
prd create "Frontend UI" --epic "Feature X"        # #11
prd create "Integration" --epic "Feature X"        # #12

# Integration depends on both
prd depends "#12" --on "#10"
prd depends "#12" --on "#11"

# Parallel work
prd sync backend-agent "#10"
prd sync frontend-agent "#11"

# Both must complete before integration
prd ready  # Shows #10 and #11, not #12

# After both complete
prd complete "#10"
prd complete "#11"
prd ready  # Now shows #12
```

### Complex Epic with Dependencies
```bash
# Authentication epic
prd create "User model" --epic "Auth"              # #20
prd create "Password hashing" --epic "Auth"        # #21
prd create "Login endpoint" --epic "Auth"          # #22
prd create "JWT tokens" --epic "Auth"              # #23
prd create "Protected routes" --epic "Auth"        # #24

# Set up dependencies
prd depends "#21" --on "#20"  # Hashing needs user model
prd depends "#22" --on "#21"  # Login needs hashing
prd depends "#23" --on "#22"  # Tokens need login
prd depends "#24" --on "#23"  # Routes need tokens

# View progress
prd ready
prd list --epic "Auth" --status completed
prd epics  # Shows Auth epic progress
```

## Removing Dependencies

Currently, dependencies can be removed by recreating the dependency structure. If you need to remove a dependency, you can:

1. Cancel the dependent task
2. Create a new task without the dependency
3. Or contact the PRD tool maintainer for dependency removal support

## Best Practices

1. **Define Dependencies Early**: Set task order before starting work
2. **Use Ready Command**: Check `prd ready` to find available work
3. **Avoid Circular Dependencies**: Plan task flow to prevent cycles
4. **Document Reasons**: Use task descriptions to explain dependencies
5. **Keep It Simple**: Don't over-complicate dependency chains
6. **Review Dependencies**: Use `prd depends "#X" --list` to verify structure

## Integration Notes

- Dependencies are checked when finding ready tasks
- Circular dependency detection prevents invalid task graphs
- Dependency information is shown in task details
- Ready tasks list is cached for performance
- Dependencies are preserved when tasks are updated
