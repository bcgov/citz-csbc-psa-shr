-- adhoc__null_key_check.sql
-- Count NULL and blank values in business key columns across staging and target.
SET NOCOUNT ON;

-- Staging null key check
SELECT
    SUM(CASE WHEN EmployeeId IS NULL OR EmployeeId = '' THEN 1 ELSE 0 END) AS NullEmployeeId,
    SUM(CASE WHEN Position IS NULL OR Position = ''    THEN 1 ELSE 0 END) AS NullPosition,
    SUM(CASE WHEN EntryDate IS NULL                    THEN 1 ELSE 0 END) AS NullEntryDate,
    SUM(CASE WHEN EntrySeq IS NULL                     THEN 1 ELSE 0 END) AS NullEntrySeq,
    COUNT(*)                                                                AS TotalRows
FROM dbo.Stg_Peoplesoft_TIP;

-- Target null key check (should be 0 — enforced by NOT NULL constraint on PK cols)
SELECT
    SUM(CASE WHEN EmployeeId IS NULL OR EmployeeId = '' THEN 1 ELSE 0 END) AS NullEmployeeId,
    SUM(CASE WHEN Position IS NULL OR Position = ''    THEN 1 ELSE 0 END) AS NullPosition,
    SUM(CASE WHEN EntryDate IS NULL                    THEN 1 ELSE 0 END) AS NullEntryDate,
    SUM(CASE WHEN EntrySeq IS NULL                     THEN 1 ELSE 0 END) AS NullEntrySeq,
    COUNT(*)                                                                AS TotalRows
FROM dbo.Peoplesoft_TIP;
