-- tip__by_org.sql
-- Position tenure by organisation hierarchy. Active records only.
SET NOCOUNT ON;

SELECT
    Organization,
    Level1,
    Level2,
    DeptId,
    COUNT(*)                     AS PositionCount,
    COUNT(DISTINCT EmployeeId)   AS UniqueEmployees,
    AVG(DaysInPosition)          AS AvgDaysInPosition,
    AVG(YearsInPosition)         AS AvgYearsInPosition,
    MIN(EntryDate)               AS EarliestEntryDate,
    MAX(EntryDate)               AS LatestEntryDate
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
GROUP BY Organization, Level1, Level2, DeptId
ORDER BY Organization, Level1, Level2, AvgYearsInPosition DESC;
