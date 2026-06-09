/*=============================================================================
File:    hem__update_history_by_column.sql
Purpose:
  Show ALL update events across entire audit history.
  Only displays the column(s) that actually changed per row.
  Includes current Name and Organization from target table for context.
  Use to diagnose which columns are triggering false updates.
Note:
  The audit table tracks 32 key columns. The merge proc uses a 104-column
  RowHash for change detection. If updates appear here with NO column
  changes, the cause is a hash formula mismatch (rebase RowHash needed).
=============================================================================*/

SET NOCOUNT ON;

SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.EmplId,
    a.EffDt,
    a.EffSeq,
    a.EmplRcd,
    t.Name              AS CurrentName,
    t.NewOrganization   AS CurrentOrganization,

    CASE WHEN ISNULL(CAST(a.OldCompChange AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewCompChange AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldCompChange AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewCompChange AS NVARCHAR(255)),'<NULL>'))
    END AS CompChange_Change,

    CASE WHEN ISNULL(CAST(a.OldFiscalYear AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewFiscalYear AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldFiscalYear AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewFiscalYear AS NVARCHAR(255)),'<NULL>'))
    END AS FiscalYear_Change,

    CASE WHEN ISNULL(CAST(a.OldMoveType AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldMoveType AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewMoveType AS NVARCHAR(255)),'<NULL>'))
    END AS MoveType_Change,

    CASE WHEN ISNULL(CAST(a.OldMoveType1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType1 AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldMoveType1 AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewMoveType1 AS NVARCHAR(255)),'<NULL>'))
    END AS MoveType1_Change,

    CASE WHEN ISNULL(CAST(a.OldMoveType2 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType2 AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldMoveType2 AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewMoveType2 AS NVARCHAR(255)),'<NULL>'))
    END AS MoveType2_Change,

    CASE WHEN ISNULL(CAST(a.OldName AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewName AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldName AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewName AS NVARCHAR(255)),'<NULL>'))
    END AS Name_Change,

    CASE WHEN ISNULL(CAST(a.OldNewAction AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewAction AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewAction AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewAction AS NVARCHAR(255)),'<NULL>'))
    END AS NewAction_Change,

    CASE WHEN ISNULL(CAST(a.OldNewActionReasonDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewActionReasonDescr AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewActionReasonDescr AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewActionReasonDescr AS NVARCHAR(255)),'<NULL>'))
    END AS NewActionReasonDescr_Change,

    CASE WHEN ISNULL(CAST(a.OldNewAnnualRt AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewAnnualRt AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewAnnualRt AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewAnnualRt AS NVARCHAR(255)),'<NULL>'))
    END AS NewAnnualRt_Change,

    CASE WHEN ISNULL(CAST(a.OldNewDeptId AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewDeptId AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewDeptId AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewDeptId AS NVARCHAR(255)),'<NULL>'))
    END AS NewDeptId_Change,

    CASE WHEN ISNULL(CAST(a.OldNewDeptIdDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewDeptIdDescr AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewDeptIdDescr AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewDeptIdDescr AS NVARCHAR(255)),'<NULL>'))
    END AS NewDeptIdDescr_Change,

    CASE WHEN ISNULL(CAST(a.OldNewEmplCtg AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewEmplCtg AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewEmplCtg AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewEmplCtg AS NVARCHAR(255)),'<NULL>'))
    END AS NewEmplCtg_Change,

    CASE WHEN ISNULL(CAST(a.OldNewEmplStatus AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewEmplStatus AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewEmplStatus AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewEmplStatus AS NVARCHAR(255)),'<NULL>'))
    END AS NewEmplStatus_Change,

    CASE WHEN ISNULL(CAST(a.OldNewGrade AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewGrade AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewGrade AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewGrade AS NVARCHAR(255)),'<NULL>'))
    END AS NewGrade_Change,

    CASE WHEN ISNULL(CAST(a.OldNewLevel1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewLevel1 AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewLevel1 AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewLevel1 AS NVARCHAR(255)),'<NULL>'))
    END AS NewLevel1_Change,

    CASE WHEN ISNULL(CAST(a.OldNewLevel2 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewLevel2 AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewLevel2 AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewLevel2 AS NVARCHAR(255)),'<NULL>'))
    END AS NewLevel2_Change,

    CASE WHEN ISNULL(CAST(a.OldNewOrganization AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewOrganization AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewOrganization AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewOrganization AS NVARCHAR(255)),'<NULL>'))
    END AS NewOrganization_Change,

    CASE WHEN ISNULL(CAST(a.OldNewPositionNbr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewPositionNbr AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewPositionNbr AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewPositionNbr AS NVARCHAR(255)),'<NULL>'))
    END AS NewPositionNbr_Change,

    CASE WHEN ISNULL(CAST(a.OldNewSalAdminPlan AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewSalAdminPlan AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewSalAdminPlan AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewSalAdminPlan AS NVARCHAR(255)),'<NULL>'))
    END AS NewSalAdminPlan_Change,

    CASE WHEN ISNULL(CAST(a.OldNewStep AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewStep AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewStep AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewStep AS NVARCHAR(255)),'<NULL>'))
    END AS NewStep_Change,

    CASE WHEN ISNULL(CAST(a.OldNewSupervisor AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewSupervisor AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldNewSupervisor AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewNewSupervisor AS NVARCHAR(255)),'<NULL>'))
    END AS NewSupervisor_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorAction AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorAction AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorAction AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorAction AS NVARCHAR(255)),'<NULL>'))
    END AS PriorAction_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorAnnualRt AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorAnnualRt AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorAnnualRt AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorAnnualRt AS NVARCHAR(255)),'<NULL>'))
    END AS PriorAnnualRt_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorDeptId AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorDeptId AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorDeptId AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorDeptId AS NVARCHAR(255)),'<NULL>'))
    END AS PriorDeptId_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorDeptIdDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorDeptIdDescr AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorDeptIdDescr AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorDeptIdDescr AS NVARCHAR(255)),'<NULL>'))
    END AS PriorDeptIdDescr_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorEmplCtg AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorEmplCtg AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorEmplCtg AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorEmplCtg AS NVARCHAR(255)),'<NULL>'))
    END AS PriorEmplCtg_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorEmplStatus AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorEmplStatus AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorEmplStatus AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorEmplStatus AS NVARCHAR(255)),'<NULL>'))
    END AS PriorEmplStatus_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorGrade AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorGrade AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorGrade AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorGrade AS NVARCHAR(255)),'<NULL>'))
    END AS PriorGrade_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorLevel1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorLevel1 AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorLevel1 AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorLevel1 AS NVARCHAR(255)),'<NULL>'))
    END AS PriorLevel1_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorOrganization AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorOrganization AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorOrganization AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorOrganization AS NVARCHAR(255)),'<NULL>'))
    END AS PriorOrganization_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorSalAdminPlan AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorSalAdminPlan AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorSalAdminPlan AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorSalAdminPlan AS NVARCHAR(255)),'<NULL>'))
    END AS PriorSalAdminPlan_Change,

    CASE WHEN ISNULL(CAST(a.OldPriorStep AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorStep AS NVARCHAR(255)),'')
         THEN CONCAT(ISNULL(CAST(a.OldPriorStep AS NVARCHAR(255)),'<NULL>'), ' -> ', ISNULL(CAST(a.NewPriorStep AS NVARCHAR(255)),'<NULL>'))
    END AS PriorStep_Change

