---
name: psa-api-onboarding
description: >-
  Onboards a new PeopleSoft PSA API endpoint into the data integration
  pipeline. Use this when asked to create DDLs, MERGE procedures, ETL
  scripts, or reporting SQL for a new PSA API. Also use when asked to
  onboard, add, or integrate a new API.
---

# PSA API Onboarding Procedure

## Reference Implementation
Always use `Datamart_CITZ_Report_vw_Dept_Org_Levels` as the gold standard.
All files for this API are in:
- SQL: `citz-shr-psa-sql/PeopleSoftAPI/Datamart_CITZ_Report_vw_Dept_Org_Levels/`
- R: `citz-shr-psa-r/psa_dept_org_levels_etl.R`

## Step 1: Schema Discovery
- Run `psa_schema_discovery.R` with the new API name
- Schema JSON is saved to `<api_folder>/schemas/`
- Review the Column Summary output for data types

## Step 2: Identify Business Key
- Examine the JSON schema to determine the primary/business key column
- This column is used in the MERGE ON clause
- It must be NOT NULL in staging and target tables

## Step 3: Generate Staging Table (`01_stage.sql`)
- Table name: `Stg_Peoplesoft_<EntityName>`
- Columns match JSON schema exactly
- Character columns: `NVARCHAR(255)` (adjust based on data)
- Integer columns: `INT`
- Nullable columns (empty `{}` in JSON): allow NULL
- Add primary key on business key column

## Step 4: Generate Target Table (`02_target.sql`)
- Table name: `Peoplesoft_<EntityName>`
- Same columns as staging PLUS:
  - `IsActive BIT NOT NULL DEFAULT (1)`
  - `CreatedUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
  - `LastUpdatedUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
- Primary key on business key column

## Step 5: Generate Audit Table (`03_audit.sql`)
- Table name: `Peoplesoft_<EntityName>_Audit`
- Columns:
  - `AuditId BIGINT IDENTITY PRIMARY KEY`
  - `RunId UNIQUEIDENTIFIER NOT NULL`
  - `AuditDtmUtc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`
  - `ActionType VARCHAR(12) NOT NULL` (INSERT/UPDATE/SOFT_DELETE/REACTIVATE)
  - Business key column
  - `OldRowHash VARBINARY(32) NULL`
  - `NewRowHash VARBINARY(32) NULL`
  - `OldIsActive BIT NULL`, `NewIsActive BIT NULL`
  - For EACH data column: `Old<Column>` and `New<Column>`

## Step 6: Generate MERGE Procedure (`04_merge_proc.sql`)
- Procedure name: `usp_Merge_PeopleSoft_<EntityName>`
- Parameters: `@Force BIT = 0`, `@MinPctOfTarget`, `@MaxPctOfTarget`, `@MaxSoftDeletePct`
- Must include ALL guardrails:
  1. Empty staging check
  2. NULL business key check
  3. Row-count variance bounds (±20%)
  4. Soft delete cap (10%)
  5. Transaction + TRY/CATCH
- MERGE logic:
  - MATCHED + changed → UPDATE (set IsActive=1 for reactivation)
  - NOT MATCHED BY TARGET → INSERT
  - NOT MATCHED BY SOURCE AND IsActive=1 → UPDATE IsActive=0
- OUTPUT clause with:
  - ActionType CASE (SOFT_DELETE, REACTIVATE, or $action)
  - HASHBYTES for Old/New row hashes
  - All Old/New column values
  - INTO audit table
- Run summary SELECT at end

## Step 7: Generate R ETL Script
- File: `psa_<entity_name>_etl.R`
- Copy pattern from `psa_dept_org_levels_etl.R`
- Change ONLY: `api_name`, `staging_table`, `target_table`, `expected`, `char_cols`, `int_cols`
- Keep identical: auth, proxy, pagination, normalize, SQL connection, error handling

## Step 8: Generate Reporting SQL
- Copy reporting templates from Dept_Org_Levels
- Adapt table names and column references
- Place in `reporting/daily/`, `reporting/audit/`, `reporting/ad_hoc/`

## Validation Checklist
- [ ] All files follow naming conventions
- [ ] No credentials or server names in code
- [ ] Business key identified and enforced
- [ ] Soft delete pattern (never physical DELETE)
- [ ] All guardrails present in MERGE proc
- [ ] Apache 2.0 license header on R scripts
- [ ] Schema JSON committed to schemas/ folder