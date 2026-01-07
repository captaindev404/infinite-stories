# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PRD Tool is a Rust-based CLI for managing tasks, agents, and dependencies across development teams and AI agents. It provides human-readable IDs (#1, A1), epic grouping, task dependencies, acceptance criteria, progress tracking, and real-time monitoring.

## Build & Run Commands

### Building
```bash
# Release build (recommended)
cargo build --release
# Or use convenience script
./build.sh

# Development build
cargo build

# Run tests
cargo test
```

### Running
```bash
# Main CLI
./target/release/prd <command>

# Dashboard
./target/release/prd-dashboard [db_path] [refresh_seconds]
```

### Common Development Commands
```bash
# Initialize database
prd init [--force]

# Run migrations
prd migrate latest
prd migrate status

# Create sample data
cargo run --example populate_migration_tasks
cargo run --example multi_agent_workflow
```

### Testing
```bash
# Run all tests
cargo test

# Test specific module
cargo test db::
cargo test suggestions::
cargo test watcher::

# Run with output
cargo test -- --nocapture
```

## Code Architecture

### Core Modules

**`src/db.rs`** (42K lines) - Central database layer
- Defines `Database` struct with SQLite connection
- Core types: `Task`, `Agent`, `TaskStatus`, `Priority`, `AgentStatus`
- All CRUD operations for tasks, agents, logs, and statistics
- Extensions in `db_extensions.rs`: `DependencyOps`, `AcceptanceCriteriaOps`

**`src/main.rs`** (74K lines) - CLI entry point
- Uses `clap` for command parsing with `Commands` enum
- All user-facing commands: create, list, show, assign, sync, complete, etc.
- Formatting helpers: `format_status()`, `format_priority()`, `format_agent_status()`
- Calls into `Database` methods for all operations

**`src/lib.rs`** - Public API for programmatic access
- `PRDClient` wrapper around `Database` for external use
- High-level methods: `sync_agent()`, `get_next_task()`, `complete_task()`
- Used by examples and agent integrations

