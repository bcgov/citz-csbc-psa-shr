-- tip__reactivation_trends.sql
-- Detail of reactivation events (records that were soft-deleted then returned).
SET NOCOUNT ON;

SELECT
    CAST(a.AuditDtmUtc AS DATE)   AS AuditDate,
    a.RunId,
    a.EmployeeId,
    a.Position,
    a.EntryDate,
    a.NewOrganization              AS Organization,
    a.NewLevel1                    AS Level1,
    a.NewCurrentOrHistorical       AS CurrentOrHistorical
FROM dbo.Peoplesoft_TIP_Audit a
WHERE a.ActionType = 'REACTIVATE'
ORDER BY AuditDate DESC, a.EmployeeId;
