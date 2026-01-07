# PRD Tool - Quick Start Guide

Get up and running with the PRD tool in under 10 minutes!

## Installation (5 minutes)

### 1. Install Rust (if not already installed)
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 2. Build the tool
```bash
cd tools/prd
cargo build --release
```

### 3. Initialize database
```bash
./target/release/prd init
```

### 4. Add to PATH (optional but recommended)
Add these lines to your `~/.zshrc` or `~/.bashrc`:
```bash
alias prd='~/Code/Github/infinite-stories/tools/prd/target/release/prd'
alias prd-dash='~/Code/Github/infinite-stories/tools/prd/target/release/prd-dashboard'
```

Then reload: `source ~/.zshrc`

## Your First Tasks (2 minutes)

### Create tasks with human-readable IDs
```bash
prd create "Setup development environment" --priority high
# Output: ID: #1

prd create "Configure CI/CD" --epic "DevOps" --priority medium
# Output: ID: #2

prd create "Write tests" --epic "DevOps"
# Output: #3
```

### List all tasks
```bash
prd list
# Shows: #1, #2, #3 (not long UUIDs!)
```

### View task details
```bash
prd show "#1"
# or just:
prd show 1
```

### Add acceptance criteria
```bash
prd ac "#1" add "All dependencies installed"
prd ac "#1" add "Environment variables configured"
prd ac "#1" add "Local server runs successfully"
prd ac "#1" list
```

## Working with Epics (3 minutes)

### Create an epic
```bash
prd create "User Authentication" --epic "Auth System" --priority critical
prd create "Password Reset" --epic "Auth System"
prd create "OAuth Integration" --epic "Auth System" --priority high
```

### View epic progress
```bash
prd epics
# Output:
# Auth System - 0/3 tasks (0%)
```

### Filter by epic
```bash
prd list --epic "Auth System"
```

## Task Dependencies (3 minutes)

### Set up a workflow
```bash
# Create tasks
prd create "Database Schema" --priority critical
# ID: #4

prd create "API Endpoints" --priority high
# ID: #5

prd create "Frontend Integration"
# ID: #6

# Define order
prd depends "#5" --on "#4"  # API needs DB first
prd depends "#6" --on "#5"  # Frontend needs API

# See dependency graph
prd depends "#5" --list
```

### Find what's ready to work on
```bash
prd ready
# Shows only #4 initially (no dependencies)
```

### After completing #4
```bash
prd update "#4" completed
prd ready
# Now shows #5 (dependency satisfied)
```

## Agent Workflow (5 minutes)

### 1. Create agents
```bash
prd agent-create "backend-agent"
# Output: ID: A1

prd agent-create "frontend-agent"
# Output: ID: A2

prd agent-create "qa-agent"
# Output: ID: A3
```

### 2. List agents
```bash
prd agent-list
```

### 3. Assign work
```bash
# Assign to agent
prd assign "#5" A1
prd assign "#6" A2

# Or use agent name
prd assign "#1" backend-agent
```

### 4. Start working (sync)
```bash
prd sync A1 "#5"
# Agent A1 (backend-agent) is now working on task #5
```

### 5. Check off acceptance criteria
```bash
prd ac "#5" add "All endpoints tested"
prd ac "#5" add "API documented"
prd ac "#5" list

# Mark as done
prd ac "#5" check 1
prd ac "#5" list
# Shows: ☑ All endpoints tested
```

### 6. Complete task
```bash
prd update "#5" completed
```

## Complete Example Workflow (10 minutes)

```bash
# 1. Initialize project
prd init

# 2. Create epic with tasks
prd create "User Authentication" --epic "Auth System" --priority critical
# ID: #1

prd create "OAuth Integration" --epic "Auth System" --priority high
# ID: #2

prd create "Password Reset" --epic "Auth System"
# ID: #3

# 3. Set dependencies
prd depends "#2" --on "#1"  # OAuth needs auth
prd depends "#3" --on "#1"  # Reset needs auth

# 4. Add acceptance criteria to #1
prd ac "#1" add "All unit tests pass"
prd ac "#1" add "Security audit complete"
prd ac "#1" add "Documentation updated"

# 5. Create agents
prd agent-create "auth-backend-agent"  # A1
prd agent-create "qa-agent"            # A2

# 6. Check what's ready
prd ready
# Shows: #1 (no dependencies)

# 7. Start work
prd sync A1 "#1"

# 8. Track progress
prd ac "#1" check 1  # Tests pass
prd ac "#1" check 2  # Audit complete
prd ac "#1" check 3  # Docs updated

# 9. Complete task
prd update "#1" completed

# 10. Check what's ready now
prd ready
# Shows: #2 and #3 (dependency #1 done)

# 11. View epic progress
prd epics
# Auth System - 1/3 tasks (33%)

# 12. Overall stats
prd stats
```

