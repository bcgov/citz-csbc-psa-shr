-- hem__trend.sql
-- Weekly trend of movement event INSERTs by MoveType over time.
-- Helps identify data loading patterns and API feed freshness.
SET NOCOUNT ON;

SELECT
    DATEPART(YEAR,  a.AuditDtmUtc)           AS AuditYear,
    DATEPART(WEEK,  a.AuditDtmUtc)           AS AuditWeek,
    a.NewMoveType                             AS MoveType,
    COUNT(*)                                  AS Inserted,
    COUNT(DISTINCT a.EmplId)                  AS UniqueEmployees
FROM dbo.Peoplesoft_HEM_Audit a
WHERE a.ActionType = 'INSERT'
GROUP BY
    DATEPART(YEAR,  a.AuditDtmUtc),
    DATEPART(WEEK,  a.AuditDtmUtc),
    a.NewMoveType
ORDER BY AuditYear DESC, AuditWeek DESC, MoveType;
