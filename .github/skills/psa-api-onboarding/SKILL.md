---
name: psa-api-onboarding
description: >-
  Onboards a new PeopleSoft PSA API endpoint into the data integration
  pipeline. Activates when asked to create DDLs, MERGE procedures, ETL
  scripts, or reporting SQL for a new PSA API. Also activates when asked
  to onboard, add, integrate, or set up a new API.
---

# PSA API Onboarding Procedure

## Reference Implementation
Always use `Datamart_CITZ_Report_vw_Dept_Org_Levels` as the gold standard:
- SQL: `citz-shr-psa-sql/PeopleSoftAPI/Datamart_CITZ_Report_vw_Dept_Org_Levels/`
- R: `citz-shr-psa-r/psa_dept_org_levels_etl.R`

## Step 1: Find the Schema
- Look for the JSON schema in: `citz-shr-psa-sql/PeopleSoftAPI/<api_name>/schemas/`
- The schema file contains the first element of the API response
- Use it to determine column names, data types, and business key

## Step 2: Identify Business Key
- Examine the JSON schema for the primary/business key column
- Typically the first column (e.g., `DepartmentID`, `EmployeeID`)
- This column is used in the MERGE ON clause and must be NOT NULL

## Step 3: Create Staging Table (`ddl/01_stage.sql`)
- Table name: `Stg_Peoplesoft_<EntityName>`
- Columns match JSON schema exactly
- Character fields: `NVARCHAR(255)` (or wider based on data)
- Integer fields: `INT`
- Nullable fields (empty `{}` in JSON): allow NULL
- Primary key on business key column

## Step 4: Create Target Table (`ddl/02_target.sql`)
- Table name: `Peoplesoft_<EntityName>`
- Same columns as staging PLUS:
  - `IsActive BIT NOT NULL DEFAULT (1)`
  - `CreatedUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
  - `LastUpdatedUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
- Primary key on business key column
- Index on IsActive

