/*=============================================================================
File:    pos__position_movement.sql
Purpose: Positions that changed Organization or Level hierarchy in the latest run.
         Use to detect workforce restructuring events.
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
    OldLevel1          AS WasLevel1,
    NewLevel1          AS NowLevel1,
    OldLevel2          AS WasLevel2,
    NewLevel2          AS NowLevel2,
    OldLevel3          AS WasLevel3,
    NewLevel3          AS NowLevel3,
    AuditDtmUtc
FROM dbo.Peoplesoft_SO001HRORG_Audit
WHERE RunId = @RunId
  AND ActionType IN ('UPDATE', 'REACTIVATE')
  AND (
       ISNULL(OldOrganization,'') <> ISNULL(NewOrganization,'')
    OR ISNULL(OldLevel1,'') <> ISNULL(NewLevel1,'')
    OR ISNULL(OldLevel2,'') <> ISNULL(NewLevel2,'')
    OR ISNULL(OldLevel3,'') <> ISNULL(NewLevel3,'')
  )
ORDER BY AuditDtmUtc DESC, PosPosition;
