/*=============================================================================
File:    adhoc__duplicate_key_check.sql
Purpose: Validate uniqueness of the composite business key (PosPosition, EmplId).
         Should return 0 rows on a clean target table.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    PosPosition,
    EmplId,
    COUNT(*) AS DuplicateCount
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1
GROUP BY PosPosition, EmplId
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC;
