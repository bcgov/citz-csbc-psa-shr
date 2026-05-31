-- tip__trend.sql
-- Weekly INSERT volume by CurrentOrHistorical category.
-- Helps identify when historical vs current records are loaded.
SET NOCOUNT ON;

SELECT
    DATEPART(YEAR,  a.AuditDtmUtc)     AS AuditYear,
    DATEPART(WEEK,  a.AuditDtmUtc)     AS AuditWeek,
    a.NewCurrentOrHistorical            AS CurrentOrHistorical,
    COUNT(*)                            AS Inserted,
    COUNT(DISTINCT a.EmployeeId)        AS UniqueEmployees
FROM dbo.Peoplesoft_TIP_Audit a
WHERE a.ActionType = 'INSERT'
GROUP BY
    DATEPART(YEAR,  a.AuditDtmUtc),
    DATEPART(WEEK,  a.AuditDtmUtc),
    a.NewCurrentOrHistorical
ORDER BY AuditYear DESC, AuditWeek DESC, CurrentOrHistorical;
