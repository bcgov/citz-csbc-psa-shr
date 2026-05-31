/*=============================================================================
File: adhoc__null_key_check.sql
Purpose: Validate no NULL business key values exist in the target table.
Notes:
  - PosPosition must never be NULL (enforced by MERGE guardrail 0b and R ETL).
  - EmplId must never be NULL (vacant positions use '' not NULL;
    enforced via NOT NULL DEFAULT ('') column definition and R ETL normalization).
  - Should return 0 rows under normal operation.
=============================================================================*/

SET NOCOUNT ON;

-- NULL PosPosition check (should always be 0)
SELECT
    'NULL PosPosition'  AS CheckType,
    COUNT(*)            AS ViolationCount
FROM dbo.Peoplesoft_SO001HRORG
WHERE PosPosition IS NULL

UNION ALL

-- NULL EmplId check (should always be 0; vacant rows use '' not NULL)
SELECT
    'NULL EmplId'       AS CheckType,
    COUNT(*)            AS ViolationCount
FROM dbo.Peoplesoft_SO001HRORG
WHERE EmplId IS NULL;
