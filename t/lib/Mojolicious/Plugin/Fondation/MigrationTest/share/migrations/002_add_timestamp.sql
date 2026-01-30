-- Migration 002: Add timestamp column
ALTER TABLE test_table ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;