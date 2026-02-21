-- Migration: 001_drop_social_accounts.sql
-- Drops legacy social scraping tables no longer used by the app.
-- IMPORTANT: Back up your database before running this migration.

BEGIN;

-- Drop child table first to avoid FK errors
DROP TABLE IF EXISTS social_activities;

-- Then drop the social_accounts table
DROP TABLE IF EXISTS social_accounts;

COMMIT;

-- Notes:
-- - For Postgres run: psql "$DATABASE_URL" -f 001_drop_social_accounts.sql
-- - For SQLite run: sqlite3 <path-to-db> ".read 001_drop_social_accounts.sql"
