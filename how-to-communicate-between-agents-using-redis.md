# How to Communicate Between Claude Code Agents Using Redis

## Overview

When working with multiple Claude Code sub-agents running in parallel or sequentially, Redis provides a robust mechanism for sharing state, passing data, and coordinating work between agents. This guide explains how to leverage Redis for inter-agent communication.

## Why Use Redis for Agent Communication?

- **Stateless Agents**: Each agent invocation is independent and cannot directly share memory
- **Asynchronous Work**: Agents may run in parallel and need to share results
- **Persistent State**: Data needs to survive beyond a single agent's lifecycle
- **Key-Value Simplicity**: Redis provides simple get/set operations perfect for message passing

## Prerequisites

1. **Redis Server Running**
   ```bash
   # Start Redis locally
   redis-server

   # Or using Docker
   docker run -d -p 6379:6379 redis:latest
   ```

2. **Redis CLI Access**
   ```bash
   redis-cli
   ```

## Communication Patterns

### 1. Task Queue Pattern

Use Redis lists to create a task queue where agents can push and pop work items.

```bash
# Agent 1: Push tasks to queue
redis-cli LPUSH agent:tasks "analyze_file:src/main.ts"
redis-cli LPUSH agent:tasks "analyze_file:src/utils.ts"

# Agent 2: Pop and process tasks
redis-cli RPOP agent:tasks
# Returns: "analyze_file:src/main.ts"
```

### 2. Shared State Pattern

Use Redis hashes to store structured data that multiple agents can read/write.

```bash
# Agent 1: Store analysis results
redis-cli HSET analysis:results "file_count" "42"
redis-cli HSET analysis:results "total_lines" "1337"
redis-cli HSET analysis:results "status" "in_progress"

# Agent 2: Read shared state
redis-cli HGETALL analysis:results
# Returns all key-value pairs

# Agent 3: Update specific field
redis-cli HSET analysis:results "status" "completed"
```

### 3. Pub/Sub Pattern

Use Redis pub/sub for real-time event notifications between agents.

```bash
# Agent 1: Subscribe to events (blocking)
redis-cli SUBSCRIBE agent:events

# Agent 2: Publish events
redis-cli PUBLISH agent:events "task_completed:file_analysis"
redis-cli PUBLISH agent:events "error:invalid_syntax"
```

### 4. Atomic Counters

Use Redis counters for coordination (e.g., tracking completed work).

```bash
# Initialize counter
redis-cli SET files:processed 0

# Each agent increments when done
redis-cli INCR files:processed

# Check progress
redis-cli GET files:processed
```

### 5. Key-Value Message Passing

Simple pattern for passing results between specific agents.

```bash
# Agent 1: Store result with expiration
redis-cli SETEX "agent:search:results" 3600 '{"files": ["a.ts", "b.ts"]}'

# Agent 2: Retrieve result
redis-cli GET "agent:search:results"

# Agent 2: Delete after processing
redis-cli DEL "agent:search:results"
```

## Practical Examples

### Example 1: Parallel File Analysis

```bash
# Main agent: Discover files and create tasks
redis-cli DEL analysis:queue  # Clear old queue
redis-cli LPUSH analysis:queue "analyze:src/app.ts"
redis-cli LPUSH analysis:queue "analyze:src/utils.ts"
redis-cli LPUSH analysis:queue "analyze:src/config.ts"
redis-cli SET analysis:total 3

# Sub-agent 1, 2, 3 (run in parallel):
# Each agent pops a task, processes it, and stores results
redis-cli RPOP analysis:queue  # Get next file
# ... process file ...
redis-cli HSET analysis:results "src/app.ts" '{"lines": 100, "functions": 5}'
redis-cli INCR analysis:completed

# Main agent: Check completion
redis-cli GET analysis:completed  # Check if == analysis:total
redis-cli HGETALL analysis:results  # Retrieve all results
```

### Example 2: Sequential Pipeline

```bash
# Agent 1: Search for files
redis-cli SET pipeline:step1:status "running"
# ... search logic ...
redis-cli SET pipeline:step1:results '["file1.ts", "file2.ts"]'
redis-cli SET pipeline:step1:status "completed"

# Agent 2: Wait for step 1, then analyze
status=$(redis-cli GET pipeline:step1:status)
if [ "$status" = "completed" ]; then
  files=$(redis-cli GET pipeline:step1:results)
  # ... analyze files ...
  redis-cli SET pipeline:step2:results '{"total_lines": 500}'
  redis-cli SET pipeline:step2:status "completed"
fi

# Agent 3: Wait for step 2, then generate report
status=$(redis-cli GET pipeline:step2:status)
if [ "$status" = "completed" ]; then
  results=$(redis-cli GET pipeline:step2:results)
  # ... generate report ...
fi
```

### Example 3: Error Handling & Coordination

