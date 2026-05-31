-- tip__daily_summary.sql
-- High-level active/historical counts by CurrentOrHistorical flag.
SET NOCOUNT ON;

SELECT
    CurrentOrHistorical,
    CurrentStatus,
    ClassificationGroupAtEntry,
    COUNT(*)                     AS RecordCount,
    COUNT(DISTINCT EmployeeId)   AS UniqueEmployees,
    AVG(DaysInPosition)          AS AvgDaysInPosition,
    MIN(EntryDate)               AS EarliestEntryDate,
    MAX(EntryDate)               AS LatestEntryDate
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
GROUP BY CurrentOrHistorical, CurrentStatus, ClassificationGroupAtEntry
ORDER BY CurrentOrHistorical, RecordCount DESC;
