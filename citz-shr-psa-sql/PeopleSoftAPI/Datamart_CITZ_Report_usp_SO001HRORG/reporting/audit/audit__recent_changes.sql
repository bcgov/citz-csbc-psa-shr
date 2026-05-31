/*=============================================================================
File: audit__recent_changes.sql
Purpose: Most recent audit events across all RunIds.
Notes:
  - Business key is (PosPosition, EmplId).
  - OldRowHash / NewRowHash can be compared to confirm content changed.
  - Limit TOP (200) for interactive review; adjust as needed.
=============================================================================*/

SET NOCOUNT ON;

SELECT TOP (200)
    AuditId,
    RunId,
    AuditDtmUtc,
    ActionType,
    PosPosition,
    EmplId,
    OldIsActive,
    NewIsActive,
    OldRowHash,
    NewRowHash,
    -- Snapshot of key data columns for quick review
    OldName,
    NewName,
    OldTitle,
    NewTitle,
    OldOrganization,
    NewOrganization,
    OldLevel1,
    NewLevel1,
    OldLevel2,
    NewLevel2,
    OldStatus,
    NewStatus,
    OldEmplStatus,
    NewEmplStatus
FROM dbo.Peoplesoft_SO001HRORG_Audit
ORDER BY AuditDtmUtc DESC;
