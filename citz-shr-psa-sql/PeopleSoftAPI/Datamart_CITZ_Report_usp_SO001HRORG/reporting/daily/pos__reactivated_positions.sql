/*=============================================================================
File:    pos__reactivated_positions.sql
Purpose: Positions reactivated (IsActive 0 -> 1) in the latest ETL run.
=============================================================================*/

SET NOCOUNT ON;

DECLARE @RunId UNIQUEIDENTIFIER =
(
    SELECT TOP (1) RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
    ORDER BY AuditDtmUtc DESC
);

SELECT
    PosPosition,
    EmplId,
    OldOrganization    AS WasOrganization,
    NewOrganization    AS NowOrganization,
    OldTitle           AS WasTitle,
    NewTitle           AS NowTitle,
    OldName            AS WasName,
    NewName            AS NowName,
    OldIsActive        AS WasActive,
    NewIsActive        AS NowActive,
    AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE RunId = @RunId
  AND ActionType = 'REACTIVATE'
ORDER BY PosPosition;
