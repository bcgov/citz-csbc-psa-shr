-- adhoc__duplicate_key_check.sql
-- Verify business key uniqueness in the staging and target tables.
-- Run ad hoc to investigate duplicate key warnings.
SET NOCOUNT ON;

-- Staging duplicates
SELECT
    EmplId,
    EffDt,
    EffSeq,
    EmplRcd,
    COUNT(*)   AS DupCount
FROM dbo.Stg_Peoplesoft_HEM
GROUP BY EmplId, EffDt, EffSeq, EmplRcd
HAVING COUNT(*) > 1
ORDER BY DupCount DESC;

-- Target should have no duplicates (enforced by PK), but verify just in case
SELECT
    EmplId,
    EffDt,
    EffSeq,
    EmplRcd,
    COUNT(*)   AS DupCount
FROM dbo.Peoplesoft_HEM
GROUP BY EmplId, EffDt, EffSeq, EmplRcd
HAVING COUNT(*) > 1
ORDER BY DupCount DESC;
