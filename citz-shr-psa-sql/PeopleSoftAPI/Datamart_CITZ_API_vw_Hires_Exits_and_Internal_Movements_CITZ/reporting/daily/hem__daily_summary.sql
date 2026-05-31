-- hem__daily_summary.sql
-- High-level counts of active movement events by MoveType and fiscal year.
SET NOCOUNT ON;

SELECT
    FiscalYear,
    MoveType,
    MoveType1,
    COUNT(*)                     AS EventCount,
    COUNT(DISTINCT EmplId)       AS UniqueEmployees,
    MIN(EffDt)                   AS EarliestEffDt,
    MAX(EffDt)                   AS LatestEffDt
FROM dbo.Peoplesoft_HEM
WHERE IsActive = 1
GROUP BY FiscalYear, MoveType, MoveType1
ORDER BY FiscalYear DESC, EventCount DESC;
