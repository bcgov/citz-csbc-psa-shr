/*=============================================================================
File:    pos__new_positions.sql
Purpose: Positions inserted during the latest ETL run.
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
    NewName            AS Name,
    NewTitle           AS Title,
    NewOrganization    AS Organization,
    NewLevel1          AS Level1,
    NewLevel2          AS Level2,
    NewLevel3          AS Level3,
    NewPosDepartment   AS PosDepartment,
    NewStatus          AS Status,
    AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE RunId = @RunId
  AND ActionType = 'INSERT'
ORDER BY PosPosition;