```bash
# Agent 1: Set up error tracking
redis-cli DEL errors:list
redis-cli SET task:status "running"

# Any agent: Report errors
redis-cli LPUSH errors:list "Agent 2: File not found - config.ts"
redis-cli LPUSH errors:list "Agent 3: Syntax error in utils.ts"

# Main agent: Check for errors
error_count=$(redis-cli LLEN errors:list)
if [ "$error_count" -gt 0 ]; then
  redis-cli SET task:status "failed"
  redis-cli LRANGE errors:list 0 -1  # Get all errors
fi
```

## Best Practices

### 1. Use Namespaced Keys

Prevent key collisions by using prefixes:
```bash
# Good
redis-cli SET "myproject:agent1:result" "value"
redis-cli SET "myproject:task:status" "running"

# Avoid
redis-cli SET "result" "value"
```

### 2. Set Expiration Times

Prevent memory leaks by setting TTL on temporary data:
```bash
# Auto-expire after 1 hour (3600 seconds)
redis-cli SETEX "session:temp:data" 3600 "value"

# Or set expiration on existing key
redis-cli SET "mykey" "value"
redis-cli EXPIRE "mykey" 3600
```

### 3. Clean Up After Completion

```bash
# Delete temporary keys when done
redis-cli DEL "agent:task:queue"
redis-cli DEL "agent:temp:results"

# Or delete all keys matching pattern (use carefully!)
redis-cli --scan --pattern "agent:temp:*" | xargs redis-cli DEL
```

### 4. Use Atomic Operations

For counters and flags, use atomic operations:
```bash
# Atomic increment
redis-cli INCR counter

# Atomic decrement
redis-cli DECR counter

# Conditional set (only if not exists)
redis-cli SETNX "lock:resource" "agent1"
```

### 5. Handle JSON Data

For complex data structures, use JSON strings:
```bash
# Store JSON
redis-cli SET "config" '{"timeout": 30, "retry": 3}'

# Retrieve and parse (in agent logic)
config=$(redis-cli GET "config")
# Parse JSON in your agent's environment
```

## Integration with Claude Code Agents

### In Your Agent Prompt

When launching sub-agents, include Redis instructions:

```
You are a file analysis agent. Use Redis to coordinate with other agents:

1. Get your task: redis-cli RPOP analysis:queue
2. Process the file
3. Store results: redis-cli HSET results "[filename]" "[json_data]"
4. Increment counter: redis-cli INCR completed
5. Report errors: redis-cli LPUSH errors "[error_message]"

Redis server: localhost:6379
```

### Workflow Example

```bash
# Main task: Analyze codebase with 3 parallel agents

# Step 1: Setup (in main flow)
redis-cli DEL analysis:queue analysis:results analysis:completed analysis:errors
redis-cli LPUSH analysis:queue "file1.ts" "file2.ts" "file3.ts"
redis-cli SET analysis:total 3

# Step 2: Launch parallel agents
# Agent 1, 2, 3 each:
# - RPOP analysis:queue (get file)
# - Analyze file
# - HSET analysis:results [file] [results]
# - INCR analysis:completed

# Step 3: Wait and collect (in main flow)
while [ $(redis-cli GET analysis:completed) -lt 3 ]; do
  sleep 1
done

# Step 4: Retrieve all results
redis-cli HGETALL analysis:results

# Step 5: Cleanup
redis-cli DEL analysis:queue analysis:results analysis:completed
```

## Debugging Tips

### Monitor Redis Activity

```bash
# Watch all commands in real-time
redis-cli MONITOR

# Check all keys
redis-cli KEYS "*"

# Inspect key type
redis-cli TYPE "mykey"

# Check TTL
redis-cli TTL "mykey"
```

### Common Issues

1. **Keys not found**: Check if key expired or was deleted
2. **Stale data**: Set appropriate TTL values
3. **Memory issues**: Monitor with `redis-cli INFO memory`
4. **Race conditions**: Use atomic operations (INCR, SETNX, etc.)

## Advanced Patterns

### Distributed Locks

```bash
# Agent attempts to acquire lock
if redis-cli SETNX "lock:resource" "agent1" | grep -q "1"; then
  # Lock acquired, set expiration for safety
  redis-cli EXPIRE "lock:resource" 30

  # ... do work ...

  # Release lock
  redis-cli DEL "lock:resource"
else
  # Lock already held by another agent
  echo "Resource locked"
fi
```

### Progress Tracking

```bash
# Setup
redis-cli SET progress:total 100
redis-cli SET progress:current 0

# Agents update progress
redis-cli INCRBY progress:current 10

# Check percentage
current=$(redis-cli GET progress:current)
total=$(redis-cli GET progress:total)
percentage=$((current * 100 / total))
echo "Progress: $percentage%"
```

## Summary

Redis provides a powerful, simple way for Claude Code agents to:
- Share data and state
- Coordinate work through queues
- Track progress with counters
- Handle errors collectively
- Implement complex workflows

Use these patterns to build sophisticated multi-agent systems that work together efficiently!
