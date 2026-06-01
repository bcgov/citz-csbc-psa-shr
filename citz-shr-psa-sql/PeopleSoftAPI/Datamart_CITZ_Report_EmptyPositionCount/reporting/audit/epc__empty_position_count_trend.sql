-- epc__empty_position_count_trend.sql
-- Trend of total empty positions recorded at each MERGE run.
-- Approximated from audit: sum of active empty positions at each run boundary.
-- For point-in-time accuracy, pair with a snapshot table if available.

SELECT
    a.RunId,
    MIN(a.AuditDtmUtc)                              AS RunDtmUtc,
    SUM(CASE WHEN a.ActionType IN ('INSERT','UPDATE','REACTIVATE')
                  AND a.NewEmptyPosition = 'YES' THEN 1 ELSE 0 END)
                                                    AS NewOrUpdatedEmptyPositions,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE'  THEN 1 ELSE 0 END)
                                                    AS PositionsRemovedFromReport
FROM dbo.Peoplesoft_EPC_Audit AS a
GROUP BY a.RunId
ORDER BY RunDtmUtc DESC;
