-- epc__position_change_history.sql
-- Full change history for a single position across all MERGE runs.
-- Replace the Position value to inspect a specific position.

DECLARE @Position NVARCHAR(20) = '00000000';  -- replace with target Position

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.ActionType,
    a.OldPositionTitle,
    a.NewPositionTitle,
    a.OldDeptId,
    a.NewDeptId,
    a.OldDeptIdDesc,
    a.NewDeptIdDesc,
    a.OldEmptyPosition,
    a.NewEmptyPosition,
    a.OldEmptyEffDt,
    a.NewEmptyEffDt,
    a.OldYearsEmpty,
    a.NewYearsEmpty,
    a.OldPositionEmptyGt1Year,
    a.NewPositionEmptyGt1Year,
    a.OldIncumbents,
    a.NewIncumbents,
    a.OldLastIncumbents,
    a.NewLastIncumbents,
    a.OldJobReqStatus,
    a.NewJobReqStatus,
    a.OldPosStatusDescr,
    a.NewPosStatusDescr,
    a.OldIsActive,
    a.NewIsActive
FROM dbo.Peoplesoft_EPC_Audit AS a
WHERE a.Position = @Position
ORDER BY a.AuditDtmUtc DESC;
