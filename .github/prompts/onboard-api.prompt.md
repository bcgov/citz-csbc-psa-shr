---
description: "Onboard a new PeopleSoft PSA API endpoint"
---

# Onboard New PSA API

Generate all DDL and ETL files for a new PeopleSoft API endpoint.

## Inputs needed
- API name (e.g., `Datamart_CITZ_Report_vw_Employee_Positions`)
- JSON schema file location in `schemas/` folder

## Steps
1. Read the JSON schema from the `schemas/` folder
2. Use `Datamart_CITZ_Report_vw_Dept_Org_Levels` as the reference implementation
3. Generate these files following the exact same patterns:
   - `ddl/01_stage.sql` — staging table matching JSON schema
   - `ddl/02_target.sql` — target table with IsActive, CreatedUtc, LastUpdatedUtc
   - `ddl/03_audit.sql` — audit table with Old/New columns per field
   - `ddl/04_merge_proc.sql` — MERGE proc with all guardrails
4. Generate the R ETL script following `psa_dept_org_levels_etl.R` as template
5. Ensure all naming conventions match the project standards