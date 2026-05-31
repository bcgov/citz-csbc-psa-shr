-- tip__executive_summary.sql
-- Executive summary: current vs historical position records, avg tenure, unique employees.
SET NOCOUNT ON;

SELECT
    CurrentOrHistorical,
    COUNT(*)                                                    AS TotalRecords,
    COUNT(DISTINCT EmployeeId)                                  AS UniqueEmployees,
    AVG(DaysInPosition)                                         AS AvgDaysInPosition,
    AVG(YearsInPosition)                                        AS AvgYearsInPosition,
    SUM(CASE WHEN ExitDate IS NULL THEN 1 ELSE 0 END)           AS StillInPosition,
    SUM(CASE WHEN ExitDate IS NOT NULL THEN 1 ELSE 0 END)       AS ExitedPosition,
    MIN(EntryDate)                                              AS EarliestEntryDate,
    MAX(EntryDate)                                              AS LatestEntryDate
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
GROUP BY CurrentOrHistorical
ORDER BY CurrentOrHistorical;
