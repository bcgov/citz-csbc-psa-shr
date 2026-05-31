applyTo: "**/*.sql"
SQL Coding Standards

Use DATETIME2(0) for timestamps, never DATETIME
Use SYSUTCDATETIME() for all timestamps (UTC)
Use NVARCHAR for string columns, never VARCHAR (Unicode support)
Use ISNULL(col, default) for NULL-safe comparisons in MERGE
Terminate MERGE statements with semicolon
Prefix MERGE with semicolon: ;MERGE
Always include SET NOCOUNT ON and SET XACT_ABORT ON in stored procedures
Use WITH (HOLDLOCK) on MERGE target for concurrency safety
Use CREATE OR ALTER PROCEDURE for idempotent deployments
Include GO after procedure definitions
Never use physical DELETE in MERGE — use soft delete (IsActive = 0)
SQL file naming: lowercase with double underscore separator (entity__purpose.sql)


Staging Table Design (CRITICAL)
Staging tables are landing zones, not authoritative tables.
Rules

DO NOT enforce PRIMARY KEY constraints for report-style APIs
Allow NULL values where API may return NULL
Accept duplicate rows
Do NOT enforce business rules in staging

SO001HRORG Pattern

Remove PK constraint from staging table
PosPosition allows NULL
Duplicates are handled in R, not SQL


Target Table Design
Rules

Business keys MUST be enforced in target table
Use PRIMARY KEY or UNIQUE constraint
Normalize NULL key columns if required

Composite Key Example
PRIMARY KEY (PosPosition, EmplId)
Important

PosPosition → NOT NULL
EmplId → NOT NULL with DEFAULT '' (handles vacant positions)


Composite Business Keys
When a single column is not unique:
Rules

Use multiple columns representing identity
DO NOT include attributes
DO NOT include report metadata

SO001HRORG Example
Correct key:
PosPosition + EmplId
Incorrect key:
PosPosition + EmplId + FutureTermReason
Reason:
FutureTermReason is an attribute that changes over time and does not define identity

MERGE ON Clause (CRITICAL)
For composite keys:
;MERGE target WITH (HOLDLOCK) AS tgt
USING source AS src
ON tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')
Rules

Use NULL-safe comparison for nullable keys
Include ALL key columns
Do NOT include attribute columns
Do NOT include report metadata columns


HASHBYTES Usage
When detecting changes:
Rules

Include ALL business key columns
Include ALL tracked data columns
EXCLUDE:

report metadata fields
audit/control columns




Soft Delete Pattern
Rules

Never hard delete rows
Use IsActive flag

Pattern
WHEN NOT MATCHED BY SOURCE THEN
UPDATE SET IsActive = 0, LastUpdatedUtc = SYSUTCDATETIME()

Report Metadata Columns
Examples: ReportName, SubTitle, RunDate
Rules

Present in staging table (for lineage)
NOT in target table
NOT in audit table
NOT in MERGE logic
NOT in HASHBYTES

Reason:
These fields change every API run and cause false updates

Audit Table Design
Rules

Track business key columns (including composite keys)
Track Old/New values
Capture Insert/Update/Delete actions

SO001HRORG

Include both PosPosition and EmplId as key columns
Exclude report metadata


JSON Field Name Comments
When JSON field names differ from SQL column names:
Example:
PosRole NVARCHAR(255) NULL, -- JSON: "pos role"
Rules

Always document original JSON field
Only required in staging DDL


Data Integrity Rules
Required Validation

Target table MUST enforce business key uniqueness
MERGE source MUST be unique on business key

If duplicates exist:

MUST be resolved BEFORE MERGE
DO NOT attempt to resolve inside SQL MERGE


Dropped Records Tables

For every report-style API, create a parallel dropped-records staging table:

Naming: Stg_<ApiName>_Dropped
File:   ddl/05_dropped_stage.sql

Structure
- DropReason    NVARCHAR(100) NOT NULL  -- 'NULL_POSPOSITION' | 'DUPLICATE_COMPOSITE_KEY'
- LoadDtmUtc   DATETIME2(0)  NOT NULL  DEFAULT SYSUTCDATETIME()
- All original staging columns (same schema as Stg_<ApiName>)

Rules
- No primary key (append-only across ETL runs)
- Allow NULLs in all data columns (PosPosition may be NULL for NULL_POSPOSITION rows)
- Do NOT truncate between runs — historical records are required for trend analysis
- Index on (DropReason, LoadDtmUtc) for reporting query performance

Purpose
Transparency for upstream API data issue reporting and SHR communication.
Dropped rows are captured in R before removal and appended via dbWriteTable.
Create reporting/audit/audit__dropped_records_summary.sql for consumer queries.


Known Pattern: SO001HRORG
Dataset
3795 rows
Key Findings

PosPosition not unique (71 duplicates)
PosPosition + EmplId = 3791 unique
4 duplicates remain

Root Cause
Same employee + position
Different FutureTermReason values:

Redundant
Retired

This is a PeopleSoft reporting artifact
Final Decision

Business key = PosPosition + EmplId
Deduplicate before staging load
Do NOT include FutureTermReason in key
Staging table must not enforce PK


Sanity Check Before Deployment
Before running MERGE:

Source dataset must be unique on business key
Target table must enforce business key
Any duplicates must be:

explained
documented



If not → STOP