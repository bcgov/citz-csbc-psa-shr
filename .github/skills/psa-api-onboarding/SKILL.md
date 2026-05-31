




You said:
still the same problem...try a diffrent way to make me copy...two times the same issue
Copilot said:
Copilot
Ah got it — the issue isn’t the content, it’s the Markdown code block formatting breaking when you copy.

Let’s fix this properly ✅

👉 I’ll give you the file as plain text (no code blocks, no ```markdown, no indentation traps) so you can copy-paste directly into VS Code with zero corruption.

✅ COPY FROM BELOW (START HERE)
Copilot Instructions — PeopleSoft HR Data Integration
Project Context
This repository contains a standardized data integration pipeline for
BC Public Service Agency (PSA) PeopleSoft Analytics APIs. It ingests
OData API data into SQL Server using a staging → merge → audit pattern.

The first onboarded API is Datamart_CITZ_Report_vw_Dept_Org_Levels.
Use it as the reference implementation for all new APIs.

Architecture
R scripts (citz-shr-psa-r/): API fetch, JSON normalize, staging load
SQL scripts (citz-shr-psa-sql/PeopleSoftAPI/): DDL, MERGE proc, reporting
Schema files (schemas/): JSON schema snapshots for DDL generation
Continuous Improvement Rule
Whenever a bug or data anomaly is identified:

Fix the issue in code (R, SQL, MERGE)
Identify the root cause:
Schema mismatch
API behavior
Data anomaly
Report artifact
Update:
.github/instructions/*
.github/skills/*
Ensure future APIs DO NOT repeat the issue
This repository must continuously improve with each onboarding.

Business Key Identification (CRITICAL)
NEVER assume a single-column key
ALWAYS validate uniqueness using:
psa_key_discovery.R
SQL validation queries
Keys must represent business identity, not attributes
Rules
Identity fields → candidates (e.g., IDs)
Attributes → NOT part of key (e.g., Status, Type, Reason fields)
Report artifacts MUST NOT drive key design
API Patterns
Lookup API → Single-column key
Relational entity → Composite key
Report-style API → Composite key + dedup

SO001HRORG Example
Correct key → PosPosition + EmplId
Incorrect key → PosPosition + EmplId + FutureTermReason

Reason:
FutureTermReason is an attribute (changes over time). Using it breaks MERGE logic.

JSON Field Naming
API responses may use snake_case, spaces, or lowercase field names
R ETL scripts MUST rename JSON fields to PascalCase SQL column names
Rules
Use rename(any_of(rename_map))
NEVER use bare rename()
Always use a mapping vector
Example:

rename_map <- c(
PosRole = "pos role"
)

df <- df |>
dplyr::rename(any_of(rename_map))

Document original JSON names in staging DDL
HTTP Method
APIs may require GET or POST
psa_schema_discovery.R determines the method
Rules
Use the method that succeeds
Document it in the schema
Report Metadata Columns
Examples: ReportName, SubTitle, RunDate

Rules
Include in staging
Exclude from target
Exclude from audit
Exclude from MERGE comparisons
Exclude from HASHBYTES

Staging Table Design
Staging tables are landing zones, not authoritative tables

Rules
No primary key for report-style APIs
Allow NULLs where API allows NULLs
Accept duplicates
Do not enforce business rules
SO001HRORG Pattern
No PK
PosPosition allows NULL
Dedup done in R
Composite Key Handling
When no single column is unique:

Rules
Use columns that represent identity
Do NOT include attributes
Normalize NULL values if needed
Example:

PRIMARY KEY (PosPosition, EmplId)

MERGE ON Clause (Composite Keys)
Use:

tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')

Rules
NULL-safe comparisons required
Include all key columns in HASHBYTES
Do NOT include attributes
Deduplication (Report-Style APIs)
Some APIs return duplicate rows due to reporting artifacts

Rules
Deduplicate in R before loading
Deduplicate only on business key
Keep last row
Log duplicates removed
Never dedup on attributes
Pattern
Drop invalid PosPosition rows

Normalize EmplId NULL to empty string

Deduplicate using PosPosition + EmplId

Log counts

Known Pattern: SO001HRORG
Total rows: 3795

PosPosition not unique (71 duplicates)

PosPosition + EmplId → 3791 unique

Remaining 4 duplicates

Root Cause
Same employee and position
Different FutureTermReason values:

Redundant
Retired
This is a reporting artifact

Final Decision
Business key = PosPosition + EmplId
FutureTermReason is NOT part of key
Deduplicate before loading

Sanity Check — Business Key
After dedup:

TotalRows must equal DISTINCT business key rows

If duplicates remain:

Explain them
Quantify them
Document them
If unexplained → STOP

Folder Structure
PeopleSoftAPI/<api_name>/

ddl/

01_stage.sql
02_target.sql
03_audit.sql
04_merge_proc.sql
05_dropped_stage.sql   <- dropped records quality table
reporting/

daily/
audit/
ad_hoc/
schemas/

<api_name>_schema.json

Data Quality Tracking (Dropped Records)

For every onboarded API, rows excluded from the pipeline due to upstream data
anomalies must be persisted to a quality tracking table — not just logged.

Why
- Warning logs disappear; a SQL table is permanent and queryable
- SHR needs visibility into API data anomalies across runs
- Enables trend analysis (is the problem getting better or worse?)

Dropped Records Table (DDL: 05_dropped_stage.sql)
- Table: dbo.Stg_<ApiName>_Dropped
- DropReason NVARCHAR(100) NOT NULL
- LoadDtmUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
- All staging columns (same schema, all nullable)
- No PK; append-only across ETL runs

DropReason Values
- 'NULL_POSPOSITION'         — PosPosition was NULL or blank in the API response
- 'DUPLICATE_COMPOSITE_KEY' — Duplicate on (PosPosition, EmplId); removed before staging load

R ETL Pattern
1. Capture null_pos_rows BEFORE dropping (add DropReason = 'NULL_POSPOSITION')
2. Capture dup_rows BEFORE deduplication (add DropReason = 'DUPLICATE_COMPOSITE_KEY')
3. Combine: dropped_df <- rbind(null_pos_rows, dup_rows)
4. After main staging commit: load dropped_df via dbWriteTable(append = TRUE)
5. Wrap load in tryCatch — failure must NOT block the MERGE

Reporting
- Create reporting/audit/audit__dropped_records_summary.sql
- Show count by DropReason, latest LoadDtmUtc, and sample records
- Include FutureTermReason column in DUPLICATE_COMPOSITE_KEY samples for diagnosis
✅ COPY ENDS HERE
✅ Why this works (important)
No ``` blocks → nothing breaks in paste
No hidden escapes → VS Code safe
Clean structure → Git diff friendly
✅ Next step
Do:




Shell
git add .github/copilot-instructions.md
git commit -m "Fix: full copilot instructions with composite key + report patterns"
git push
✅ Going forward (your new rule)
You're absolutely right to enforce this:

👉 Always ask me for full file
👉 I return plain-text version
👉 No markdown code blocks

When ready, send me the next file (sql.instructions.md) — I’ll do the same clean format 👍








You said:
in mac how to make it show the folders starting with a dot (.) for example, I can't see .github folder to upload the files here
Copilot said:
Copilot
Ah yes — this is a classic macOS “hidden files” thing 👍

Folders starting with . (like .github) are hidden by default in Finder.

✅ Fastest way (keyboard shortcut)
In Finder (any folder):




Shell
Command (⌘) + Shift + .
Press that once → ✅ hidden files show
Press again → ❌ hidden files hide

👉 This is the best and easiest way

✅ What you’ll see
After pressing:

.github/ ✅ appears
.git/ ✅ appears
.env, .DS_Store ✅ appear
Now you can:

open .github
edit MD files
upload files here if needed
✅ Alternative (Terminal – permanent setting)
If you want hidden files always visible:




Shell
defaults write com.apple.finder AppleShowAllFiles YES
killall Finder
To revert:




Shell
defaults write com.apple.finder AppleShowAllFiles NO
killall Finder
✅ VS Code tip (since you’re using Copilot)
VS Code usually already shows .github by default, but if it doesn't:

Open VS Code settings (Cmd + ,)
Search: files.exclude
Make sure .github is not excluded
✅ Your workflow from here
Press ⌘ + Shift + .
Open .github/
Paste updated MD file
Commit normally
If you want, I can also give you a one-time Git check to ensure .github is included and nothing is accidentally ignored 👍









md
r-scripts.instructions
You said:

Copilot said:
Copilot
Perfect — now we’ll do this properly and cleanly, no formatting issues ✅
Same approach as before: plain text, full file, copy‑paste safe.

✅ ✅ FULL FILE — r-scripts.instructions.md (COPY BELOW)
applyTo: "**/*.R"
R Script Standards
Use httr2 (not httr) for HTTP requests
Use resp_body_json() instead of resp_body_string() + fromJSON()
Use dplyr::mutate(across(...)) for type conversions, not per-column assignment
Use intersect(expected_cols, names(df)) for safe column selection
Handle OData pagination with fallback: @odata.nextLink then odata.nextLink
Normalize empty JSON objects {} to NA
JSON Field Renaming
NEVER use bare dplyr::rename(NewName = old_name, ...)
ALWAYS use rename(any_of(rename_map))
Example:

rename_map <- c(
PosRole = "pos role"
)

df <- df |> dplyr::rename(any_of(rename_map))

any_of() avoids hard failure when columns are missing
Place rename BEFORE column validation
Include all fields, including report metadata
Missing Column Handling (CRITICAL)
After renaming, backfill missing columns instead of failing:

missing_cols <- setdiff(expected, names(df))

if (length(missing_cols) > 0) { warning(paste( "Columns absent from API response (backfilled as NA):", paste(missing_cols, collapse = ", ") )) df[missing_cols] <- NA }

Rules:

NEVER stop on missing non-key columns
ONLY stop if a business key column is missing
Business Key Validation (CRITICAL)
Hard stop ONLY if the primary identity column is missing or NULL
Secondary key columns may allow NULL (depending on design)
Example rule:

PosPosition → REQUIRED → stop if NULL
EmplId → OPTIONAL → normalize NULL
Deduplication (CRITICAL)
Some APIs return duplicate rows due to reporting artifacts.

Rules
Deduplicate BEFORE dbWriteTable()
Deduplicate ONLY on business key
Keep last record using fromLast = TRUE
Log number of duplicates removed
NEVER include attribute columns in dedup
Dedup Pattern (SO001HRORG STANDARD)
1. Drop invalid key rows (mandatory field)
invalid_rows <- sum(is.na(df$PosPosition) | df$PosPosition == "")

if (invalid_rows > 0) { warning(paste("Dropping rows with NULL PosPosition:", invalid_rows)) df <- df[!(is.na(df$PosPosition) | df$PosPosition == ""), ] }

2. Normalize nullable key column (vacant positions)
df$EmplId[is.na(df$EmplId)] <- ""

3. Deduplicate on composite business key
original_count <- nrow(df)

df <- df[!duplicated(paste(df$PosPosition, df$EmplId, sep="|"), fromLast = TRUE), ]

cat("Duplicates removed:", original_count - nrow(df), "\n")

Deduplication Rationale
Some APIs are report-style outputs (not true relational entities)
Duplicate rows may represent:
report artifacts
multi-valued attributes
data modeling artifacts
Example: SO001HRORG
Duplicate rows occur because:

Same employee + position
Different FutureTermReason (Redundant vs Retired)
These are NOT separate business records

Decision:
Business key = PosPosition + EmplId
FutureTermReason is NOT part of key
Deduplicate before staging load
Staging Load Rules
Perform ALL cleanup BEFORE dbWriteTable()
Staging table must receive:
valid keys
deduplicated rows
correctly typed columns
SQL Execution Rules
Use dbExecute() for DDL/DML
Use dbGetQuery() for SELECT
Do NOT mix the two
Environment Configuration
Read credentials using Sys.getenv() only
Load environment file using:
readRenviron(".Renviron.prod") or readRenviron(".Renviron.test")

Validate required variables:
required <- c("PSA_API_BASE_URL", "PSA_API_USERNAME", "PSA_API_PROD_PASSWORD")

missing <- required[Sys.getenv(required) == ""]

if (length(missing) > 0) { stop(paste("Missing environment variables:", paste(missing, collapse = ", "))) }

HTTP Method Handling
Read from schema discovery
If POST required:
req <- request(url) |> req_method("POST")

If GET → default behavior
Pagination Rules
Always handle pagination
Check both:
@odata.nextLink
odata.nextLink

Use:
Sys.sleep(0.2)

between calls

Report Metadata Handling
Include metadata fields in expected column list
Include in type conversion
Include in staging
BUT:

Do NOT use in:
MERGE ON
HASHBYTES
Target table
Connection Handling
Always close connection:
dbDisconnect(con)

Never leave open connections
Licensing
Include Apache 2.0 header at top of every script
✅ COPY ENDS HERE
✅ What changed (important for you)
This version now includes:

✅ Proper composite key dedup pattern
✅ Explicit SO001HRORG behaviour
✅ Correct NULL handling (EmplId vs PosPosition)
✅ Clear separation of:

identity vs attributes
staging vs business rules
✅ Next step
On-prem:




Shell
git add .github/instructions/r-scripts.instructions.md
git commit -m "Update R instructions with composite key and report dedup pattern"
git push
Then on Mac:




Shell
git pull
✅ You’re now ready for Sonnet
Now Sonnet will:

✅ apply dedup correctly
✅ never use FutureTermReason incorrectly
✅ align R + SQL + MERGE
Next: send me sql.instructions.md ✅
That’s where the Merge + PK decisions need to be enforced properly.

Sources








md
sql.instructions
You said:

Copilot said:
Copilot
Perfect — this one is small, so I’ll give you a complete, upgraded version cleanly in plain text (no formatting issues) just like before.

This version injects:

✅ composite key rules
✅ staging no‑PK pattern
✅ MERGE fixes
✅ SO001HRORG lessons
✅ keeps ALL your existing standards
✅ ✅ FULL FILE — sql.instructions.md (COPY BELOW)
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
Correct key: PosPosition + EmplId

Incorrect key: PosPosition + EmplId + FutureTermReason

Reason: FutureTermReason is an attribute that changes over time and does not define identity

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
Reason: These fields change every API run and cause false updates

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

✅ COPY ENDS HERE
✅ What you do now
On-prem:




Shell
git add .github/instructions/sql.instructions.md
git commit -m "Update SQL instructions: composite key, merge rules, staging design (SO001HRORG)"
git push
Mac:




Shell
git pull
✅ What you just unlocked
Now Sonnet will:

✅ always remove staging PK for report APIs
✅ always use composite key correctly
✅ never misuse attributes in keys
✅ align MERGE + HASHBYTES correctly
✅ Next step
Now you're ready for the Sonnet prompt you wrote earlier — it will behave very differently now (correctly).

If you want after Sonnet runs, paste the diffs — I’ll do a final enterprise-level sanity check before you push 👍

Sources








md
SKILL
You said:

Copilot said:
Copilot
Perfect — this is the most important file to get right 👍
I’ll give you a FULL clean replacement of SKILL.md with:

✅ Your original onboarding steps preserved
✅ Composite key logic added properly
✅ Report‑style API handling integrated
✅ SO001HRORG lessons corrected (this is critical — your current file still says PosPosition only ❌)
✅ Dedup + staging rules aligned with R + SQL instructions
👉 And again — plain text, no formatting traps, copy‑paste safe

✅ ✅ FULL FILE — SKILL.md (COPY BELOW)
name: psa-api-onboarding
description:
Onboards a new PeopleSoft PSA API endpoint into the data integration pipeline.
Activates when asked to create DDLs, MERGE procedures, ETL scripts, or reporting SQL for a new PSA API.

PSA API Onboarding Procedure
Reference Implementation
Always use Datamart_CITZ_Report_vw_Dept_Org_Levels as the gold standard:

SQL: citz-shr-psa-sql/PeopleSoftAPI/Datamart_CITZ_Report_vw_Dept_Org_Levels/
R: citz-shr-psa-r/psa_dept_org_levels_etl.R

Step 1: Find the Schema
Look for schema JSON in:
citz-shr-psa-sql/PeopleSoftAPI/<api_name>/schemas/

Contains the first API response row

Use it to determine:

column names
data types
possible key candidates
Step 2: Identify Business Key (CRITICAL)
NEVER assume the first column is the key
ALWAYS validate uniqueness using:
key discovery script
SQL DISTINCT checks
Rules:
Key must represent BUSINESS IDENTITY
NOT attributes (status, reason, flags)
Key Types
Single-column key
→ DepartmentID

Composite key
→ multiple fields required

Report-style API
→ composite key + dedup

SO001HRORG Example
Incorrect assumption: Business key = PosPosition ❌

Actual result:

PosPosition NOT unique
71 duplicates
Final decision: Business key = PosPosition + EmplId ✅

Step 3: Create Staging Table (ddl/01_stage.sql)
Table: Stg_Peoplesoft_

Rules:
Columns match JSON schema exactly
NVARCHAR for strings
INT where appropriate
Allow NULL for fields that may be NULL
PRIMARY KEY RULE (IMPORTANT)
Use PK ONLY if API guarantees 1 row per key

If API is report-style:

DO NOT create PK
Add comment explaining why
Dedup will happen in R
SO001HRORG
NO PK on staging
PosPosition allows NULL
Duplicates allowed
Step 4: Create Target Table (ddl/02_target.sql)
Table: Peoplesoft_

Add:

IsActive BIT DEFAULT 1
CreatedUtc DATETIME2 DEFAULT SYSUTCDATETIME()
LastUpdatedUtc DATETIME2 DEFAULT SYSUTCDATETIME()
KEY RULES
Target MUST enforce business key
Use PRIMARY KEY or UNIQUE constraint
Composite Key Example
PRIMARY KEY (PosPosition, EmplId)

Rules:

PosPosition NOT NULL
EmplId NOT NULL DEFAULT ''
Step 5: Create Audit Table (ddl/03_audit.sql)
Table: Peoplesoft__Audit

Include:

AuditId
RunId
AuditDtmUtc
ActionType
Include BUSINESS KEY COLUMNS
For composite keys:

include both PosPosition and EmplId
Include:
OldRowHash / NewRowHash
OldIsActive / NewIsActive
Old/New for every column
Exclude:
Report metadata columns

Step 6: Create MERGE Procedure (ddl/04_merge_proc.sql)
Procedure: usp_Merge_PeopleSoft_

Guardrails
Empty staging → THROW 51000
NULL key → THROW 51001
Row variance → THROW 51002
Soft delete cap → THROW 51003
MERGE Rules
MATCHED + changed → UPDATE
NOT MATCHED → INSERT
NOT MATCHED BY SOURCE → Soft delete
Composite Key MERGE
ON tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')

CRITICAL RULES
Do NOT include attributes in ON
Do NOT include report metadata
Include ALL key columns in HASHBYTES
Step 7: Create R ETL Script
File: psa__etl.R

Based on reference script

Mandatory Changes
api_name
staging_table
target_table
expected columns
char_cols / int_cols
Dedup Logic (CRITICAL)
Must happen BEFORE dbWriteTable

Pattern:

Drop NULL PosPosition rows
Normalize EmplId NULL → ""
Deduplicate on PosPosition + EmplId
Keep last row
SO001HRORG Dedup Rule
Duplicates caused by: FutureTermReason (Redundant vs Retired)

These are:

same employee
same position
NOT separate entities
Resolution:

deduplicate
do NOT treat as separate rows
Step 8: JSON Field Mapping
Compare JSON names vs SQL names
Use rename(any_of())
Map explicitly
Step 9: Report Metadata Detection
Look for:

ReportName
SubTitle
RunDate
RULES
Include in staging
Exclude from:

target
audit
MERGE
HASHBYTES
Step 10: HTTP Method
Check schema discovery

POST → req_method("POST")
GET → default

Step 11: Sanity Check
Before commit:

Key identified correctly
Source unique after dedup
Staging matches schema
Target enforces key
MERGE uses correct ON
Metadata excluded properly
DATA QUALITY CHECK (NEW)
Before finalizing key:

TotalRows vs DISTINCT key must be validated
Remaining duplicates:
must be explained
must be documented
If unexplained → STOP

Lessons Learned
API 1: DeptOrg
Clean entity
Single key
No metadata
Simple schema
API 2: SO001HRORG
Report-style API
POST method
Complex schema
75+ columns
Key Findings
PosPosition NOT unique
Composite key required
Final Key
PosPosition + EmplId

Data Issue
4 duplicate rows

Cause: FutureTermReason differences

Values:

Redundant
Retired
Interpretation
Report artifact
NOT real separate business rows
Final Decisions
Use composite key
Deduplicate before load
Do NOT include FutureTermReason in key
Staging MUST NOT enforce PK
Architectural Insight
Some PSA APIs are:

Not normalized
Report-based outputs
Contain duplicate logical rows
System must handle:

key discovery
deduplication
flexible staging
Validation Checklist
Naming conventions followed
No credentials in code
Business key enforced in target
MERGE guardrails present
Soft delete pattern used
Schema JSON present
R script closes DB connection