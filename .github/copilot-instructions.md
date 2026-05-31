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
Whenever a bug is found and fixed in any script, **also update the relevant
instruction and skill files** in the same response — without being asked.
- Bugs in R scripts → update `.github/instructions/r-scripts.instructions.md`
  and `.github/skills/psa-api-onboarding/SKILL.md`
- Bugs in SQL → update `.github/instructions/sql.instructions.md`
- New patterns or anti-patterns discovered → update the relevant file
This keeps future onboarding from repeating the same mistakes.

## JSON Field Naming
- API responses may use snake_case, spaces, or lowercase field names
- R ETL scripts MUST rename JSON fields to PascalCase SQL column names
- Use `dplyr::rename(any_of(rename_map))` with a named character vector — never bare `rename()`
- Document original JSON names as comments in staging DDL

## HTTP Method
- Some PSA APIs require GET, others require POST
- The schema discovery tool (`psa_schema_discovery.R`) auto-detects the method
- ETL scripts MUST use the method that succeeded during discovery
- Document the method in the `_discovery` section of the schema JSON

## Report Metadata Columns
- Some APIs return per-run metadata (e.g., ReportName, SubTitle, RunDate)
- These values change on EVERY API call and are NOT meaningful data
- Rules:
  - INCLUDE in staging table (for traceability)
  - EXCLUDE from target table (prevents false updates)
  - EXCLUDE from audit table (not meaningful change data)
  - EXCLUDE from MERGE comparison (prevents false UPDATE on every row)
  - EXCLUDE from HASHBYTES calculation

## Folder Structure (per API)
Each API lives in its own folder named exactly after the API:

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