## Step 5: Create Audit Table (`ddl/03_audit.sql`)
- Table name: `Peoplesoft_<EntityName>_Audit`
- Columns:
  - `AuditId BIGINT IDENTITY(1,1) PRIMARY KEY`
  - `RunId UNIQUEIDENTIFIER NOT NULL`
  - `AuditDtmUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
  - `ActionType VARCHAR(12) NOT NULL`
  - Business key column
  - `OldRowHash VARBINARY(32) NULL`, `NewRowHash VARBINARY(32) NULL`
  - `OldIsActive BIT NULL`, `NewIsActive BIT NULL`
  - For EACH data column: `Old<Column>` and `New<Column>` with matching types
- Index on `(RunId, ActionType)`

## Step 6: Create MERGE Procedure (`ddl/04_merge_proc.sql`)
- Procedure: `usp_Merge_PeopleSoft_<EntityName>`
- Parameters: `@Force BIT=0`, `@MinPctOfTarget DECIMAL(5,2)=0.80`, `@MaxPctOfTarget DECIMAL(5,2)=1.20`, `@MaxSoftDeletePct DECIMAL(5,2)=0.10`
- Guardrails:
  1. Empty staging check (THROW 51000)
  2. NULL business key check (THROW 51001)
  3. Row-count variance ±20% (THROW 51002)
  4. Soft delete cap 10% (THROW 51003)
- MERGE logic:
  - MATCHED + changed → UPDATE (set IsActive=1 for reactivation)
  - NOT MATCHED BY TARGET → INSERT
  - NOT MATCHED BY SOURCE AND IsActive=1 → UPDATE IsActive=0
- OUTPUT clause with CASE for ActionType (SOFT_DELETE, REACTIVATE, $action)
- HASHBYTES SHA2_256 for Old/New row hashes
- All Old/New values INTO audit table
- Transaction + TRY/CATCH
- Run summary SELECT at end

## Step 7: Create R ETL Script
- File: `citz-shr-psa-r/psa_<lowercase_entity>_etl.R`
- Copy structure from `psa_dept_org_levels_etl.R`
- Change ONLY: `api_name`, `staging_table`, `target_table`, `expected`, `char_cols`, `int_cols`
- Keep identical: license header, env config loading, auth, proxy, pagination, normalize, SQL connection
- **Field renaming — use `any_of()` pattern (REQUIRED):**
  Build a named character vector sourced from the schema JSON `value[0]` keys:
  ```r
  json_to_sql <- c(
    SqlColName = "json_field_name",
    ...
  )
  df <- df |> dplyr::rename(any_of(json_to_sql))
  ```
  Do NOT use bare `dplyr::rename(NewName = old_name, ...)`. That form throws a hard error
  when a column is absent. Fields that are always `{}` (empty object) can be dropped by
  `bind_rows()`, and live API responses can omit fields present in the schema sample.
  `any_of()` silently skips missing columns, making the ETL resilient to API schema drift.
- **Map field names directly from schema JSON** — open `schemas/<api>_schema.json`, read
  the keys under `value[0]`, and use those exact strings as the right-hand side of the
  rename map. Fields with spaces (e.g. `"pos role"`, `"maildrop city"`) must be quoted
  strings in the vector (no backticks needed in the vector form).
- If `http_method` in the schema `_discovery` block is `POST`, add `req_method("POST")`
  to the `request()` chain in `fetch_page()`.

## Step 8: JSON Field Name Mapping (if needed)
- Compare JSON field names from schema with SQL column names
- If JSON uses snake_case, spaces, or lowercase:
  - Add `dplyr::rename()` block in R ETL script
  - Map every field explicitly (no automatic conversion)
  - Add `-- JSON: "original_name"` comments in staging DDL
- If JSON uses PascalCase already: no rename needed

## Step 9: Detect Report Metadata Columns
- Look for fields that contain per-run values (e.g., report name, run date, subtitle)
- These fields change on every API call and are NOT meaningful data changes
- Include them in STAGING ONLY
- Exclude from target, audit, MERGE comparison, and HASHBYTES

## Step 10: Determine HTTP Method
- Check `_discovery.method` in the schema JSON
- If POST: add `req_method("POST")` in the R ETL `fetch_page()` function
- If GET: use default (no change needed)

## Step 11: Sanity Check (before commit)
Before committing generated files, verify ALL of the following:

### SQL Checks
- [ ] Staging table name: `Stg_Peoplesoft_<EntityName>`
- [ ] Target table name: `Peoplesoft_<EntityName>`
- [ ] Audit table name: `Peoplesoft_<EntityName>_Audit`
- [ ] Stored procedure name: `usp_Merge_PeopleSoft_<EntityName>`
- [ ] Business key identified, NOT NULL, and used in MERGE ON clause
- [ ] Target has `IsActive`, `CreatedUtc`, `LastUpdatedUtc`
- [ ] All 4 guardrails present (THROW 51000-51003)
- [ ] MERGE uses `WITH (HOLDLOCK)`
- [ ] MERGE uses `;MERGE` prefix
- [ ] Soft delete pattern (IsActive=0, no physical DELETE)
- [ ] OUTPUT clause has ActionType CASE (SOFT_DELETE/REACTIVATE/$action)
- [ ] HASHBYTES separator is `'|'` (consistent with other APIs)
- [ ] Report metadata excluded from target, audit, MERGE, HASHBYTES
- [ ] Audit table has Old/New for every data column
- [ ] Audit index on `(RunId, ActionType)`
- [ ] `CREATE OR ALTER PROCEDURE` for idempotency
- [ ] Transaction + TRY/CATCH in MERGE proc
- [ ] Run summary SELECT at end of proc

### R Script Checks
- [ ] `api_name` matches exact API name
- [ ] HTTP method matches discovery result (GET or POST)
- [ ] `staging_table` matches staging DDL
- [ ] `target_table` matches target DDL
- [ ] Column rename mapping is complete (if JSON names differ)
- [ ] `expected` list includes all staging columns
- [ ] `char_cols` and `int_cols` match SQL schema types
- [ ] `int_cols` uses correct columns (not strings stored as NVARCHAR)
- [ ] Report metadata in `expected` but excluded from target by MERGE proc
- [ ] Apache 2.0 license header present
- [ ] No credentials, server names, or internal URLs in code
- [ ] `dbDisconnect(con)` at end of script
- [ ] Env var validation present (config + credentials)

### Cross-File Consistency
- [ ] Column count in staging = column count in R `expected`
- [ ] Column names in staging DDL match R rename output
- [ ] Column names in MERGE match target table columns
- [ ] Audit Old/New columns match target data columns
- [ ] HASHBYTES columns match MERGE comparison columns

## Lessons Learned (from onboarded APIs)

### API 1: Datamart_CITZ_Report_vw_Dept_Org_Levels
- GET method
- JSON fields already in PascalCase — no rename needed
- No report metadata columns
- Business key: DepartmentID
- 12 columns (simple schema)

### API 2: Datamart_CITZ_Report_usp_SO001HRORG
- POST method (GET returns 400)
- JSON fields in snake_case and spaces — full rename required
- 3 report metadata columns (ReportName, SubTitle, RunDate) excluded from target/audit
- Business key: PosPosition
- 75+ columns (complex schema)
- Architectural decision: report metadata stored in staging only to prevent
  false UPDATE events on every row during MERGE

## Validation Checklist
- [ ] All files follow naming conventions
- [ ] No credentials or server names in any file
- [ ] Business key identified and enforced
- [ ] Soft delete pattern (never physical DELETE)
- [ ] All 4 guardrails present in MERGE proc
- [ ] Apache 2.0 license header on R script
- [ ] Schema JSON exists in schemas/ folder