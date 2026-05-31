-- tip__time_in_position_summary.sql
-- Average and median time in position by classification group at entry.
-- Active records only.
SET NOCOUNT ON;

SELECT
    ClassificationGroupAtEntry,
    JobCodeAtEntry,
    COUNT(*)                     AS PositionCount,
    AVG(DaysInPosition)          AS AvgDaysInPosition,
    AVG(YearsInPosition)         AS AvgYearsInPosition,
    MIN(YearsInPosition)         AS MinYearsInPosition,
    MAX(YearsInPosition)         AS MaxYearsInPosition
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
GROUP BY ClassificationGroupAtEntry, JobCodeAtEntry
ORDER BY AvgYearsInPosition DESC;