## Dashboard (1 minute)

Launch the real-time dashboard in a separate terminal:

```bash
prd-dash
```

The dashboard shows:
- 📊 Overall statistics and progress
- 🔥 Active tasks (in progress)
- ⚠️ Blocked tasks
- 👥 Agent activity
- 📝 Recent activity log
- 📋 High-priority upcoming tasks

Press `Ctrl+C` to exit.

## Key Features Summary

### ✨ Display IDs
- **Before**: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
- **Now**: `#42` for tasks, `A5` for agents
- All commands accept the new format!

### 🎯 Epics
- Group related tasks: `--epic "Feature Name"`
- View progress: `prd epics`
- Filter: `prd list --epic "Name"`

### 🔗 Dependencies
- Define order: `prd depends "#2" --on "#1"`
- See ready tasks: `prd ready`
- Automatic blocking prevention

### ✅ Acceptance Criteria
- Define "done": `prd ac "#42" add "Criterion"`
- Check off: `prd ac "#42" check 1`
- View checklist: `prd ac "#42" list`

### 📊 Advanced Filtering
```bash
prd list --epic "Auth"                    # By epic
prd list --priority critical              # By priority
prd list --no-agent                       # Unassigned
prd list --status pending --priority high # Combined
```

## Common Commands Cheat Sheet

| Command | Example | What it does |
|---------|---------|--------------|
| `init` | `prd init` | Create new database |
| `create` | `prd create "Task" --epic "Epic"` | Create task |
| `list` | `prd list --epic "Name"` | List/filter |
| `show` | `prd show "#42"` | Task details |
| `update` | `prd update "#42" completed` | Change status |
| `depends` | `prd depends "#2" --on "#1"` | Add dependency |
| `ready` | `prd ready` | Show available |
| `ac` | `prd ac "#42" add "Test"` | Add criterion |
| `epics` | `prd epics` | List epics |
| `stats` | `prd stats` | Statistics |
| `sync` | `prd sync A1 "#42"` | Start work |
| `agent-create` | `prd agent-create "name"` | Register agent |
| `agent-list` | `prd agent-list` | List agents |

## Migration from Existing Database

If you already have a PRD database:

```bash
# Check current version
prd migrate status

# Run migrations (SAFE - preserves all data)
prd migrate latest

# Verify
prd list    # All tasks now have #1, #2, #3 IDs
prd agent-list  # All agents now have A1, A2, A3 IDs
```

**What happens:**
- ✅ All tasks get sequential display IDs
- ✅ All agents get sequential display IDs
- ✅ All existing data 100% preserved
- ✅ UUIDs still work (backward compatible)

## Rust Library Integration (Recommended for Agents)

For automated agent workflows, use the Rust library:

### Add to Cargo.toml
```toml
[dependencies]
prd-tool = { path = "../tools/prd" }
anyhow = "1.0"
```

### Basic Agent
```rust
use prd_tool::{PRDClient, Priority, TaskStatus};

fn main() -> anyhow::Result<()> {
    let client = PRDClient::new("tools/prd.db")?;
    let agent_name = "my-agent";

    // Register
    client.create_agent(agent_name.to_string())?;

    // Get next high-priority task
    let pending = client.list_tasks(Some(TaskStatus::Pending))?;
    if let Some(task) = pending.into_iter()
        .filter(|t| t.priority == Priority::High || t.priority == Priority::Critical)
        .next()
    {
        // Start work
        client.sync_agent(agent_name, &task.id)?;

        // Do work...
        println!("Working on: {}", task.title);

        // Complete
        client.complete_task(&task.id, agent_name)?;
    }

    Ok(())
}
```

