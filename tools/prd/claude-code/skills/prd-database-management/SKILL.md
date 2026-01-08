---
name: prd-database-management
description: Initialize and manage the PRD Tool database, including database creation, migrations, and schema updates. Use when setting up PRD Tool for the first time, applying database migrations, or troubleshooting database issues.
allowed-tools: Bash
---

# PRD Database Management

This skill helps you initialize and manage the PRD Tool database.

## Database Location

**IMPORTANT**: The PRD database is stored at (relative to project root):
```
tools/prd.db
```

Always run commands from the project root with the relative `--database` flag:
```bash
./tools/prd/target/release/prd --database tools/prd.db
```

## Building PRD Tool

Before using PRD, you must build it:

```bash
cd tools/prd
cargo build --release
```

The compiled binary will be at: `tools/prd/target/release/prd`

## Database Initialization

### First Time Setup
```bash
# Initialize new database
prd init
```

This creates:
- New SQLite database at `tools/prd.db`
- All required tables (tasks, agents, dependencies, etc.)
- Initial schema version

### Force Recreate
```bash
# WARNING: Destroys all existing data
prd init --force
```

Use `--force` to:
- Reset database completely
- Clear all tasks, agents, and logs
- Start fresh with clean schema

**⚠️ WARNING**: `--force` deletes all existing data. Use with caution!

## Database Migrations

### Check Migration Status
```bash
prd migrate status
```

Shows:
- Current schema version
- Available migrations
- Which migrations have been applied
- Which migrations are pending

### Apply Latest Migrations
```bash
prd migrate latest
```

Applies all pending migrations to bring database to latest schema version.

### Rollback Migration
```bash
prd migrate rollback <version>
```

Rolls back to a specific schema version. Use with caution.

## Migration History

PRD uses numbered migrations in `tools/prd/migrations/`:

1. **001_add_display_ids.sql** - Human-readable IDs (#1, A1)
2. **002_add_dependencies.sql** - Task dependencies and circular detection
3. **003_add_acceptance_criteria.sql** - Acceptance criteria checklists
4. **004_add_completion_fields.sql** - Duration tracking
5. **005_add_agent_progress.sql** - Real-time progress reporting
6. **006_add_agent_intelligence.sql** - Specializations and metrics
7. **007_add_sprints.sql** - Sprint support

## Complete Setup Workflow

### New Project Setup
```bash
# 1. Build PRD tool
cd tools/prd
cargo build --release

# 2. Initialize database
./target/release/prd --database ../prd.db init

# 3. Verify setup
./target/release/prd --database ../prd.db migrate status

# 4. Create first agent
./target/release/prd --database ../prd.db agent-create "main-dev"

# 5. Create first task
./target/release/prd --database ../prd.db create "Setup complete" --priority low
```

### Existing Project Setup
```bash
# 1. Build PRD tool
cd tools/prd
cargo build --release

# 2. Check migration status
./target/release/prd --database ../prd.db migrate status

# 3. Apply any pending migrations
./target/release/prd --database ../prd.db migrate latest

# 4. Verify
./target/release/prd --database ../prd.db stats
```

## Troubleshooting

### Database Locked
If you get "database is locked" errors:
```bash
# Check for running prd processes
ps aux | grep prd

# Kill stale processes
killall prd

# Try command again
prd stats
```

### Schema Version Mismatch
```bash
# Check migration status
prd migrate status

# Apply missing migrations
prd migrate latest
```

### Corrupted Database
```bash
# Backup existing database
cp tools/prd.db tools/prd.db.backup

# Recreate database (WARNING: loses all data)
prd init --force

# Or restore from backup
cp tools/prd.db.backup tools/prd.db
```

### Migration Failed
```bash
# Check migration status
prd migrate status

# Manually inspect database
sqlite3 tools/prd.db ".schema"

# Rollback to previous version
prd migrate rollback <previous-version>

# Try applying migrations again
prd migrate latest
```

## Database Reconciliation

### Reconcile Database with Filesystem
```bash
# Detect and fix inconsistencies
prd reconcile
```

**What it does**:
- Checks database integrity
- Verifies task references are valid
- Detects orphaned or missing data
- Fixes inconsistencies automatically
- Reports issues found and fixed

**When to use**:
- After manual database edits
- If you suspect data corruption
- When file-based workflows get out of sync
- Before major migrations
- As part of database health checks

**Example Output**:
```
Reconciling database...
✓ Checked 150 tasks
✓ Checked 5 agents
✓ Fixed 2 orphaned dependencies
✓ Removed 1 invalid task reference
Database reconciliation complete.
```

## Database Maintenance

### Backup Database
```bash
# Create timestamped backup
cp tools/prd.db tools/prd.db.$(date +%Y%m%d_%H%M%S)

# Or simple backup
cp tools/prd.db tools/prd.db.backup
```

### Restore Database
```bash
# From timestamped backup
cp tools/prd.db.20250101_120000 tools/prd.db

# From simple backup
cp tools/prd.db.backup tools/prd.db
```

### Check Database Size
```bash
ls -lh tools/prd.db
```

### Inspect Database Directly
```bash
# Open SQLite CLI
sqlite3 tools/prd.db

# View schema
.schema

# View tables
.tables

# Query tasks
SELECT display_id, title, status FROM tasks;

# Exit
.quit
```

## Examples

### First Time User
```bash
# 1. Build
cd tools/prd
./build.sh  # Or: cargo build --release

# 2. Initialize
prd init

# 3. Verify
prd stats
# Output: 0 tasks, 0 agents

# 4. Create sample data
prd agent-create "my-agent"
prd create "My first task" --priority high
prd list
```

### Updating PRD Tool
```bash
# 1. Update code (git pull or subtree update)
cd tools/prd

# 2. Rebuild
cargo build --release

# 3. Check for new migrations
prd migrate status

# 4. Apply new migrations
prd migrate latest

# 5. Verify
prd stats
```

### Reset Everything
```bash
# WARNING: Destroys all data!

# 1. Backup first
cp tools/prd.db tools/prd.db.backup

# 2. Force reinit
prd init --force

# 3. Verify clean state
prd stats
# Output: 0 tasks, 0 agents
```

## Best Practices

1. **Backup Before Migrations**: Always backup before applying migrations
2. **Check Status First**: Run `prd migrate status` before `migrate latest`
3. **Never Edit Schema Manually**: Use migrations for schema changes
4. **Regular Backups**: Backup database before major changes
5. **Test Migrations**: Test migrations on a copy of the database first
6. **Version Control**: Keep migration files in version control
7. **Document Changes**: Add comments to custom migrations

## Database Schema

Key tables created by migrations:

- **tasks**: Core task data with display IDs
- **agents**: Agent registry with status and specializations
- **task_dependencies**: Links between tasks
- **acceptance_criteria**: Per-task checklists
- **task_logs**: Audit trail of changes
- **agent_progress**: Progress tracking
- **agent_metrics**: Performance metrics
- **migrations**: Schema version tracking

## Integration Notes

- Database is SQLite (single file, no server needed)
- Located at project root in `tools/prd.db`
- Migrations are SQL files in `tools/prd/migrations/`
- Schema version tracked in `migrations` table
- All PRD commands require `--database` flag with path
- Database can be backed up by copying the file
