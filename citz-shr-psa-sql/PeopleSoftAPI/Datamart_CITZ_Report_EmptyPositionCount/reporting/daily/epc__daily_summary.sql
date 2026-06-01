-- epc__daily_summary.sql
-- One-row daily snapshot: total positions, empty count, long-term vacancy count,
-- open job req count, and soft-deleted (no longer reported) count.

SELECT
    CAST(SYSUTCDATETIME() AS DATE)                  AS ReportDate,
    SUM(1)                                          AS TotalActivePositions,
    SUM(CASE WHEN EmptyPosition = 'YES' THEN 1 ELSE 0 END)
                                                    AS EmptyPositionCount,
    SUM(CASE WHEN PositionEmptyGt1Year = 'YES' THEN 1 ELSE 0 END)
                                                    AS LongTermVacancyCount,
    SUM(CASE WHEN JobReqStatus IS NOT NULL THEN 1 ELSE 0 END)
                                                    AS OpenJobReqCount,
    SUM(CASE WHEN PositionHasBaseIncumbent = 'YES' THEN 1 ELSE 0 END)
                                                    AS HasBaseIncumbentCount,
    SUM(CASE WHEN EmptyPosition = 'YES'
              AND PositionEmptyGt1Year = 'NO' THEN 1 ELSE 0 END)
                                                    AS ShortTermVacancyCount
FROM dbo.Peoplesoft_EPC
WHERE IsActive = 1;