**`src/resolver.rs`** - ID resolution system
- Converts human-readable IDs (#42, A5) to UUIDs
- `resolve_task_id()`, `resolve_agent_id()` - accept multiple formats
- `format_task_id()`, `format_agent_id()` - display formatting

### Feature Modules

**`src/dashboard/`** - Real-time TUI dashboard
- `ui.rs`: Terminal UI using `ratatui` and `crossterm`
- `state.rs`: Dashboard state management
- Displays active tasks, blocked tasks, agent activity, logs

**`src/watcher/`** - File watching automation (Phase 3)
- `file_watcher.rs`: Watches docs/tasks for completion documents
- `daemon.rs`: Background daemon management (start/stop/status)
- Uses `notify` crate for filesystem events

**`src/sync/`** - Document synchronization
- `doc_scanner.rs`: Scans for YAML completion documents
- `sync_engine.rs`: Processes completion documents to update DB
- `reconcile.rs`: Detects and fixes DB/filesystem inconsistencies

**`src/git/`** - Git integration (Phase 3)
- `sync.rs`: Scans commit history for task completions
- `hooks.rs`: Git hook management (post-commit auto-completion)
- Parses commit messages for task IDs and completion markers

**`src/hooks/`** - Custom hook system
- `config.rs`: Loads hooks from `.prd-hooks.toml`
- `executor.rs`: Executes shell commands on events
- Events: `on_task_complete`, `on_task_error`, `on_milestone_reached`

**`src/suggestions/`** - Agent-task matching (Phase 4)
- `agent_matcher.rs`: 4-factor weighted scoring system
  - Specialization match, task history, current load, priority weighting
  - Returns ranked `AgentRecommendation` list
- Used for `prd suggest <task-id>` command

**`src/notifications/`** - Desktop notifications (Phase 2)
- `notifier.rs`: System notifications using `notify-rust`
- `config.rs`: Notification settings and filters
- Triggers on: task completion, errors, milestones, blocked tasks

**`src/visualization/`** - Progress visualizations (Phase 4)
- `timeline.rs`: ASCII sprint timelines and burndown charts
- Renders task progress over time periods
- Used by `prd stats --visual` and `prd visualize`

**`src/errors/`** - Error handling (Phase 4)
- `context.rs`: Contextual error messages with suggestions
- Fuzzy matching for typos (e.g., "prd asign" → "Did you mean 'assign'?")
- Helpful error messages for common mistakes

**`src/batch/`** - Batch operations
- `complete.rs`: Bulk task completion from CLI, JSON, or CSV
- Parses task-agent mappings for batch updates
- Used by `prd complete-batch` command

**`src/migrations/`** - Database migrations
- `runner.rs`: Migration execution and rollback
- SQL files in `/migrations/`: 001-007 applied sequentially
- Track schema version in `migrations` table

### Database Schema

**Key tables:**
- `tasks`: Core task data with `display_id`, `title`, `status`, `priority`, `epic_name`, `parent_id`, `assigned_agent`
- `agents`: Agent registry with `display_id`, `name`, `status`, `current_task_id`, `specializations`
- `task_dependencies`: Links tasks with `task_display_id`, `depends_on_display_id`, `dependency_type`
- `acceptance_criteria`: Per-task checklists with `completed` flag
- `task_logs`: Audit trail of all task actions
- `agent_progress`: Progress reports with timestamp, percentage, message
- `agent_metrics`: Performance tracking (completion rate, success rate)
- `migrations`: Schema version tracking

**Migration files** in `/migrations/`:
1. `001_add_display_ids.sql` - Human-readable IDs
2. `002_add_dependencies.sql` - Task dependencies with circular detection
3. `003_add_acceptance_criteria.sql` - Checklists
4. `004_add_completion_fields.sql` - Duration tracking
5. `005_add_agent_progress.sql` - Real-time progress reporting
6. `006_add_agent_intelligence.sql` - Specializations and metrics
7. `007_add_sprints.sql` - Sprint support

## Key Patterns & Conventions

### ID System
- **Tasks**: Display ID `#1, #2` (stored as `display_id` i32), internal UUID
- **Agents**: Display ID `A1, A2` (stored as `display_id` i32), internal UUID
- All commands accept: `#42`, `42`, full UUID
- Use `resolver.rs` functions for conversion

### Status Flow
- Tasks: `pending` → `in_progress` → `review` → `completed`
  - Alternative: → `blocked` or → `cancelled`
- Agents: `idle` → `working` → `idle`
  - Alternative: → `blocked` or → `offline`

### Sync Operation
When `prd sync A1 "#42"`:
1. Agent status → `working`, set `current_task_id`
2. Task status → `in_progress`, set `assigned_agent`
3. Create task log entry
4. Update agent `last_active` timestamp

### Dependency System
- Uses display IDs (not UUIDs) for dependencies
- Circular dependency detection in `get_ready_tasks()` via recursive CTE
- `prd ready` shows tasks with all dependencies completed
- Supports `--on` (this depends on) and `--blocks` (this blocks) syntax

### Extension Traits
The codebase extends `rusqlite::Connection` with custom operations:
- `DependencyOps`: `add_dependency()`, `get_dependencies()`, `get_blocking_tasks()`, `get_ready_tasks()`
- `AcceptanceCriteriaOps`: `add_criterion()`, `list_criteria()`, `check_criterion()`, `uncheck_criterion()`

These are defined in `db_extensions.rs` and used throughout.

### Library vs CLI
- **Library**: `src/lib.rs` exports `PRDClient`, `Database`, types for programmatic use
- **CLI**: `src/main.rs` handles argument parsing and user interaction
- Examples use library interface (see `/examples/`)

## Adding New Features

### Adding a Command
1. Add variant to `Commands` enum in `main.rs`
2. Implement handler in `match cli.command` block
3. Add DB method in `db.rs` if needed
4. Update resolver if working with IDs
5. Add tests in relevant module

### Adding a Migration
1. Create `migrations/00X_description.sql`
2. Include both `CREATE/ALTER` and corresponding `DROP` statements
3. Test with `prd migrate latest` and `prd migrate rollback`
4. Migration runner auto-detects new files by number

### Adding Agent Features
1. Extend `Agent` struct in `db.rs`
2. Update `create_agent()` and `get_agent()` queries
3. Add migration for schema change
4. Update `AgentRow` display struct in `main.rs`
5. Consider impact on `PRDClient` API

### Adding Task Fields
1. Extend `Task` struct in `db.rs`
2. Update `create_task()`, `update_task_status()` queries
3. Add migration for schema change
4. Update `TaskRow` display struct and JSON serialization
5. Update `prd show` command formatting

## Testing Strategy

- Unit tests: inline `#[cfg(test)]` modules in each file
- Integration tests: `/examples/` for end-to-end workflows
- Use `:memory:` databases for isolated tests
- Test database operations with `tempfile` crate
- Dashboard/watcher tests in respective module test subdirectories

## Common Gotchas

1. **Display IDs vs UUIDs**: Always use resolver functions, never assume format
2. **Database handles**: Main CLI uses `Database` struct, library uses `PRDClient`
3. **Connection lifetimes**: Extensions borrow `&Connection`, don't store references
4. **Circular deps**: `get_ready_tasks()` uses recursive CTE, don't reimplement
5. **Migration order**: Numbers must be sequential, no gaps allowed
6. **Status transitions**: Some transitions may have side effects (e.g., completing task updates agent)

## Examples

Example agent implementations in `/examples/`:
- `simple_agent.rs`: Basic agent loop (get task, work, complete)
- `multi_agent_workflow.rs`: Coordinated multi-agent scenario
- `populate_migration_tasks.rs`: Generates test data for migrations

Run with:
```bash
cargo run --example simple_agent
cargo run --example multi_agent_workflow
```
