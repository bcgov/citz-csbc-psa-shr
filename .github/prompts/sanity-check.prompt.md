description: "Run sanity check on generated API onboarding files"
Sanity Check — PSA API Onboarding
Review the generated DDL and R ETL files for a newly onboarded API.

Instructions
1. Identify API Type (CRITICAL)
Determine which type the API is:

Lookup API → single key
Relational API → composite key
Report-style API → composite key + dedup

If report-style:

Staging MUST NOT have PK
Dedup MUST exist in R


2. Staging Table Validation (ddl/01_stage.sql)
Verify:

Table name follows:
Stg_Peoplesoft_

For Lookup / Clean APIs:

Primary key exists
Key column is NOT NULL

For Report-Style APIs (e.g., SO001HRORG):

NO primary key
Key columns may allow NULL (temporarily)
Comment explains dedup happens in R


3. Business Key Validation (CRITICAL)
Verify correct business key is used:
Rules:

Key represents identity
NOT attributes
NOT report metadata

For SO001HRORG:

✅ Correct: PosPosition + EmplId
❌ Reject:

PosPosition only
PosPosition + FutureTermReason




4. Target Table Validation (ddl/02_target.sql)
Verify:

Table: Peoplesoft_
Columns match staging (excluding metadata)
Has:

IsActive
CreatedUtc
LastUpdatedUtc



Key Rules:

Composite key enforced if required

Example:
PRIMARY KEY (PosPosition, EmplId)

PosPosition NOT NULL
EmplId NOT NULL DEFAULT ''


5. Audit Table Validation (ddl/03_audit.sql)
Verify:

Has:

RunId
AuditDtmUtc
ActionType



Business Key:

Includes ALL key columns
(e.g., PosPosition AND EmplId)

Data Tracking:

Old/New for every data column
RowHash columns present

Exclusions:

Report metadata NOT included

Audit Type Check (CRITICAL — added after API 6 EPC failure):

ALL Old/New columns are NVARCHAR(255) NULL — including OldIsActive/NewIsActive
OldRowHash / NewRowHash are VARBINARY(32) NULL
Reject if any Old/New column is DATE, INT, DECIMAL, BIT, BINARY, or any other type
AuditId is BIGINT IDENTITY, ActionType is VARCHAR(12)
Corresponding 04_merge_proc.sql OUTPUT clause CASTs every deleted.* / inserted.*
  value to NVARCHAR(255):
    NVARCHAR/VARCHAR  -> CAST(... AS NVARCHAR(255))
    DATE              -> CONVERT(NVARCHAR(255), ..., 23)
    INT/DECIMAL/BIT   -> CAST(... AS NVARCHAR(255))
Reject if any deleted.* / inserted.* appears without an explicit CAST/CONVERT


6. MERGE Procedure Validation (ddl/04_merge_proc.sql)
Verify ALL of the following:
Guardrails present:

THROW 51000 (empty staging)
THROW 51001 (NULL key)
THROW 51002 (row count variance)
THROW 51003 (soft delete cap)


MERGE ON clause:
Must match business key:
Example:
tgt.PosPosition = src.PosPosition
AND ISNULL(tgt.EmplId, '') = ISNULL(src.EmplId, '')
Rules:

All key columns included
NULL-safe logic used where required
NO attribute columns included
NO metadata columns included


MERGE logic:

MATCHED → UPDATE
NOT MATCHED → INSERT
NOT MATCHED BY SOURCE → soft delete


HASHBYTES:


Includes:

All data columns
All key columns



Excludes:

Report metadata
Audit/system fields




Additional checks:

WITH (HOLDLOCK) used
;MERGE prefix present
OUTPUT clause present
ActionType correctly derived
Transaction + TRY/CATCH exists
Summary SELECT at end

OUTPUT/INTO Column Alignment Check (CRITICAL — silent data corruption if wrong):

SQL Server assigns OUTPUT values to INTO columns by POSITION, not by alias name.
Print the OUTPUT expression list and the INTO column list side by side.
Verify EVERY row matches — not just the first few.

Valid patterns (pick one and use it consistently throughout the proc):
  Sequential: OUTPUT all Olds then all News → INTO all Olds then all News
  Interleaved: OUTPUT Old/New pairs → INTO Old/New pairs

Reject if OUTPUT is sequential but INTO is interleaved (or vice versa).
This is a silent bug — SQL Server writes values to wrong columns without error.


7. R ETL Script Validation
Verify:
API Configuration:

api_name correct
HTTP method matches discovery (GET or POST)


Column Handling:

rename(any_of(...)) used
expected matches staging
missing columns backfilled as NA


Business Key Handling (CRITICAL)

Primary identity column validated (hard stop if missing)
Secondary key columns normalized

For SO001HRORG:


PosPosition:

must NOT be NULL
rows dropped if NULL



EmplId:

NULL → replaced with ""




Deduplication (MANDATORY for report APIs)
Verify:

Dedup happens BEFORE dbWriteTable
Dedup uses ONLY business key

Example:
PosPosition + EmplId

Uses fromLast = TRUE
Logs number of duplicates removed


Reject if:

Dedup uses attribute columns
Dedup missing
Dedup happens after load


8. Report Metadata Handling
Verify:
Metadata columns (e.g., ReportName, SubTitle, RunDate):

Present in staging
NOT in target
NOT in audit
NOT in MERGE ON
NOT in HASHBYTES


9. Data Integrity Validation
Verify:

Staging data can contain duplicates
Target data MUST be unique on business key
MERGE source MUST be unique (after dedup)


10. SO001HRORG Specific Checks
Verify:

Composite key used: PosPosition + EmplId
FutureTermReason NOT part of key
Dedup removes only 4 rows (known artifact)
Staging has no PK
R script contains dedup logic


11. Cross-File Consistency
Verify:

Column names match across:

staging
R script
MERGE


Key columns consistent everywhere
HASHBYTES columns match MERGE comparisons


Output Requirement
Report:

Any violations found
Exact issue
File name
Line reference if possible

Do NOT suggest changes without first identifying issues clearly.