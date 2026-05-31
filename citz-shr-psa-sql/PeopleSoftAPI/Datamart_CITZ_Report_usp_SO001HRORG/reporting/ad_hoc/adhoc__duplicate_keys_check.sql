/*=============================================================================
File: adhoc__duplicate_keys_check.sql
Purpose: Detect duplicate composite business keys (PosPosition, EmplId) in target.
Notes:
  - Should return 0 rows under normal operation.
  - Any rows returned indicate a data integrity violation that must be investigated.
  - Checks all rows (active and inactive) because the PK constraint is enforced
    across the full table, not just active rows.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    PosPosition,
    EmplId,
    COUNT(*) AS DuplicateCount
FROM dbo.Peoplesoft_SO001HRORG
GROUP BY
    PosPosition,
    EmplId
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC, PosPosition;
