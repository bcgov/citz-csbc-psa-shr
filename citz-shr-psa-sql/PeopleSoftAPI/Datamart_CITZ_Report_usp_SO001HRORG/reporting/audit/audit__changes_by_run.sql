/*=============================================================================
File: audit__changes_by_run.sql
Purpose: Change volume trend by RunId — spot spikes and outliers.
Notes:
  - One row per RunId with counts split by ActionType.
  - Flag columns highlight runs with unusually high event counts (3x average).
=============================================================================*/

SET NOCOUNT ON;

;WITH run_agg AS
(
    SELECT
        RunId,
        MIN(AuditDtmUtc) AS RunStartUtc,
        MAX(AuditDtmUtc) AS RunEndUtc,
        COUNT(*)         AS TotalEvents,
        SUM(CASE WHEN ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
        SUM(CASE WHEN ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations
    FROM dbo.Peoplesoft_SO001HRORG_Audit
    GROUP BY RunId
),
stats AS
(
    SELECT
        *,
        AVG(CAST(TotalEvents  AS FLOAT)) OVER () AS AvgEvents_AllTime,
        AVG(CAST(SoftDeletes  AS FLOAT)) OVER () AS AvgSoftDeletes_AllTime
    FROM run_agg
)
SELECT TOP (100)
    RunId,
    RunStartUtc,
    RunEndUtc,
    DATEDIFF(SECOND, RunStartUtc, RunEndUtc) AS RunDurationSeconds,
    TotalEvents,
    Inserts,
    Updates,
    SoftDeletes,
    Reactivations,
    CASE WHEN TotalEvents > (AvgEvents_AllTime   * 3) THEN 1 ELSE 0 END AS Flag_TotalEvents_High,
    CASE WHEN SoftDeletes > (AvgSoftDeletes_AllTime * 3) THEN 1 ELSE 0 END AS Flag_SoftDeletes_High
FROM stats
ORDER BY RunStartUtc DESC;
