/*=============================================================================
File:    pos__daily_summary.sql
Purpose: Daily snapshot — current position counts and latest run change summary.
=============================================================================*/

SET NOCOUNT ON;

-- Current state (filled / vacant)
SELECT
    COUNT(*)                                       AS TotalActivePositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END) AS FilledPositions,
    SUM(CASE WHEN EmplId = '' THEN 1 ELSE 0 END)  AS VacantPositions,
    CAST(
        100.0 * SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,1))                               AS FillRatePct
FROM dbo.Peoplesoft_SO001HRORG
WHERE IsActive = 1;

-- Latest run change summary
;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
)
SELECT
    MIN(a.AuditDtmUtc)                                              AS RunStartUtc,
    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END)  AS Inserts,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END)  AS Updates,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END)  AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END)  AS Reactivations,
    COUNT(*)                                                        AS TotalEvents
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId;
