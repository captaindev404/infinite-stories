# PRD Command Helper

This file provides the exact command syntax for running PRD commands in this project.

## PRD Executable Location

From project root:
```
tools/prd/target/release/prd
```

## Database Location

From project root:
```
tools/prd.db
```

## Command Template

**IMPORTANT**: All commands must be run from the project root directory.

```bash
./tools/prd/target/release/prd --database tools/prd.db <command> [args]
```

## Examples

```bash
# List all tasks
./tools/prd/target/release/prd --database tools/prd.db list

# Create a task
./tools/prd/target/release/prd --database tools/prd.db create "Task title" --priority high

# Show task details
./tools/prd/target/release/prd --database tools/prd.db show "#42"

# View statistics
./tools/prd/target/release/prd --database tools/prd.db stats

# Create an agent
./tools/prd/target/release/prd --database tools/prd.db agent-create "agent-name"
```

## Usage in Skills

When using these commands in Claude Code Skills, always use the relative path from the project root:

```bash
./tools/prd/target/release/prd --database tools/prd.db <command>
```
