-- Migration 001: Create test table
CREATE TABLE test_table (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    value INTEGER DEFAULT 0
);