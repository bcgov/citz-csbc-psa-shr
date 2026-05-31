-- adhoc__duplicate_key_check.sql
-- Verify no duplicate EmplId values exist in the target table.
-- Expected result: 0 rows.

SELECT
    EmplId,
    COUNT(*)    AS DuplicateCount
FROM dbo.Peoplesoft_SHR010HRORG
GROUP BY EmplId
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC;
