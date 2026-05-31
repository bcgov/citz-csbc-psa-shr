-- adhoc__null_key_check.sql
-- Count NULL and blank values in business key columns across staging and target.
SET NOCOUNT ON;

-- Staging null key check
SELECT
    SUM(CASE WHEN EmplId IS NULL OR EmplId = ''  THEN 1 ELSE 0 END) AS NullEmplId,
    SUM(CASE WHEN EffDt  IS NULL                 THEN 1 ELSE 0 END) AS NullEffDt,
    SUM(CASE WHEN EffSeq IS NULL                 THEN 1 ELSE 0 END) AS NullEffSeq,
    SUM(CASE WHEN EmplRcd IS NULL                THEN 1 ELSE 0 END) AS NullEmplRcd,
    COUNT(*)                                                          AS TotalRows
FROM dbo.Stg_Peoplesoft_HEM;

-- Target null key check (should be 0 — enforced by PK NOT NULL constraint)
SELECT
    SUM(CASE WHEN EmplId IS NULL OR EmplId = ''  THEN 1 ELSE 0 END) AS NullEmplId,
    SUM(CASE WHEN EffDt  IS NULL                 THEN 1 ELSE 0 END) AS NullEffDt,
    SUM(CASE WHEN EffSeq IS NULL                 THEN 1 ELSE 0 END) AS NullEffSeq,
    SUM(CASE WHEN EmplRcd IS NULL                THEN 1 ELSE 0 END) AS NullEmplRcd,
    COUNT(*)                                                          AS TotalRows
FROM dbo.Peoplesoft_HEM;
