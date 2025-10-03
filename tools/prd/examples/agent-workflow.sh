#!/bin/bash

# Example: Agent Workflow Automation (Shell Script Reference)
# This script demonstrates how to use prd tool for agent coordination via shell
#
# NOTE: For production use, prefer the Rust library examples:
#   - examples/simple_agent.rs
#   - examples/multi_agent_workflow.rs
#
# Run with: cargo run --example simple_agent

set -e

PRD="../../target/release/prd"
DB_PATH="../../prd.db"

echo "🤖 PRD Tool - Agent Workflow Example"
echo "===================================="
echo ""

# Check if prd is built
if [ ! -f "$PRD" ]; then
    echo "❌ PRD tool not found. Run 'cargo build --release' first."
    exit 1
fi

# 1. Create a main task
echo "1️⃣ Creating main task..."
MAIN_TASK_OUTPUT=$($PRD --database "$DB_PATH" create "Migrate backend to Firebase" \
    --description "Complete migration from Supabase to Firebase" \
    --priority high)

MAIN_TASK_ID=$(echo "$MAIN_TASK_OUTPUT" | grep "ID:" | awk '{print $2}')
echo "   Created task: $MAIN_TASK_ID"
echo ""

# 2. Break down into subtasks
echo "2️⃣ Creating subtasks..."
SUBTASK_1=$($PRD --database "$DB_PATH" create "Setup Firebase project" \
    --parent "$MAIN_TASK_ID" --priority high | grep "ID:" | awk '{print $2}')
echo "   ✓ Subtask 1: $SUBTASK_1"

SUBTASK_2=$($PRD --database "$DB_PATH" create "Migrate authentication" \
    --parent "$MAIN_TASK_ID" --priority high | grep "ID:" | awk '{print $2}')
echo "   ✓ Subtask 2: $SUBTASK_2"

SUBTASK_3=$($PRD --database "$DB_PATH" create "Migrate database schema" \
    --parent "$MAIN_TASK_ID" --priority medium | grep "ID:" | awk '{print $2}')
echo "   ✓ Subtask 3: $SUBTASK_3"

SUBTASK_4=$($PRD --database "$DB_PATH" create "Update client SDKs" \
    --parent "$MAIN_TASK_ID" --priority medium | grep "ID:" | awk '{print $2}')
echo "   ✓ Subtask 4: $SUBTASK_4"

SUBTASK_5=$($PRD --database "$DB_PATH" create "Deploy and test" \
    --parent "$MAIN_TASK_ID" --priority critical | grep "ID:" | awk '{print $2}')
echo "   ✓ Subtask 5: $SUBTASK_5"
echo ""

# 3. Create agents
echo "3️⃣ Registering agents..."
$PRD --database "$DB_PATH" agent-create "firebase-setup-agent" 2>/dev/null || true
$PRD --database "$DB_PATH" agent-create "auth-migration-agent" 2>/dev/null || true
$PRD --database "$DB_PATH" agent-create "database-agent" 2>/dev/null || true
$PRD --database "$DB_PATH" agent-create "sdk-agent" 2>/dev/null || true
$PRD --database "$DB_PATH" agent-create "qa-agent" 2>/dev/null || true
echo "   ✓ 5 agents registered"
echo ""

# 4. Assign tasks to agents
echo "4️⃣ Assigning tasks to agents..."
$PRD --database "$DB_PATH" assign "$SUBTASK_1" firebase-setup-agent > /dev/null
echo "   ✓ Assigned setup to firebase-setup-agent"

$PRD --database "$DB_PATH" assign "$SUBTASK_2" auth-migration-agent > /dev/null
echo "   ✓ Assigned auth migration to auth-migration-agent"

$PRD --database "$DB_PATH" assign "$SUBTASK_3" database-agent > /dev/null
echo "   ✓ Assigned database to database-agent"

$PRD --database "$DB_PATH" assign "$SUBTASK_4" sdk-agent > /dev/null
echo "   ✓ Assigned SDK updates to sdk-agent"

