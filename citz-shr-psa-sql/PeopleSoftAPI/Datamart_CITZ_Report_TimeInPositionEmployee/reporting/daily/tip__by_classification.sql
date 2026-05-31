-- tip__by_classification.sql
-- Position tenure broken down by classification group. Active records only.
SET NOCOUNT ON;

SELECT
    ClassificationGroupAtEntry,
    JobCodeDescGroupAtEntry,
    COUNT(*)                                AS PositionCount,
    COUNT(DISTINCT EmployeeId)              AS UniqueEmployees,
    AVG(DaysInPosition)                     AS AvgDaysInPosition,
    AVG(YearsInPosition)                    AS AvgYearsInPosition,
    SUM(CASE WHEN ExitDate IS NULL THEN 1 ELSE 0 END)  AS CurrentlyInPosition,
    SUM(CASE WHEN ExitDate IS NOT NULL THEN 1 ELSE 0 END) AS Exited
FROM dbo.Peoplesoft_TIP
WHERE IsActive = 1
GROUP BY ClassificationGroupAtEntry, JobCodeDescGroupAtEntry
ORDER BY ClassificationGroupAtEntry, AvgYearsInPosition DESC;
