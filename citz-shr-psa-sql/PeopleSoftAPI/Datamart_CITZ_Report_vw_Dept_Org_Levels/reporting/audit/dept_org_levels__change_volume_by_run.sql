/*=============================================================================
File: dept_org_levels__change_volume_by_run.sql
Purpose: Change volume trend by RunId (spot spikes/outliers).
=============================================================================*/

SET NOCOUNT ON;

;WITH run_agg AS
(
    SELECT
        RunId,
        MIN(AuditDtmUtc) AS RunStartUtc,
        COUNT(*) AS TotalEvents,
        SUM(CASE WHEN ActionType = 'INSERT' THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN ActionType = 'UPDATE' THEN 1 ELSE 0 END) AS Updates,
        SUM(CASE WHEN ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
        SUM(CASE WHEN ActionType = 'REACTIVATE' THEN 1 ELSE 0 END) AS Reactivations
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    GROUP BY RunId
),
stats AS
(
    SELECT
        *,
        AVG(CAST(TotalEvents AS FLOAT)) OVER () AS AvgEvents_AllTime,
        AVG(CAST(SoftDeletes AS FLOAT)) OVER () AS AvgSoftDeletes_AllTime
    FROM run_agg
)
SELECT TOP (100)
    RunId,
    RunStartUtc,
    TotalEvents,
    Inserts, Updates, SoftDeletes, Reactivations,

    -- Simple flags to eyeball anomalies (tune thresholds to your comfort)
    CASE WHEN TotalEvents > (AvgEvents_AllTime * 3) THEN 1 ELSE 0 END AS Flag_TotalEvents_High,
    CASE WHEN SoftDeletes > (AvgSoftDeletes_AllTime * 3) THEN 1 ELSE 0 END AS Flag_SoftDeletes_High
FROM stats
ORDER BY RunStartUtc DESC;