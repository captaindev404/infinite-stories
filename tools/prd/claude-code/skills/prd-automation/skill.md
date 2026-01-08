---
name: prd-automation
description: Automate task management with git integration, documentation sync, file watching, and hook management using PRD Tool. Use when setting up automation, syncing tasks from git commits or docs, managing hooks, or watching for task completion files.
allowed-tools: Bash
---

# PRD Automation

This skill helps you automate task management using git integration, documentation sync, file watching, and hooks.

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

## Documentation Sync

### Sync Tasks from Documentation
```bash
# Sync from docs/tasks directory
prd sync-docs

# Custom docs directory
prd sync-docs --docs-dir custom/path

# Dry run (preview changes)
prd sync-docs --dry-run
```

**How it works**:
- Scans docs directory for task completion files
- Parses task IDs and completion status
- Updates database to match documentation
- Useful for teams using docs-driven workflows

### Sync Tasks from Git History
```bash
# Sync from git commit history
prd sync-docs --from-git

# Since specific date
prd sync-docs --from-git --since 2025-10-01

# Date range
prd sync-docs --from-git --since 2025-10-01 --until 2025-10-13

# Specific branch
prd sync-docs --from-git --branch feature/new-ui

# Dry run to preview
prd sync-docs --from-git --dry-run
```

**Git Integration Features**:
- Parses commit messages for task IDs (e.g., "Fix #42: Update login flow")
- Extracts completion markers from commits
- Syncs task status based on commit history
- Supports date-based filtering
- Works across branches

**Date Format**: ISO 8601 (YYYY-MM-DD)

**Example Commit Messages**:
```
Completed #42: Implement user authentication
Fixes #10: Resolve login bug
Closes #15: Add password reset feature
```

## File Watching

### Watch for Task Completion Files
```bash
# Start file watcher
prd watch-files
```

**Features**:
- Monitors docs/tasks directory for changes
- Auto-syncs when completion files are created/modified
- Runs in background or foreground
- Real-time task status updates

**Use Cases**:
- Continuous integration workflows
- Team collaboration with file-based updates
- Automated task tracking from documentation
- CI/CD pipeline integration

**File Format Expected**:
```markdown
# Task #42 - Completed
Status: completed
Agent: A1
Completed: 2025-10-31
```

## Git Hooks

### Install Git Hook
```bash
# Install hook for auto-completion
prd install-git-hook

# Uninstall hook
prd install-git-hook --uninstall
```

**What it does**:
- Installs pre-commit or post-commit hook
- Automatically updates task status on git commits
- Parses commit messages for task references
- Syncs PRD database with git activity

**Hook Behavior**:
- Pre-commit: Validates task IDs in commit messages
- Post-commit: Auto-completes tasks referenced in commits
- Updates task logs with commit SHA

## Hook System Management

### Initialize Hooks Configuration
```bash
# Create hooks config with examples
prd hooks init
```

Creates `.prd/hooks.yaml` with example hook configurations.

### List All Hooks
```bash
prd hooks list
```

Shows:
- Hook name
- Hook type (pre-commit, post-commit, task-update, etc.)
- Enabled/disabled status
- Command to execute
- Trigger conditions

### Test Hook
```bash
# Test a hook without side effects
prd hooks test <hook-name>
```

**Features**:
- Dry run of hook execution
- Shows what would happen
- Validates hook configuration
- No database changes

### Enable/Disable Hooks
```bash
# Enable a hook
prd hooks enable <hook-name>

# Disable a hook
prd hooks disable <hook-name>
```

**Common Hooks**:
- `task-created`: Runs when new task is created
- `task-completed`: Runs when task is marked complete
- `agent-synced`: Runs when agent starts work
- `git-commit`: Runs on git commits
- `slack-notify`: Posts to Slack on task updates

## Hook Configuration

Example `.prd/hooks.yaml`:
```yaml
hooks:
  - name: slack-notify
    type: task-completed
    enabled: true
    command: |
      curl -X POST $SLACK_WEBHOOK \
        -d '{"text": "Task #$TASK_ID completed by $AGENT"}'

  - name: git-commit-sync
    type: post-commit
    enabled: true
    command: prd sync-docs --from-git --since today

  - name: task-logger
    type: task-created
    enabled: true
    command: echo "Task created: #$TASK_ID - $TASK_TITLE" >> tasks.log
```

**Environment Variables Available**:
- `$TASK_ID`: Task ID
- `$TASK_TITLE`: Task title
- `$TASK_STATUS`: Current status
- `$AGENT`: Agent ID or name
- `$EPIC`: Epic name

## Examples

### Git-Based Workflow
```bash
# 1. Install git hook
prd install-git-hook

# 2. Make changes and commit with task reference
git commit -m "Completed #42: Implement login feature"

# 3. Hook auto-completes task #42
# Task status updated to 'completed'

# 4. View updated stats
prd stats
```

### Documentation-Driven Workflow
```bash
# 1. Start file watcher
prd watch-files &

# 2. Create completion file
cat > docs/tasks/task-42-completed.md <<EOF
# Task #42 - User Authentication
Status: completed
Agent: backend-dev
EOF

# 3. Watcher auto-syncs task
# Task #42 marked as completed

# 4. Verify
prd show "#42"
```

### CI/CD Integration
```bash
# In CI/CD pipeline script
# Sync tasks based on merged commits
prd sync-docs --from-git --since $LAST_DEPLOY_DATE --branch main

# Update deployment task
prd complete "#${DEPLOYMENT_TASK_ID}"

# Trigger deployment hook
prd hooks test deploy-notification
```

### Team Collaboration
```bash
# Initialize hooks for team
prd hooks init

# Enable Slack notifications
prd hooks enable slack-notify

# Enable git sync
prd hooks enable git-commit-sync

# List active hooks
prd hooks list

# Start watching docs
prd watch-files
```

### Sprint Retrospective
```bash
# Sync all completed work from sprint
prd sync-docs --from-git \
  --since 2025-10-15 \
  --until 2025-10-31 \
  --branch sprint-10

# Generate completion report
prd stats
prd list --status completed --json > sprint-10-report.json
```

## Best Practices

1. **Use Dry Run**: Test sync operations with `--dry-run` before applying
2. **Date Filters**: Use specific date ranges to avoid syncing unwanted commits
3. **Branch Strategy**: Sync from main/master for production task tracking
4. **Hook Testing**: Always test hooks with `prd hooks test` before enabling
5. **File Watching**: Use file watching for real-time collaboration
6. **Git Hooks**: Install git hooks for automatic task tracking
7. **Documentation**: Keep task completion docs in standard format
8. **CI/CD**: Integrate PRD sync into deployment pipelines

## Integration Notes

- Sync operations are idempotent (safe to run multiple times)
- Git sync uses commit message parsing for task references
- File watching requires docs/tasks directory structure
- Hooks support shell commands and scripts
- Hook environment variables available for custom integrations
- Date filtering uses ISO 8601 format (YYYY-MM-DD)
- Dry run mode shows preview without making changes
