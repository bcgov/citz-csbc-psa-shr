/*=============================================================================
File: hem__update_history_by_column.sql
Purpose:
  Column-level change diagnostic for UPDATE actions in the HEM audit table.
  Shows exactly which columns changed per row. Use to identify
  continuously-computed columns causing false updates.
Audit table : dbo.Peoplesoft_HEM_Audit
Target table: dbo.Peoplesoft_HEM
Business key: EmplId, EffDt, EffSeq, EmplRcd
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId FROM dbo.Peoplesoft_HEM_Audit
)
SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.EmplId,
    a.EffDt,
    a.EffSeq,
    a.EmplRcd,
    t.Name AS CurrentName,
    a.OldRowHash,
    a.NewRowHash,

    CASE WHEN ISNULL(a.OldCompChange,'') <> ISNULL(a.NewCompChange,'')
         THEN CONCAT(ISNULL(a.OldCompChange,'<NULL>'),' -> ',ISNULL(a.NewCompChange,'<NULL>')) END AS CompChange_Change,
    CASE WHEN ISNULL(a.OldMoveType,'') <> ISNULL(a.NewMoveType,'')
         THEN CONCAT(ISNULL(a.OldMoveType,'<NULL>'),' -> ',ISNULL(a.NewMoveType,'<NULL>')) END AS MoveType_Change,
    CASE WHEN ISNULL(a.OldMoveType1,'') <> ISNULL(a.NewMoveType1,'')
         THEN CONCAT(ISNULL(a.OldMoveType1,'<NULL>'),' -> ',ISNULL(a.NewMoveType1,'<NULL>')) END AS MoveType1_Change,
    CASE WHEN ISNULL(a.OldMoveType2,'') <> ISNULL(a.NewMoveType2,'')
         THEN CONCAT(ISNULL(a.OldMoveType2,'<NULL>'),' -> ',ISNULL(a.NewMoveType2,'<NULL>')) END AS MoveType2_Change,
    CASE WHEN ISNULL(a.OldFiscalYear,'') <> ISNULL(a.NewFiscalYear,'')
         THEN CONCAT(ISNULL(a.OldFiscalYear,'<NULL>'),' -> ',ISNULL(a.NewFiscalYear,'<NULL>')) END AS FiscalYear_Change,
    CASE WHEN ISNULL(a.OldName,'') <> ISNULL(a.NewName,'')
         THEN CONCAT(ISNULL(a.OldName,'<NULL>'),' -> ',ISNULL(a.NewName,'<NULL>')) END AS Name_Change,

    CASE WHEN ISNULL(a.OldNewAction,'') <> ISNULL(a.NewNewAction,'')
         THEN CONCAT(ISNULL(a.OldNewAction,'<NULL>'),' -> ',ISNULL(a.NewNewAction,'<NULL>')) END AS NewAction_Change,
    CASE WHEN ISNULL(a.OldNewActionReasonDescr,'') <> ISNULL(a.NewNewActionReasonDescr,'')
         THEN CONCAT(ISNULL(a.OldNewActionReasonDescr,'<NULL>'),' -> ',ISNULL(a.NewNewActionReasonDescr,'<NULL>')) END AS NewActionReasonDescr_Change,
    CASE WHEN ISNULL(a.OldNewEmplStatus,'') <> ISNULL(a.NewNewEmplStatus,'')
         THEN CONCAT(ISNULL(a.OldNewEmplStatus,'<NULL>'),' -> ',ISNULL(a.NewNewEmplStatus,'<NULL>')) END AS NewEmplStatus_Change,
    CASE WHEN ISNULL(a.OldNewEmplCtg,'') <> ISNULL(a.NewNewEmplCtg,'')
         THEN CONCAT(ISNULL(a.OldNewEmplCtg,'<NULL>'),' -> ',ISNULL(a.NewNewEmplCtg,'<NULL>')) END AS NewEmplCtg_Change,
    CASE WHEN ISNULL(a.OldNewDeptId,'') <> ISNULL(a.NewNewDeptId,'')
         THEN CONCAT(ISNULL(a.OldNewDeptId,'<NULL>'),' -> ',ISNULL(a.NewNewDeptId,'<NULL>')) END AS NewDeptId_Change,
    CASE WHEN ISNULL(a.OldNewDeptIdDescr,'') <> ISNULL(a.NewNewDeptIdDescr,'')
         THEN CONCAT(ISNULL(a.OldNewDeptIdDescr,'<NULL>'),' -> ',ISNULL(a.NewNewDeptIdDescr,'<NULL>')) END AS NewDeptIdDescr_Change,
    CASE WHEN ISNULL(a.OldNewLevel1,'') <> ISNULL(a.NewNewLevel1,'')
         THEN CONCAT(ISNULL(a.OldNewLevel1,'<NULL>'),' -> ',ISNULL(a.NewNewLevel1,'<NULL>')) END AS NewLevel1_Change,
    CASE WHEN ISNULL(a.OldNewLevel2,'') <> ISNULL(a.NewNewLevel2,'')
         THEN CONCAT(ISNULL(a.OldNewLevel2,'<NULL>'),' -> ',ISNULL(a.NewNewLevel2,'<NULL>')) END AS NewLevel2_Change,
    CASE WHEN ISNULL(a.OldNewOrganization,'') <> ISNULL(a.NewNewOrganization,'')
         THEN CONCAT(ISNULL(a.OldNewOrganization,'<NULL>'),' -> ',ISNULL(a.NewNewOrganization,'<NULL>')) END AS NewOrganization_Change,
    CASE WHEN ISNULL(a.OldNewSalAdminPlan,'') <> ISNULL(a.NewNewSalAdminPlan,'')
         THEN CONCAT(ISNULL(a.OldNewSalAdminPlan,'<NULL>'),' -> ',ISNULL(a.NewNewSalAdminPlan,'<NULL>')) END AS NewSalAdminPlan_Change,
    CASE WHEN ISNULL(a.OldNewGrade,'') <> ISNULL(a.NewNewGrade,'')
         THEN CONCAT(ISNULL(a.OldNewGrade,'<NULL>'),' -> ',ISNULL(a.NewNewGrade,'<NULL>')) END AS NewGrade_Change,
    CASE WHEN ISNULL(a.OldNewStep,'') <> ISNULL(a.NewNewStep,'')
         THEN CONCAT(ISNULL(a.OldNewStep,'<NULL>'),' -> ',ISNULL(a.NewNewStep,'<NULL>')) END AS NewStep_Change,
    CASE WHEN ISNULL(a.OldNewAnnualRt,'') <> ISNULL(a.NewNewAnnualRt,'')
         THEN CONCAT(ISNULL(a.OldNewAnnualRt,'<NULL>'),' -> ',ISNULL(a.NewNewAnnualRt,'<NULL>')) END AS NewAnnualRt_Change,
    CASE WHEN ISNULL(a.OldNewPositionNbr,'') <> ISNULL(a.NewNewPositionNbr,'')
         THEN CONCAT(ISNULL(a.OldNewPositionNbr,'<NULL>'),' -> ',ISNULL(a.NewNewPositionNbr,'<NULL>')) END AS NewPositionNbr_Change,
    CASE WHEN ISNULL(a.OldNewSupervisor,'') <> ISNULL(a.NewNewSupervisor,'')
         THEN CONCAT(ISNULL(a.OldNewSupervisor,'<NULL>'),' -> ',ISNULL(a.NewNewSupervisor,'<NULL>')) END AS NewSupervisor_Change,

    CASE WHEN ISNULL(a.OldPriorAction,'') <> ISNULL(a.NewPriorAction,'')
         THEN CONCAT(ISNULL(a.OldPriorAction,'<NULL>'),' -> ',ISNULL(a.NewPriorAction,'<NULL>')) END AS PriorAction_Change,
    CASE WHEN ISNULL(a.OldPriorEmplStatus,'') <> ISNULL(a.NewPriorEmplStatus,'')
         THEN CONCAT(ISNULL(a.OldPriorEmplStatus,'<NULL>'),' -> ',ISNULL(a.NewPriorEmplStatus,'<NULL>')) END AS PriorEmplStatus_Change,
    CASE WHEN ISNULL(a.OldPriorEmplCtg,'') <> ISNULL(a.NewPriorEmplCtg,'')
         THEN CONCAT(ISNULL(a.OldPriorEmplCtg,'<NULL>'),' -> ',ISNULL(a.NewPriorEmplCtg,'<NULL>')) END AS PriorEmplCtg_Change,
    CASE WHEN ISNULL(a.OldPriorDeptId,'') <> ISNULL(a.NewPriorDeptId,'')
         THEN CONCAT(ISNULL(a.OldPriorDeptId,'<NULL>'),' -> ',ISNULL(a.NewPriorDeptId,'<NULL>')) END AS PriorDeptId_Change,
    CASE WHEN ISNULL(a.OldPriorDeptIdDescr,'') <> ISNULL(a.NewPriorDeptIdDescr,'')
         THEN CONCAT(ISNULL(a.OldPriorDeptIdDescr,'<NULL>'),' -> ',ISNULL(a.NewPriorDeptIdDescr,'<NULL>')) END AS PriorDeptIdDescr_Change,
    CASE WHEN ISNULL(a.OldPriorLevel1,'') <> ISNULL(a.NewPriorLevel1,'')
         THEN CONCAT(ISNULL(a.OldPriorLevel1,'<NULL>'),' -> ',ISNULL(a.NewPriorLevel1,'<NULL>')) END AS PriorLevel1_Change,
    CASE WHEN ISNULL(a.OldPriorOrganization,'') <> ISNULL(a.NewPriorOrganization,'')
         THEN CONCAT(ISNULL(a.OldPriorOrganization,'<NULL>'),' -> ',ISNULL(a.NewPriorOrganization,'<NULL>')) END AS PriorOrganization_Change,
    CASE WHEN ISNULL(a.OldPriorSalAdminPlan,'') <> ISNULL(a.NewPriorSalAdminPlan,'')
         THEN CONCAT(ISNULL(a.OldPriorSalAdminPlan,'<NULL>'),' -> ',ISNULL(a.NewPriorSalAdminPlan,'<NULL>')) END AS PriorSalAdminPlan_Change,
    CASE WHEN ISNULL(a.OldPriorGrade,'') <> ISNULL(a.NewPriorGrade,'')
         THEN CONCAT(ISNULL(a.OldPriorGrade,'<NULL>'),' -> ',ISNULL(a.NewPriorGrade,'<NULL>')) END AS PriorGrade_Change,
    CASE WHEN ISNULL(a.OldPriorStep,'') <> ISNULL(a.NewPriorStep,'')
         THEN CONCAT(ISNULL(a.OldPriorStep,'<NULL>'),' -> ',ISNULL(a.NewPriorStep,'<NULL>')) END AS PriorStep_Change,
    CASE WHEN ISNULL(a.OldPriorAnnualRt,'') <> ISNULL(a.NewPriorAnnualRt,'')
         THEN CONCAT(ISNULL(a.OldPriorAnnualRt,'<NULL>'),' -> ',ISNULL(a.NewPriorAnnualRt,'<NULL>')) END AS PriorAnnualRt_Change

FROM dbo.Peoplesoft_HEM_Audit a
INNER JOIN latest_run lr
    ON a.RunId = lr.RunId
LEFT JOIN dbo.Peoplesoft_HEM t
    ON  t.EmplId  = a.EmplId
    AND t.EffDt   = a.EffDt
    AND t.EffSeq  = a.EffSeq
    AND t.EmplRcd = a.EmplRcd
WHERE a.ActionType = 'UPDATE'
  -- Uncomment to filter by a specific business key:
  -- AND a.EmplId = '000000'
  -- AND a.EffDt  = '2022-07-11'
  -- AND a.EffSeq = 0
  -- AND a.EmplRcd = 0
  -- Uncomment to exclude rows where no projected column actually changed
  -- (i.e., hash differs but every Old/New pair is equal):
  /*
  AND (
       ISNULL(a.OldCompChange,'')         <> ISNULL(a.NewCompChange,'')
    OR ISNULL(a.OldMoveType,'')           <> ISNULL(a.NewMoveType,'')
    OR ISNULL(a.OldMoveType1,'')          <> ISNULL(a.NewMoveType1,'')
    OR ISNULL(a.OldMoveType2,'')          <> ISNULL(a.NewMoveType2,'')
    OR ISNULL(a.OldFiscalYear,'')         <> ISNULL(a.NewFiscalYear,'')
    OR ISNULL(a.OldName,'')               <> ISNULL(a.NewName,'')
    OR ISNULL(a.OldNewAction,'')          <> ISNULL(a.NewNewAction,'')
    OR ISNULL(a.OldNewActionReasonDescr,'') <> ISNULL(a.NewNewActionReasonDescr,'')
    OR ISNULL(a.OldNewEmplStatus,'')      <> ISNULL(a.NewNewEmplStatus,'')
    OR ISNULL(a.OldNewEmplCtg,'')         <> ISNULL(a.NewNewEmplCtg,'')
    OR ISNULL(a.OldNewDeptId,'')          <> ISNULL(a.NewNewDeptId,'')
    OR ISNULL(a.OldNewDeptIdDescr,'')     <> ISNULL(a.NewNewDeptIdDescr,'')
    OR ISNULL(a.OldNewLevel1,'')          <> ISNULL(a.NewNewLevel1,'')
    OR ISNULL(a.OldNewLevel2,'')          <> ISNULL(a.NewNewLevel2,'')
    OR ISNULL(a.OldNewOrganization,'')    <> ISNULL(a.NewNewOrganization,'')
    OR ISNULL(a.OldNewSalAdminPlan,'')    <> ISNULL(a.NewNewSalAdminPlan,'')
    OR ISNULL(a.OldNewGrade,'')           <> ISNULL(a.NewNewGrade,'')
    OR ISNULL(a.OldNewStep,'')            <> ISNULL(a.NewNewStep,'')
    OR ISNULL(a.OldNewAnnualRt,'')        <> ISNULL(a.NewNewAnnualRt,'')
    OR ISNULL(a.OldNewPositionNbr,'')     <> ISNULL(a.NewNewPositionNbr,'')
    OR ISNULL(a.OldNewSupervisor,'')      <> ISNULL(a.NewNewSupervisor,'')
    OR ISNULL(a.OldPriorAction,'')        <> ISNULL(a.NewPriorAction,'')
    OR ISNULL(a.OldPriorEmplStatus,'')    <> ISNULL(a.NewPriorEmplStatus,'')
    OR ISNULL(a.OldPriorEmplCtg,'')       <> ISNULL(a.NewPriorEmplCtg,'')
    OR ISNULL(a.OldPriorDeptId,'')        <> ISNULL(a.NewPriorDeptId,'')
    OR ISNULL(a.OldPriorDeptIdDescr,'')   <> ISNULL(a.NewPriorDeptIdDescr,'')
    OR ISNULL(a.OldPriorLevel1,'')        <> ISNULL(a.NewPriorLevel1,'')
    OR ISNULL(a.OldPriorOrganization,'')  <> ISNULL(a.NewPriorOrganization,'')
    OR ISNULL(a.OldPriorSalAdminPlan,'')  <> ISNULL(a.NewPriorSalAdminPlan,'')
    OR ISNULL(a.OldPriorGrade,'')         <> ISNULL(a.NewPriorGrade,'')
    OR ISNULL(a.OldPriorStep,'')          <> ISNULL(a.NewPriorStep,'')
    OR ISNULL(a.OldPriorAnnualRt,'')      <> ISNULL(a.NewPriorAnnualRt,'')
  )
  */
ORDER BY a.EmplId, a.EffDt, a.EffSeq, a.EmplRcd, a.AuditDtmUtc DESC;