$PRD --database "$DB_PATH" assign "$SUBTASK_5" qa-agent > /dev/null
echo "   ✓ Assigned testing to qa-agent"
echo ""

# 5. Simulate agent work
echo "5️⃣ Simulating agent work..."

# Firebase setup agent starts
$PRD --database "$DB_PATH" sync firebase-setup-agent "$SUBTASK_1" > /dev/null
echo "   🔄 firebase-setup-agent started working"
sleep 1

# Complete setup
$PRD --database "$DB_PATH" update "$SUBTASK_1" completed --agent firebase-setup-agent > /dev/null
$PRD --database "$DB_PATH" agent-status firebase-setup-agent idle > /dev/null
echo "   ✅ firebase-setup-agent completed setup"
sleep 1

# Auth migration starts
$PRD --database "$DB_PATH" sync auth-migration-agent "$SUBTASK_2" > /dev/null
echo "   🔄 auth-migration-agent started working"
sleep 1

# Database migration starts in parallel
$PRD --database "$DB_PATH" sync database-agent "$SUBTASK_3" > /dev/null
echo "   🔄 database-agent started working"
sleep 1

# Auth migration completes
$PRD --database "$DB_PATH" update "$SUBTASK_2" completed --agent auth-migration-agent > /dev/null
$PRD --database "$DB_PATH" agent-status auth-migration-agent idle > /dev/null
echo "   ✅ auth-migration-agent completed auth migration"

# Database hits a blocker
$PRD --database "$DB_PATH" update "$SUBTASK_3" blocked --agent database-agent > /dev/null
echo "   ⚠️  database-agent encountered a blocker"
sleep 1

# SDK agent starts
$PRD --database "$DB_PATH" sync sdk-agent "$SUBTASK_4" > /dev/null
echo "   🔄 sdk-agent started working"
sleep 1

# Database blocker resolved
$PRD --database "$DB_PATH" update "$SUBTASK_3" in_progress --agent database-agent > /dev/null
echo "   ✓ database-agent blocker resolved, continuing..."
sleep 1

# Database completes
$PRD --database "$DB_PATH" update "$SUBTASK_3" completed --agent database-agent > /dev/null
$PRD --database "$DB_PATH" agent-status database-agent idle > /dev/null
echo "   ✅ database-agent completed migration"

# SDK completes
$PRD --database "$DB_PATH" update "$SUBTASK_4" review --agent sdk-agent > /dev/null
echo "   📋 sdk-agent completed, in review"
sleep 1

# After review, SDK approved
$PRD --database "$DB_PATH" update "$SUBTASK_4" completed --agent sdk-agent > /dev/null
$PRD --database "$DB_PATH" agent-status sdk-agent idle > /dev/null
echo "   ✅ sdk-agent changes approved"

# QA starts final testing
$PRD --database "$DB_PATH" sync qa-agent "$SUBTASK_5" > /dev/null
echo "   🔄 qa-agent started testing"
sleep 1

# QA completes
$PRD --database "$DB_PATH" update "$SUBTASK_5" completed --agent qa-agent > /dev/null
$PRD --database "$DB_PATH" agent-status qa-agent idle > /dev/null
echo "   ✅ qa-agent completed testing"

# Mark main task as completed
$PRD --database "$DB_PATH" update "$MAIN_TASK_ID" completed > /dev/null
echo ""
echo "   🎉 Main task completed!"
echo ""

# 6. Show final statistics
echo "6️⃣ Final Statistics:"
echo ""
$PRD --database "$DB_PATH" stats

echo ""
echo "7️⃣ Task Details:"
echo ""
$PRD --database "$DB_PATH" show "$MAIN_TASK_ID"

echo ""
echo "===================================="
echo "✅ Workflow demonstration complete!"
echo ""
echo "To see the dashboard visualization, run:"
echo "  ../../target/release/prd-dashboard $DB_PATH"
