-- Migration: 001_rename_social_tables.sql
-- Non-destructive rename of legacy social tables.
-- This migration renames `social_accounts` -> `archived_social_accounts`
-- and `social_activities` -> `archived_social_activities` so data remains
-- available while removing active references from the application.

BEGIN;

-- Rename parent table first (Postgres/SQLite support ALTER TABLE ... RENAME TO)
ALTER TABLE IF EXISTS social_accounts RENAME TO archived_social_accounts;

-- Rename child table
ALTER TABLE IF EXISTS social_activities RENAME TO archived_social_activities;

COMMIT;

-- Notes:
-- - This is reversible by swapping the names back (rename archived_* -> original names).
-- - For Postgres: psql "$DATABASE_URL" -f 001_rename_social_tables.sql
-- - For SQLite: sqlite3 <path-to-db> ".read 001_rename_social_tables.sql"
