/*=============================================================================
File:    pos__soft_deleted_positions.sql
Purpose: Positions soft-deleted (IsActive 1 -> 0) in the latest ETL run.
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
    OldName            AS Name,
    OldTitle           AS Title,
    OldOrganization    AS Organization,
    OldLevel1          AS Level1,
    OldLevel2          AS Level2,
    OldLevel3          AS Level3,
    OldPosDepartment   AS PosDepartment,
    OldStatus          AS Status,
    AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE RunId = @RunId
  AND ActionType = 'SOFT_DELETE'
ORDER BY PosPosition;
