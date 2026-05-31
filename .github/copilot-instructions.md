# Copilot Instructions -- PeopleSoft HR Data Integration

## Project Context

Standardized data integration pipeline for BC PSA PeopleSoft Analytics APIs.
Ingests OData APIs into SQL Server using a staging -> merge -> audit pattern.

Reference implementations (gold standards):
- R ETL: [psa_so001hrorg_etl.R](citz-shr-psa-r/psa_so001hrorg_etl.R)
- SQL pipeline: [Datamart_CITZ_Report_vw_Dept_Org_Levels](citz-shr-psa-sql/PeopleSoftAPI/Datamart_CITZ_Report_vw_Dept_Org_Levels/)

## Architecture

- **R scripts** (`citz-shr-psa-r/`): API fetch, JSON normalize, staging load
- **SQL** (`citz-shr-psa-sql/PeopleSoftAPI/<api_name>/`): DDL, MERGE, reporting
- **Schemas** (`schemas/`): JSON schema snapshots for DDL generation

## Continuous Improvement Rule (CRITICAL)

Whenever a bug or data anomaly is found:
1. Fix it in code (R, SQL, MERGE).
2. Identify root cause (schema mismatch, API behavior, data anomaly, report artifact).
3. Update `.github/instructions/*` and `.github/skills/*` so future APIs do not repeat it.

This repo MUST continuously improve with every onboarding.

## Pattern Consistency Rule (CRITICAL)

When generating a new R ETL script:
1. Read [psa_so001hrorg_etl.R](citz-shr-psa-r/psa_so001hrorg_etl.R) in full first.
2. Copy it as the starting point. Change ONLY:
   - `json_to_sql` rename map
   - `key_cols`
   - `char_cols` / `int_cols` / `dec_cols` / `date_cols`
   - `staging_table`, `dropped_table`, MERGE proc name
   - `api_name` and header comments
3. Do NOT invent new env var names, auth methods, JSON parsing approaches,
   row-binding approaches, libraries, or DB connection parameter sets.
4. If the API genuinely requires a different approach, document WHY in the
   script header AND update [r-scripts.instructions.md](.github/instructions/r-scripts.instructions.md)
   before merging.

Rationale: pattern drift produces silent breakage on the on-prem Windows
scheduler and makes batch onboarding unreviewable.

## Business Key Identification (CRITICAL)

- NEVER assume a single-column key.
- ALWAYS validate uniqueness with `psa_key_discovery.R` and SQL DISTINCT checks.
- Keys represent **business identity**, never attributes.

| Field type | Key role |
|---|---|
| Identity (IDs) | Key candidate |
| Attributes (Status, Type, Reason) | NEVER part of key |
| Report metadata (RunDate, ReportName) | NEVER part of key |

API patterns:
- Lookup API -> single-column key
- Relational entity -> composite key
- Report-style API -> composite key + dedup

## JSON Field Naming

- API responses may use snake_case, spaces, or lowercase.
- R scripts MUST rename to PascalCase via `dplyr::rename(any_of(rename_map))`.
- NEVER use bare `rename()`.
- Document original JSON names in staging DDL comments.

## Report Metadata Columns

Examples: `ReportName`, `SubTitle`, `RunDate`, `AsOfDate`.

- Include in staging (lineage).
- EXCLUDE from target, audit, MERGE ON, HASHBYTES.
- Reason: they change every run and produce false UPDATEs.

## Staging Table Design

Staging is a landing zone, not authoritative.
- No PK for report-style APIs (dedup happens in R).
- Allow NULLs where the API allows NULLs.
- Accept duplicates.
- No business rules enforced.

## Composite Key MERGE

Use NULL-safe comparisons and include ALL key columns:

```sql
ON tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')
```

Include all key columns in HASHBYTES. NEVER include attributes or report metadata.

## Sanity Check -- Business Key

After dedup: `nrow(df)` MUST equal `nrow(unique(df[, key_cols]))`.
If duplicates remain: explain, quantify, document. If unexplained -> STOP.

## Folder Structure

```text
PeopleSoftAPI/<exact_api_name>/
  ddl/
    01_stage.sql
    02_target.sql
    03_audit.sql
    04_merge_proc.sql
    05_dropped_stage.sql
  reporting/
    daily/
    audit/
    ad_hoc/
  schemas/
    <api_name>_schema.json
```