FROM dbo.Peoplesoft_HEM_Audit a
LEFT JOIN dbo.Peoplesoft_HEM t
    ON  t.EmplId  = a.EmplId
    AND t.EffDt   = a.EffDt
    AND t.EffSeq  = a.EffSeq
    AND t.EmplRcd = a.EmplRcd
WHERE a.ActionType = 'UPDATE'
  AND (
       ISNULL(CAST(a.OldCompChange AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewCompChange AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldFiscalYear AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewFiscalYear AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldMoveType AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldMoveType1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType1 AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldMoveType2 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewMoveType2 AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldName AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewName AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewAction AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewAction AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewActionReasonDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewActionReasonDescr AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewAnnualRt AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewAnnualRt AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewDeptId AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewDeptId AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewDeptIdDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewDeptIdDescr AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewEmplCtg AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewEmplCtg AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewEmplStatus AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewEmplStatus AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewGrade AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewGrade AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewLevel1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewLevel1 AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewLevel2 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewLevel2 AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewOrganization AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewOrganization AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewPositionNbr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewPositionNbr AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewSalAdminPlan AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewSalAdminPlan AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewStep AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewStep AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldNewSupervisor AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewNewSupervisor AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorAction AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorAction AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorAnnualRt AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorAnnualRt AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorDeptId AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorDeptId AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorDeptIdDescr AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorDeptIdDescr AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorEmplCtg AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorEmplCtg AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorEmplStatus AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorEmplStatus AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorGrade AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorGrade AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorLevel1 AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorLevel1 AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorOrganization AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorOrganization AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorSalAdminPlan AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorSalAdminPlan AS NVARCHAR(255)),'')
    OR ISNULL(CAST(a.OldPriorStep AS NVARCHAR(255)),'') <> ISNULL(CAST(a.NewPriorStep AS NVARCHAR(255)),'')
  )
ORDER BY a.AuditDtmUtc DESC, a.EmplId, a.EffDt;