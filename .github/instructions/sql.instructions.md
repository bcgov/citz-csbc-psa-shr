---
applyTo: "**/*.sql"
---

# SQL Coding Standards

- Use `DATETIME2(0)` for timestamps, never `DATETIME`
- Use `SYSUTCDATETIME()` for all timestamps (UTC)
- Use `NVARCHAR` for string columns, never `VARCHAR` (Unicode support)
- Use `ISNULL(col, default)` for NULL-safe comparisons in MERGE
- Terminate MERGE statements with semicolon
- Prefix MERGE with semicolon: `;MERGE`
- Always include `SET NOCOUNT ON` and `SET XACT_ABORT ON` in stored procedures
- Use `WITH (HOLDLOCK)` on MERGE target for concurrency safety
- Use `CREATE OR ALTER PROCEDURE` for idempotent deployments
- Include `GO` after procedure definitions
- Never use physical `DELETE` in MERGE — use soft delete (`IsActive = 0`)
- SQL file naming: lowercase with double underscore separator (`entity__purpose.sql`)