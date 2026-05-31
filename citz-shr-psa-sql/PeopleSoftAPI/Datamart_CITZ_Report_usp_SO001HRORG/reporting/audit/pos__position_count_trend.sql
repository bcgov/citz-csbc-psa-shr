/*=============================================================================
File:    pos__position_count_trend.sql
Purpose: Trend of active position count per ETL run.
         Useful for spotting unexpected bulk changes over time.
=============================================================================*/

SET NOCOUNT ON;

SELECT TOP (60)
    a.RunId,
    MIN(a.AuditDtmUtc)          AS RunStartUtc,
    COUNT(DISTINCT t.PosPosition) AS ActivePositions,
    SUM(CASE WHEN t.EmplId <> '' THEN 1 ELSE 0 END) AS FilledPositions,
    SUM(CASE WHEN t.EmplId = '' THEN 1 ELSE 0 END)  AS VacantPositions
FROM (
    SELECT DISTINCT RunId, AuditDtmUtc
    FROM dbo.Peoplesoft_SO001HRORG_Audit
) a
CROSS JOIN dbo.Peoplesoft_SO001HRORG t
WHERE t.IsActive = 1
GROUP BY a.RunId
ORDER BY MIN(a.AuditDtmUtc) DESC;
