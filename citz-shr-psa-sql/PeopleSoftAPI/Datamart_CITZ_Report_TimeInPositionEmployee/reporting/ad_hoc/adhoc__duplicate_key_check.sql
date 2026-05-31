-- adhoc__duplicate_key_check.sql
-- Verify business key uniqueness in staging and target tables.
SET NOCOUNT ON;

-- Staging duplicates
SELECT
    EmployeeId,
    Position,
    EntryDate,
    EntrySeq,
    COUNT(*)   AS DupCount
FROM dbo.Stg_Peoplesoft_TIP
GROUP BY EmployeeId, Position, EntryDate, EntrySeq
HAVING COUNT(*) > 1
ORDER BY DupCount DESC;

-- Target (PK enforces uniqueness, but verify for safety)
SELECT
    EmployeeId,
    Position,
    EntryDate,
    EntrySeq,
    COUNT(*)   AS DupCount
FROM dbo.Peoplesoft_TIP
GROUP BY EmployeeId, Position, EntryDate, EntrySeq
HAVING COUNT(*) > 1
ORDER BY DupCount DESC;
