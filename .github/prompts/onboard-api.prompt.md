---
description: "Onboard a new PeopleSoft PSA API endpoint"
---

# Onboard New PSA API

Generate all DDL and ETL files for a new PeopleSoft API endpoint.

## Instructions

1. Read the JSON schema from the API's `schemas/` folder
2. Use `Datamart_CITZ_Report_vw_Dept_Org_Levels` as the reference implementation
3. Identify the business key column from the schema
4. Generate these files:
   - `ddl/01_stage.sql` — staging table matching JSON schema
   - `ddl/02_target.sql` — target table with IsActive, CreatedUtc, LastUpdatedUtc
   - `ddl/03_audit.sql` — audit table with Old/New columns per field
   - `ddl/04_merge_proc.sql` — MERGE proc with all guardrails
5. Generate R ETL script in `citz-shr-psa-r/` following `psa_dept_org_levels_etl.R`
6. Follow all naming conventions and standards from project instructions