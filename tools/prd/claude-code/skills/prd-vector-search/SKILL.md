---
name: prd-vector-search
description: Semantic vector search and indexing for PRD Tool. Use when the user needs to search tasks, code, or documentation semantically, find similar content, or index project content for search. Supports cosine similarity search with configurable thresholds.
allowed-tools: Bash
---

# PRD Vector Search

This skill enables semantic search across tasks, code, and documentation using local embeddings (BGE-small-en-v1.5, 384 dimensions).

## Database Location

**IMPORTANT**: Always run commands from the project root and use the relative database path:
```bash
./tools/prd/target/release/prd --database tools/prd.db vector <command>
```

For brevity in examples below, we'll use `prd` but you must always use the full relative path with `--database tools/prd.db`.

## Indexing Content

Before searching, content must be indexed. The indexer creates embeddings for tasks, code files, and documentation.

### Index Everything
```bash
prd vector index all
```

### Index Specific Content Types
```bash
# Index only tasks
prd vector index tasks

# Index code files
prd vector index code --path ./src --include "*.swift,*.ts,*.rs"

# Index documentation
prd vector index docs --path ./docs
```

### Force Re-Index
```bash
# Re-index everything (ignores cache)
prd vector index all --force

# Re-index specific type
prd vector index code --force --path ./src
```

### Index Options
- `--path <PATH>`: Directory to index (for code/docs)
- `--include <PATTERNS>`: File patterns to include (e.g., "*.rs", "*.ts", "*.swift")
- `--force`: Force re-index everything (ignore content hash cache)

## Semantic Search

Search across indexed content using natural language queries.

### Basic Search
```bash
prd vector search "authentication flow"
prd vector search "how to generate stories"
prd vector search "error handling patterns"
```

### Filter by Content Type
```bash
# Search only in tasks
prd vector search "user authentication" --type tasks

# Search only in code
prd vector search "API client implementation" --type code

# Search only in docs
prd vector search "deployment instructions" --type docs
```

### Adjust Results
```bash
# Limit results
prd vector search "database queries" --limit 5

# Set similarity threshold (0.0 to 1.0, default 0.5)
prd vector search "SwiftUI views" --threshold 0.7
```

### Search Options
- `--type <TYPE>`: Filter by type: `tasks`, `code`, `docs`
- `--limit <N>`: Number of results (default: 10)
- `--threshold <FLOAT>`: Minimum similarity threshold 0.0-1.0 (default: 0.5)

## Find Similar Content

Find content similar to a specific task - useful for finding related code or documentation.

### Basic Similar Search
```bash
# Find content similar to task #42
prd vector similar "#42"
```

### Include Code and Docs
```bash
# Find similar code
prd vector similar "#42" --code

# Find similar documentation
prd vector similar "#42" --docs

# Find both
prd vector similar "#42" --code --docs
```

### Adjust Results
```bash
prd vector similar "#42" --limit 10
```

### Similar Options
- `--code`: Include code file matches
- `--docs`: Include documentation matches
- `--limit <N>`: Number of results (default: 5)

## View Indexing Statistics

```bash
prd vector stats
```

Shows:
- Total indexed items by type
- Index size
- Last index time
- Content hash cache status

## Clear Indexes

```bash
# Clear all vector indexes
prd vector clear
```

**Warning**: This removes all indexed content. You'll need to re-index before searching.

## Best Practices

1. **Index First**: Always index content before searching
2. **Re-index After Changes**: Run `prd vector index` after significant code or doc changes
3. **Use Specific Types**: Filter by `--type` for faster, more relevant results
4. **Adjust Threshold**: Lower threshold (0.3-0.5) for broader results, higher (0.7-0.9) for precise matches
5. **Incremental Indexing**: The indexer uses content hashing - unchanged files are skipped automatically

## Example Workflows

### Setup Project Indexing
```bash
# Initial full index
prd vector index all --path . --include "*.swift,*.ts,*.md"

# Check stats
prd vector stats
```

### Find Code for a Task
```bash
# Find code related to task #15
prd vector similar "#15" --code --limit 10

# Search for implementation patterns
prd vector search "story generation service" --type code
```

### Discover Related Documentation
```bash
# Find docs related to a task
prd vector similar "#42" --docs

# Search documentation
prd vector search "API authentication" --type docs
```

### Research Before Implementation
```bash
# Before working on a new feature, find related content
prd vector search "user preferences storage" --limit 20

# Find similar past tasks
prd vector search "settings view implementation" --type tasks
```

## Technical Details

- **Embeddings**: BGE-small-en-v1.5 (384 dimensions)
- **Storage**: SQLite BLOB format (1536 bytes per vector)
- **Similarity**: Cosine similarity
- **Change Detection**: SHA-256 content hashing for incremental indexing
- **Text Processing**: UTF-8 safe chunking with code-aware boundaries
