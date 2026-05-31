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

## Validation Checklist
- [ ] All files follow naming conventions
- [ ] No credentials or server names in any file
- [ ] Business key identified and enforced
- [ ] Soft delete pattern (never physical DELETE)
- [ ] All 4 guardrails present in MERGE proc
- [ ] Apache 2.0 license header on R script
- [ ] Schema JSON exists in schemas/ folder