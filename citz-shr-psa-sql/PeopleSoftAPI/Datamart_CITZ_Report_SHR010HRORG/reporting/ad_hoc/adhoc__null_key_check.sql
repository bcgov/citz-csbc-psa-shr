-- adhoc__null_key_check.sql
-- Verify no NULL or blank EmplId values exist in the target table.
-- Expected result: 0 rows.
-- The R ETL and MERGE proc both enforce this; this query is a belt-and-suspenders check.

SELECT
    EmplId,
    Name,
    EmplStatus,
    DeptDescr,
    IsActive,
    CreatedUtc
FROM dbo.Peoplesoft_SHR010HRORG
WHERE EmplId IS NULL
   OR EmplId = ''
ORDER BY CreatedUtc DESC;
