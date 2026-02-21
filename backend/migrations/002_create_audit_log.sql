-- Migration: 002_create_audit_log.sql
-- Creates `audit_logs` table used to record consent and deletion events.

BEGIN;

CREATE TABLE IF NOT EXISTS audit_logs (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  action VARCHAR(100) NOT NULL,
  details TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- If using Postgres, add foreign key constraint (optional)
-- ALTER TABLE audit_logs ADD CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;

COMMIT;

-- SQLite equivalent (if you're using SQLite, run the following instead):
-- CREATE TABLE IF NOT EXISTS audit_logs (
--   id INTEGER PRIMARY KEY AUTOINCREMENT,
--   user_id INTEGER NOT NULL,
--   action TEXT NOT NULL,
--   details TEXT,
--   timestamp DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL
-- );
