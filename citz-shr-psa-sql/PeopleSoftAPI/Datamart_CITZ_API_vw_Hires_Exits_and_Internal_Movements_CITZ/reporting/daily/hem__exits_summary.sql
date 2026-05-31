-- hem__exits_summary.sql
-- Count of exits (MoveType = 'Exit') by fiscal year, action reason, and department.
SET NOCOUNT ON;

SELECT
    FiscalYear,
    NewOrganization,
    NewDeptId,
    NewDeptIdDescr,
    NewLevel1,
    NewAction,
    NewActionReason,
    NewActionReasonDescr,
    NewLifeCycle,
    NewClassificationGroup,
    COUNT(*)                     AS ExitCount,
    AVG(NewAnnualRt)             AS AvgAnnualRt
FROM dbo.Peoplesoft_HEM
WHERE IsActive  = 1
  AND MoveType  = 'Exit'
GROUP BY
    FiscalYear, NewOrganization, NewDeptId, NewDeptIdDescr,
    NewLevel1, NewAction, NewActionReason, NewActionReasonDescr,
    NewLifeCycle, NewClassificationGroup
ORDER BY FiscalYear DESC, ExitCount DESC;
