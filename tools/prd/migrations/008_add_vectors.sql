-- Migration 008: Add vector embeddings support
-- Vector embeddings table (384 dimensions for bge-small-en-v1.5)

CREATE TABLE IF NOT EXISTS embeddings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL,       -- 'task', 'code', 'doc'
    content_id TEXT NOT NULL,         -- task ID, file path, etc.
    chunk_index INTEGER DEFAULT 0,    -- chunk number for split content
    content_preview TEXT,             -- first 200 chars of content for display
    content_hash TEXT NOT NULL,       -- SHA256 hash for change detection
    embedding BLOB NOT NULL,          -- 384-dim float32 vector (1536 bytes)
    metadata TEXT,                    -- JSON: {line_start, line_end, file_type, etc.}
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(content_type, content_id, chunk_index)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_embeddings_type ON embeddings(content_type);
CREATE INDEX IF NOT EXISTS idx_embeddings_content_id ON embeddings(content_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_hash ON embeddings(content_hash);

-- Vector index statistics table
CREATE TABLE IF NOT EXISTS vector_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL UNIQUE,
    total_items INTEGER DEFAULT 0,
    total_chunks INTEGER DEFAULT 0,
    last_indexed_at TEXT,
    index_duration_ms INTEGER
);

-- Insert initial stats rows
INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('task', 0, 0);
INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('code', 0, 0);
INSERT OR IGNORE INTO vector_stats (content_type, total_items, total_chunks) VALUES ('doc', 0, 0);

-- Rollback support
-- DROP TABLE IF EXISTS embeddings;
-- DROP TABLE IF EXISTS vector_stats;
