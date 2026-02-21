Migration: Drop legacy social tables
===================================

What this migration does
------------------------

This migration drops the legacy `social_activities` and `social_accounts` tables. The application
no longer automatically fetches or stores data from connected social accounts; instead it uses
explicit user uploads (`/social/upload`).

Pre-apply checklist
-------------------
- Back up your database (required). Do NOT proceed without a verified backup.
- Verify no downstream systems still rely on the `social_accounts` or `social_activities` tables.

How to apply
------------

PostgreSQL (recommended):

```bash
# Example: export DATABASE_URL=postgres://user:pass@host:5432/dbname
psql "$DATABASE_URL" -f 001_drop_social_accounts.sql
```

SQLite (local dev):

```bash
# Example: sqlite3 ./dev.db ".read ./backend/migrations/001_drop_social_accounts.sql"
sqlite3 <path-to-your-sqlite-db> ".read 001_drop_social_accounts.sql"
```

Rollback
--------
This migration is destructive. Restoring requires restoring from backup. If you need a non-destructive
approach first, consider renaming the tables instead of dropping them.

Questions
---------
If you want I can produce an Alembic-style migration instead.

Non-destructive rename (recommended)
-----------------------------------
Instead of dropping the tables immediately, you can rename them so data is retained and the app
no longer uses them. A sample rename migration is provided at:

- `001_rename_social_tables.sql`

This renames `social_accounts` -> `archived_social_accounts` and
`social_activities` -> `archived_social_activities`.

Apply the rename migration with:

```bash
psql "$DATABASE_URL" -f 001_rename_social_tables.sql
```

Or for SQLite:

```bash
sqlite3 <path-to-your-sqlite-db> ".read ./backend/migrations/001_rename_social_tables.sql"
```

If you confirm the rename is fine, you can later run the drop migration `001_drop_social_accounts.sql` or keep
the archived tables for audit purposes.
