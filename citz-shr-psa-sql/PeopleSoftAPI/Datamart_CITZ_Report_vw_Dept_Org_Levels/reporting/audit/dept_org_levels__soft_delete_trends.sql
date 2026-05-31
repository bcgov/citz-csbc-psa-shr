/*=============================================================================
File: dept_org_levels__soft_delete_trends.sql
Purpose: Trend soft deletes over time (daily) + highlight spike days.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @DaysBack INT = 90;  -- lookback window

;WITH daily AS
(
    SELECT
        CAST(AuditDtmUtc AS date) AS AuditDate,
        COUNT(*) AS SoftDeletes
    FROM dbo.PeopleSoft_Dept_Org_Levels_Audit
    WHERE ActionType = 'SOFT_DELETE'
      AND AuditDtmUtc >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY CAST(AuditDtmUtc AS date)
),
stats AS
(
    SELECT
        *,
        AVG(CAST(SoftDeletes AS FLOAT)) OVER () AS AvgSoftDeletes,
        STDEV(CAST(SoftDeletes AS FLOAT)) OVER () AS StdSoftDeletes
    FROM daily
)
SELECT
    AuditDate,
    SoftDeletes,
    AvgSoftDeletes,
    StdSoftDeletes,
    CASE
        WHEN StdSoftDeletes IS NULL OR StdSoftDeletes = 0 THEN 0
        WHEN SoftDeletes > (AvgSoftDeletes + (3 * StdSoftDeletes)) THEN 1
        ELSE 0
    END AS Flag_Spike_3Sigma
FROM stats
ORDER BY AuditDate DESC;