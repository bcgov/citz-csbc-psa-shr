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

## Report Metadata Columns
- Some APIs include per-run report metadata (e.g., ReportName, RunDate)
- These MUST be:
  - Present in staging table (for data lineage)
  - ABSENT from target table
  - ABSENT from audit table
  - ABSENT from MERGE comparison clauses
  - ABSENT from HASHBYTES calculations
- Add a comment in staging DDL explaining why they are excluded downstream

## JSON Field Name Comments
- When JSON field names differ from SQL column names, add inline comments
  in staging DDL: `PosRole NVARCHAR(255) NULL, -- JSON: "pos role"`