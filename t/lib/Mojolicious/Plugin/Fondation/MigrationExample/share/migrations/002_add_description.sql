-- Migration 002: Add description column to example data table
-- This migration will be automatically copied to the application's
-- share/migrations/ directory when the plugin is loaded by Fondation.

ALTER TABLE example_data ADD COLUMN description TEXT;

-- Update existing rows with a default description
UPDATE example_data SET description = 'No description provided' WHERE description IS NULL;