### Run Examples
```bash
cd tools/prd

# Simple agent
cargo run --example simple_agent

# Multi-agent workflow
cargo run --example multi_agent_workflow
```

## Tips & Tricks

### 1. ID Shortcuts
```bash
prd show "#42"    # ✅ Recommended
prd show "42"     # ✅ Also works
prd show 42       # ✅ Works too
prd sync A5 "#42" # ✅ Agent and task
```

### 2. Epic-Driven Development
```bash
# Create all tasks for a feature in one epic
prd create "Task 1" --epic "Feature X"
prd create "Task 2" --epic "Feature X"
prd create "Task 3" --epic "Feature X"

# Work on one epic at a time
prd list --epic "Feature X" --status pending
```

### 3. Dependency Chains
```bash
# Create ordered workflow
prd depends "#2" --on "#1"
prd depends "#3" --on "#2"
prd depends "#4" --on "#3"

# Always work on ready tasks
prd ready  # Smart queue
```

### 4. Definition of Done
```bash
# Always add acceptance criteria
prd ac "#42" add "Tests pass"
prd ac "#42" add "Code reviewed"
prd ac "#42" add "Docs updated"

# Check off as you go
prd ac "#42" check 1
prd ac "#42" check 2
```

### 5. Multi-Agent Coordination
```bash
# Each agent gets next available task
prd ready | head -1  # Get top task

# Agents can work in parallel
prd sync A1 "#10"
prd sync A2 "#11"
prd sync A3 "#12"
```

## Common Workflows

### Bug Triage
```bash
prd create "Login fails on Safari" --priority critical --epic "Bugs Q4"
prd ac "#new" add "Bug reproduced"
prd ac "#new" add "Root cause identified"
prd ac "#new" add "Fix implemented"
prd ac "#new" add "Verified on Safari"
prd sync dev-agent "#new"
```

### Sprint Planning
```bash
# Create sprint epic
for task in "Story 1" "Story 2" "Story 3"; do
    prd create "$task" --epic "Sprint 42"
done

# Track progress
prd epics
prd list --epic "Sprint 42"
```

### Feature Development
```bash
# Create feature
prd create "Real-time Chat" --epic "Chat" --priority high
# ID: #100

# Break down
prd create "WebSocket server" --parent "#100" --priority critical  # #101
prd create "Chat UI" --parent "#100"                               # #102
prd create "Message DB" --parent "#100"                            # #103

# Dependencies
prd depends "#102" --on "#101"  # UI needs server

# Assign
prd sync backend-dev "#101"
```

## Troubleshooting

**"Task not found"**
```bash
# Use correct ID format
prd show "#42"   # Correct
prd show 42      # Also works
```

**"Circular dependency detected"**
```bash
# Review dependencies
prd depends "#task" --list

# Remove if needed (manual SQL for now)
sqlite3 tools/prd.db "DELETE FROM task_dependencies WHERE task_display_id = 42"
```

**"Database already exists"**
```bash
# Use existing database
prd list

# Or force recreate (DELETES ALL DATA!)
prd init --force
```

## Next Steps

- **Full docs**: Read [README.md](README.md)
- **Examples**: Check `examples/` directory
- **Dashboard**: Run `prd-dash` for real-time monitoring
- **Help**: Run `prd --help` or `prd <command> --help`

---

**Quick Reference Card**

```bash
# Setup
prd init                                    # New database

# Tasks
prd create "Title" --epic "Name" -p high   # Create
prd list --epic "Name" --no-agent          # Filter
prd show "#42"                             # Details
prd update "#42" completed                 # Update

# Dependencies & AC
prd depends "#2" --on "#1"                 # Add dependency
prd ready                                  # Show available
prd ac "#42" add "Criterion"               # Add AC
prd ac "#42" check 1                       # Mark done

# Agents
prd agent-create "name"                    # Create (A1)
prd sync A1 "#42"                          # Start work

# Progress
prd epics                                  # Epic progress
prd stats                                  # Overall stats
prd-dash                                   # Live dashboard
```

Happy task managing! 🚀
