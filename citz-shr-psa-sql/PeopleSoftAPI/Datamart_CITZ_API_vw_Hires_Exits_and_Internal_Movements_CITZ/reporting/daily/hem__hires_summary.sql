-- hem__hires_summary.sql
-- Count of hires (MoveType = 'Hire') by fiscal year and department, active records only.
SET NOCOUNT ON;

SELECT
    FiscalYear,
    NewOrganization,
    NewDeptId,
    NewDeptIdDescr,
    NewLevel1,
    NewClassificationGroup,
    NewSalAdminPlan,
    COUNT(*)                     AS HireCount,
    AVG(NewAnnualRt)             AS AvgAnnualRt
FROM dbo.Peoplesoft_HEM
WHERE IsActive   = 1
  AND MoveType   = 'Hire'
GROUP BY
    FiscalYear, NewOrganization, NewDeptId, NewDeptIdDescr,
    NewLevel1, NewClassificationGroup, NewSalAdminPlan
ORDER BY FiscalYear DESC, HireCount DESC;
