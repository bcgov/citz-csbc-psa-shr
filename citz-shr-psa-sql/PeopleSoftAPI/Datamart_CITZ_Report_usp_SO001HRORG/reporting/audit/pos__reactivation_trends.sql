/*=============================================================================
File:    pos__reactivation_trends.sql
Purpose: Trend of REACTIVATE events over time (daily).
         Rising trend may indicate data quality issues or workforce reinstatements.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @DaysBack INT = 90;

;WITH daily AS
(
    SELECT
        CAST(AuditDtmUtc AS date) AS AuditDate,
        COUNT(*)                  AS Reactivations
    FROM dbo.Peoplesoft_SO001HRORG_Audit
    WHERE ActionType = 'REACTIVATE'
      AND AuditDtmUtc >= DATEADD(DAY, -@DaysBack, SYSUTCDATETIME())
    GROUP BY CAST(AuditDtmUtc AS date)
)
SELECT
    AuditDate,
    Reactivations,
    SUM(Reactivations) OVER (ORDER BY AuditDate ROWS UNBOUNDED PRECEDING) AS CumulativeReactivations
FROM daily
ORDER BY AuditDate DESC;
