---
description: "Run sanity check on generated API onboarding files"
---

# Sanity Check — PSA API Onboarding

Review the generated DDL and R ETL files for a newly onboarded API.

## Instructions

1. Read the staging table DDL and verify:
   - Table name follows `Stg_Peoplesoft_<EntityName>` convention
   - Business key is NOT NULL with PRIMARY KEY
   - Column types match the JSON schema

2. Read the target table DDL and verify:
   - Has `IsActive`, `CreatedUtc`, `LastUpdatedUtc`
   - Report metadata columns are EXCLUDED
   - Primary key matches staging

3. Read the audit table DDL and verify:
   - Has `RunId`, `AuditDtmUtc`, `ActionType`
   - Has Old/New pairs for every target data column
   - Report metadata columns are EXCLUDED

4. Read the MERGE proc and verify:
   - All 4 guardrails present (THROW 51000-51003)
   - MERGE ON clause uses correct business key
   - Report metadata excluded from comparison
   - HASHBYTES separator is '|'
   - OUTPUT has correct ActionType CASE logic
   - Transaction + TRY/CATCH present

5. Read the R ETL script and verify:
   - API name and HTTP method are correct
   - Column rename mapping is complete (if needed)
   - Expected columns match staging DDL
   - char_cols and int_cols match SQL types
   - No credentials or server names in code

Report any issues found with specific line references.