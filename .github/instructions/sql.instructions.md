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


Audit Table Column Types (CRITICAL)
Standardized as of API 6 (Datamart_CITZ_Report_EmptyPositionCount) onboarding.
A typed audit table (DATE/INT/DECIMAL/BIT for Old/New) caused the MERGE OUTPUT
INTO clause to fail with "Error converting data type" the moment any source
column's type drifted. The fix is uniform: audit Old/New columns are always
NVARCHAR(255), and the MERGE OUTPUT explicitly casts every value.

Rules
- All Old/New columns must be NVARCHAR(255) NULL — including OldIsActive/NewIsActive.
- OldRowHash / NewRowHash remain VARBINARY(32).
- Never use DATE, INT, DECIMAL, or BIT for Old/New audit columns.
- AuditId BIGINT IDENTITY, RunId UNIQUEIDENTIFIER, AuditDtmUtc DATETIME2(0),
  ActionType VARCHAR(12) — these keep their native types.
- Business key columns keep their native types (e.g., DATE EffDt, INT EffSeq).
- MERGE OUTPUT must explicitly CAST every deleted.* / inserted.* value to
  NVARCHAR(255):
    NVARCHAR / VARCHAR  -> CAST(deleted.Col AS NVARCHAR(255))
    DATE                -> CONVERT(NVARCHAR(255), deleted.Col, 23)
    INT / DECIMAL / BIT -> CAST(deleted.Col AS NVARCHAR(255))

Rationale
NVARCHAR(255) is a type-agnostic landing zone. It removes all OUTPUT bind
fragility, survives schema drift, and lets the audit table accept any value
the source produces without conversion errors.


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

DATE Column Types
When the API returns ISO-format date strings (e.g., "2024-03-15"), use SQL DATE type — not NVARCHAR.

Rules
Use DATE for all date columns (both NOT NULL and nullable)
For MERGE WHEN MATCHED comparisons:
  NOT NULL date columns: direct comparison (tgt.Col <> src.Col)
  NULLABLE date columns: ISNULL(CONVERT(NVARCHAR(10), col, 23), '')
For HASHBYTES:
  NOT NULL date columns: CONVERT(NVARCHAR(10), col, 23)
  NULLABLE date columns: COALESCE(CONVERT(NVARCHAR(10), col, 23), '')

SHR010HRORG NOT NULL dates (direct compare):
  Birthdate, HireDt, MostHistoricDate, FirstDateInOrganization, FirstDateInPosition

SHR010HRORG NULLABLE dates (ISNULL/COALESCE pattern):
  LastHireDt, FutureReturnDate, LayoffLeaveStopPayStartDate


Numeric Column Types (DECIMAL / INT)
When the API returns numeric values, use appropriate SQL numeric types.

Rules
Use DECIMAL(p,s) for money and rate columns (not NVARCHAR)
Use INT for whole-number count columns
For MERGE WHEN MATCHED comparisons:
  ISNULL(tgt.Col, -1) <> ISNULL(src.Col, -1)
For HASHBYTES:
  COALESCE(CONVERT(NVARCHAR(p), col), '') where p is wide enough for the precision

SHR010HRORG DECIMAL columns:
  Age DECIMAL(8,4), AnnualRt DECIMAL(18,4), CompRate DECIMAL(18,4),
  HourlyRt DECIMAL(12,4), StdHours DECIMAL(6,2)

SHR010HRORG INT columns:
  EmplRcd INT, Step INT


Report Metadata: AsOfDate Pattern
When an API returns a "snapshot date" column that is identical for all rows per run:

Rules
Store in staging table ONLY (not target, not audit)
EXCLUDE from HASHBYTES — identical value on all rows would cause every row to
  appear as an UPDATE on every daily run
EXCLUDE from MERGE comparisons
Document the reason with a comment in the staging DDL and target DDL

SHR010HRORG example:
  AsOfDate (JSON: "As_of_Date") — 1 distinct value per run
  Stored in Stg_Peoplesoft_SHR010HRORG; excluded from Peoplesoft_SHR010HRORG


RowHash Pattern for Wide Tables (100+ columns)
When a table has more than ~50 data columns, the WHEN MATCHED OR expression becomes
impractical. Use a pre-computed SHA2_256 row hash instead.

When to use
Use RowHash pattern when the table has > ~50 data columns.
Use individual column OR comparisons for tables with <= ~55 columns.

Implementation
1. Add to target table DDL (02_target.sql):
   RowHash VARBINARY(32) NULL

2. In 04_merge_proc.sql, add a source CTE that pre-computes the hash:
   ;WITH source_hashed AS (
       SELECT *,
           HASHBYTES('SHA2_256',
               CAST(CONCAT_WS('|',
                   COALESCE(col1, ''),
                   COALESCE(col2, ''),
                   COALESCE(CONVERT(NVARCHAR(10), date_col, 23), ''),
                   COALESCE(CONVERT(NVARCHAR(38), numeric_col), ''),
                   ...
               ) AS NVARCHAR(MAX))
           ) AS _RowHash
       FROM dbo.Stg_<TableName>
   )

3. WHEN MATCHED condition:
   WHEN MATCHED AND (tgt.IsActive = 0 OR tgt.RowHash <> src._RowHash)

4. SET in UPDATE branch:
   tgt.RowHash = src._RowHash, ...

5. INSERT branch:
   RowHash = src._RowHash

NULL handling in CONCAT_WS / HASHBYTES
- Nullable strings:  COALESCE(col, '')
- Nullable dates:    COALESCE(CONVERT(NVARCHAR(10), col, 23), '')
- Nullable numerics: COALESCE(CONVERT(NVARCHAR(38), col), '')

Rationale: CONCAT_WS already skips NULLs, but using COALESCE ensures consistent
hash output between NULL and empty string — preventing false change detections.

Reference implementation: Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
(140 columns, 136 data columns in hash)