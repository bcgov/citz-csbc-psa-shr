/*=============================================================================
File:    pos__run_history.sql
Purpose: Run ledger from audit events. One row per RunId.
Notes:
  - Uses MIN(AuditDtmUtc) as run start, MAX as run end.
  - RunDurationSeconds is approximate for the audit write window.
=============================================================================*/

SET NOCOUNT ON;

;WITH run_agg AS
(
    SELECT
        RunId,
        MIN(AuditDtmUtc)                                             AS RunStartUtc,
        MAX(AuditDtmUtc)                                             AS RunEndUtc,
        COUNT(*)                                                     AS TotalEvents,
        SUM(CASE WHEN ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
        SUM(CASE WHEN ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations
    FROM dbo.Peoplesoft_SO001HRORG_Audit
    GROUP BY RunId
)
SELECT TOP (50)
    RunId,
    RunStartUtc,
    RunEndUtc,
    DATEDIFF(SECOND, RunStartUtc, RunEndUtc) AS RunDurationSeconds,
    TotalEvents,
    Inserts,
    Updates,
    SoftDeletes,
    Reactivations
FROM run_agg
ORDER BY RunStartUtc DESC;
