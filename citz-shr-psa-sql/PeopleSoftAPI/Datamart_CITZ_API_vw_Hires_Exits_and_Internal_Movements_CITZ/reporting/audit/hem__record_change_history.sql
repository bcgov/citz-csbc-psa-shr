-- hem__record_change_history.sql
-- Full audit history for a single movement event record.
-- Provides complete before/after state for every change detected.
SET NOCOUNT ON;

SELECT
    a.AuditId,
    a.RunId,
    a.AuditDtmUtc,
    a.ActionType,
    a.EmplId,
    a.EffDt,
    a.EffSeq,
    a.EmplRcd,
    a.OldIsActive,
    a.NewIsActive,
    a.OldRowHash,
    a.NewRowHash,
    -- Event header change
    a.OldMoveType,             a.NewMoveType,
    a.OldCompChange,           a.NewCompChange,
    -- New state key changes
    a.OldNewAction,            a.NewNewAction,
    a.OldNewActionReasonDescr, a.NewNewActionReasonDescr,
    a.OldNewEmplStatus,        a.NewNewEmplStatus,
    a.OldNewDeptId,            a.NewNewDeptId,
    a.OldNewLevel1,            a.NewNewLevel1,
    a.OldNewOrganization,      a.NewNewOrganization,
    a.OldNewAnnualRt,          a.NewNewAnnualRt
FROM dbo.Peoplesoft_HEM_Audit a
-- Filter to a specific record; replace key values as needed:
-- WHERE a.EmplId = '123456' AND a.EffDt = '2024-08-31' AND a.EffSeq = 0 AND a.EmplRcd = 0
ORDER BY a.EmplId, a.EffDt, a.AuditDtmUtc DESC;
