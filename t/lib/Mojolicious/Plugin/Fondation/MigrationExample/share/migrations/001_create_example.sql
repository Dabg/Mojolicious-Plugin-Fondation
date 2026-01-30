-- Migration 001: Create example table for MigrationExample plugin
-- This migration will be automatically copied to the application's
-- share/migrations/ directory when the plugin is loaded by Fondation.

CREATE TABLE example_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    value INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some example data
INSERT INTO example_data (name, value) VALUES ('initial', 100);