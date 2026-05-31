# Copilot Instructions — PeopleSoft HR Data Integration

## Project Context
This repository contains a standardized data integration pipeline for
BC Public Service Agency (PSA) PeopleSoft Analytics APIs. It ingests
OData API data into SQL Server using a staging → merge → audit pattern.

The first onboarded API is `Datamart_CITZ_Report_vw_Dept_Org_Levels`.
Use it as the reference implementation for all new APIs.

## Architecture
- **R scripts** (`citz-shr-psa-r/`): API fetch, JSON normalize, staging load
- **SQL scripts** (`citz-shr-psa-sql/PeopleSoftAPI/`): DDL, MERGE proc, reporting
- **Schema files** (`schemas/`): JSON schema snapshots for DDL generation


## Continuous Improvement Rule
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

## Business Key Identification (CRITICAL)

NEVER assume a single-column key
ALWAYS validate uniqueness using:

psa_key_discovery.R
SQL validation queries


Keys must represent business identity, not attributes

# Rules

Identity fields → candidates (e.g., IDs)
Attributes → NOT part of key (e.g., Status, Type, Reason fields)
Report artifacts MUST NOT drive key design

# API Patterns
Lookup API → Single-column key
Relational entity → Composite key
Report-style API → Composite key + dedup
SO001HRORG Example
Correct key → PosPosition + EmplId
Incorrect key → PosPosition + EmplId + FutureTermReason
Reason:
FutureTermReason is an attribute (changes over time). Using it breaks MERGE logic.

## JSON Field Naming

API responses may use snake_case, spaces, or lowercase field names
R ETL scripts MUST rename JSON fields to PascalCase SQL column names

# Rules

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


## HTTP Method

APIs may require GET or POST
psa_schema_discovery.R determines the method

# Rules

Use the method that succeeds
Document it in the schema


## Report Metadata Columns
Examples: ReportName, SubTitle, RunDate
# Rules
Include in staging
Exclude from target
Exclude from audit
Exclude from MERGE comparisons
Exclude from HASHBYTES

## Staging Table Design
Staging tables are landing zones, not authoritative tables
# Rules

No primary key for report-style APIs
Allow NULLs where API allows NULLs
Accept duplicates
Do not enforce business rules

# SO001HRORG Pattern

No PK
PosPosition allows NULL
Dedup done in R


## Composite Key Handling
When no single column is unique:
# Rules

Use columns that represent identity
Do NOT include attributes
Normalize NULL values if needed

Example:
PRIMARY KEY (PosPosition, EmplId)

## MERGE ON Clause (Composite Keys) 
# Use:
tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')
# Rules

NULL-safe comparisons required
Include all key columns in HASHBYTES
Do NOT include attributes


## Deduplication (Report-Style APIs)
Some APIs return duplicate rows due to reporting artifacts
# Rules

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

## Known Pattern: SO001HRORG
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

## Sanity Check — Business Key
After dedup:
TotalRows must equal DISTINCT business key rows
If duplicates remain:

Explain them
Quantify them
Document them

If unexplained → STOP

## Folder Structure
```text
PeopleSoftAPI/<exact_api_name>/
├── ddl/
│   ├── 01_stage.sql
│   ├── 02_target.sql
│   ├── 03_audit.sql
│   └── 04_merge_proc.sql
├── reporting/
│   ├── daily/
│   ├── audit/
│   └── ad_hoc/
└── schemas/
    └── <api_name>_schema.json
    