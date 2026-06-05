/*=============================================================================
File: so001hrorg__update_history_by_column.sql
Purpose:
  Column-level change diagnostic for UPDATE actions in the SO001HRORG audit table.
  Shows exactly which columns changed per row. Use to identify
  continuously-computed columns causing false updates.
Audit table : dbo.Peoplesoft_SO001HRORG_Audit
Target table: dbo.Peoplesoft_SO001HRORG
Business key: PosPosition, EmplId
  (Spec referred to the second key column as "SafeEmplId"; the actual audit
   and target schemas store it as EmplId. Aliased via SafeEmplId for clarity.)
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId FROM dbo.Peoplesoft_SO001HRORG_Audit
)
SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.PosPosition,
    a.EmplId AS SafeEmplId,
    t.Name AS CurrentName,
    a.OldRowHash,
    a.NewRowHash,

    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'),' -> ',ISNULL(a.NewOrganization,'<NULL>')) END AS Organization_Change,
    CASE WHEN ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
         THEN CONCAT(ISNULL(a.OldLevel1,'<NULL>'),' -> ',ISNULL(a.NewLevel1,'<NULL>')) END AS Level1_Change,
    CASE WHEN ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
         THEN CONCAT(ISNULL(a.OldLevel2,'<NULL>'),' -> ',ISNULL(a.NewLevel2,'<NULL>')) END AS Level2_Change,
    CASE WHEN ISNULL(a.OldLevel3,'') <> ISNULL(a.NewLevel3,'')
         THEN CONCAT(ISNULL(a.OldLevel3,'<NULL>'),' -> ',ISNULL(a.NewLevel3,'<NULL>')) END AS Level3_Change,
    CASE WHEN ISNULL(a.OldPosBusinessUnit,'') <> ISNULL(a.NewPosBusinessUnit,'')
         THEN CONCAT(ISNULL(a.OldPosBusinessUnit,'<NULL>'),' -> ',ISNULL(a.NewPosBusinessUnit,'<NULL>')) END AS PosBusinessUnit_Change,
    CASE WHEN ISNULL(a.OldPosBU,'') <> ISNULL(a.NewPosBU,'')
         THEN CONCAT(ISNULL(a.OldPosBU,'<NULL>'),' -> ',ISNULL(a.NewPosBU,'<NULL>')) END AS PosBU_Change,
    CASE WHEN ISNULL(a.OldPosDepartment,'') <> ISNULL(a.NewPosDepartment,'')
         THEN CONCAT(ISNULL(a.OldPosDepartment,'<NULL>'),' -> ',ISNULL(a.NewPosDepartment,'<NULL>')) END AS PosDepartment_Change,
    CASE WHEN ISNULL(a.OldPosDeptId,'') <> ISNULL(a.NewPosDeptId,'')
         THEN CONCAT(ISNULL(a.OldPosDeptId,'<NULL>'),' -> ',ISNULL(a.NewPosDeptId,'<NULL>')) END AS PosDeptId_Change,
    CASE WHEN ISNULL(a.OldTitle,'') <> ISNULL(a.NewTitle,'')
         THEN CONCAT(ISNULL(a.OldTitle,'<NULL>'),' -> ',ISNULL(a.NewTitle,'<NULL>')) END AS Title_Change,
    CASE WHEN ISNULL(a.OldPosRole,'') <> ISNULL(a.NewPosRole,'')
         THEN CONCAT(ISNULL(a.OldPosRole,'<NULL>'),' -> ',ISNULL(a.NewPosRole,'<NULL>')) END AS PosRole_Change,
    CASE WHEN ISNULL(a.OldPosJobCode,'') <> ISNULL(a.NewPosJobCode,'')
         THEN CONCAT(ISNULL(a.OldPosJobCode,'<NULL>'),' -> ',ISNULL(a.NewPosJobCode,'<NULL>')) END AS PosJobCode_Change,
    CASE WHEN ISNULL(a.OldPosClassification,'') <> ISNULL(a.NewPosClassification,'')
         THEN CONCAT(ISNULL(a.OldPosClassification,'<NULL>'),' -> ',ISNULL(a.NewPosClassification,'<NULL>')) END AS PosClassification_Change,
    CASE WHEN ISNULL(a.OldSupervisorPos,'') <> ISNULL(a.NewSupervisorPos,'')
         THEN CONCAT(ISNULL(a.OldSupervisorPos,'<NULL>'),' -> ',ISNULL(a.NewSupervisorPos,'<NULL>')) END AS SupervisorPos_Change,
    CASE WHEN ISNULL(a.OldSupervisorName,'') <> ISNULL(a.NewSupervisorName,'')
         THEN CONCAT(ISNULL(a.OldSupervisorName,'<NULL>'),' -> ',ISNULL(a.NewSupervisorName,'<NULL>')) END AS SupervisorName_Change,
    CASE WHEN ISNULL(a.OldDirect,'') <> ISNULL(a.NewDirect,'')
         THEN CONCAT(ISNULL(a.OldDirect,'<NULL>'),' -> ',ISNULL(a.NewDirect,'<NULL>')) END AS Direct_Change,
    CASE WHEN ISNULL(a.OldIndirect,'') <> ISNULL(a.NewIndirect,'')
         THEN CONCAT(ISNULL(a.OldIndirect,'<NULL>'),' -> ',ISNULL(a.NewIndirect,'<NULL>')) END AS Indirect_Change,
    CASE WHEN ISNULL(a.OldCity,'') <> ISNULL(a.NewCity,'')
         THEN CONCAT(ISNULL(a.OldCity,'<NULL>'),' -> ',ISNULL(a.NewCity,'<NULL>')) END AS City_Change,
    CASE WHEN ISNULL(a.OldStatus,'') <> ISNULL(a.NewStatus,'')
         THEN CONCAT(ISNULL(a.OldStatus,'<NULL>'),' -> ',ISNULL(a.NewStatus,'<NULL>')) END AS Status_Change,
    CASE WHEN ISNULL(a.OldRT,'') <> ISNULL(a.NewRT,'')
         THEN CONCAT(ISNULL(a.OldRT,'<NULL>'),' -> ',ISNULL(a.NewRT,'<NULL>')) END AS RT_Change,
    CASE WHEN ISNULL(a.OldFP,'') <> ISNULL(a.NewFP,'')
         THEN CONCAT(ISNULL(a.OldFP,'<NULL>'),' -> ',ISNULL(a.NewFP,'<NULL>')) END AS FP_Change,
    CASE WHEN ISNULL(a.OldBudgetted,'') <> ISNULL(a.NewBudgetted,'')
         THEN CONCAT(ISNULL(a.OldBudgetted,'<NULL>'),' -> ',ISNULL(a.NewBudgetted,'<NULL>')) END AS Budgetted_Change,
    CASE WHEN ISNULL(a.OldEmpty,'') <> ISNULL(a.NewEmpty,'')
         THEN CONCAT(ISNULL(a.OldEmpty,'<NULL>'),' -> ',ISNULL(a.NewEmpty,'<NULL>')) END AS Empty_Change,
    CASE WHEN ISNULL(a.OldVacant,'') <> ISNULL(a.NewVacant,'')
         THEN CONCAT(ISNULL(a.OldVacant,'<NULL>'),' -> ',ISNULL(a.NewVacant,'<NULL>')) END AS Vacant_Change,
    CASE WHEN ISNULL(a.OldTrueVacancy,'') <> ISNULL(a.NewTrueVacancy,'')
         THEN CONCAT(ISNULL(a.OldTrueVacancy,'<NULL>'),' -> ',ISNULL(a.NewTrueVacancy,'<NULL>')) END AS TrueVacancy_Change,
    CASE WHEN ISNULL(a.OldFuture,'') <> ISNULL(a.NewFuture,'')
         THEN CONCAT(ISNULL(a.OldFuture,'<NULL>'),' -> ',ISNULL(a.NewFuture,'<NULL>')) END AS Future_Change,
    CASE WHEN ISNULL(a.OldLastFilled,'') <> ISNULL(a.NewLastFilled,'')
         THEN CONCAT(ISNULL(a.OldLastFilled,'<NULL>'),' -> ',ISNULL(a.NewLastFilled,'<NULL>')) END AS LastFilled_Change,
    CASE WHEN ISNULL(a.OldLastFilledB,'') <> ISNULL(a.NewLastFilledB,'')
         THEN CONCAT(ISNULL(a.OldLastFilledB,'<NULL>'),' -> ',ISNULL(a.NewLastFilledB,'<NULL>')) END AS LastFilledB_Change,
    CASE WHEN ISNULL(a.OldLastFilledBase,'') <> ISNULL(a.NewLastFilledBase,'')
         THEN CONCAT(ISNULL(a.OldLastFilledBase,'<NULL>'),' -> ',ISNULL(a.NewLastFilledBase,'<NULL>')) END AS LastFilledBase_Change,
    CASE WHEN ISNULL(a.OldEmplBU,'') <> ISNULL(a.NewEmplBU,'')
         THEN CONCAT(ISNULL(a.OldEmplBU,'<NULL>'),' -> ',ISNULL(a.NewEmplBU,'<NULL>')) END AS EmplBU_Change,
    CASE WHEN ISNULL(a.OldEmplDeptId,'') <> ISNULL(a.NewEmplDeptId,'')
         THEN CONCAT(ISNULL(a.OldEmplDeptId,'<NULL>'),' -> ',ISNULL(a.NewEmplDeptId,'<NULL>')) END AS EmplDeptId_Change,
    CASE WHEN ISNULL(a.OldJobRole,'') <> ISNULL(a.NewJobRole,'')
         THEN CONCAT(ISNULL(a.OldJobRole,'<NULL>'),' -> ',ISNULL(a.NewJobRole,'<NULL>')) END AS JobRole_Change,
    CASE WHEN ISNULL(a.OldEmplJobCode,'') <> ISNULL(a.NewEmplJobCode,'')
         THEN CONCAT(ISNULL(a.OldEmplJobCode,'<NULL>'),' -> ',ISNULL(a.NewEmplJobCode,'<NULL>')) END AS EmplJobCode_Change,
    CASE WHEN ISNULL(a.OldEmplClassification,'') <> ISNULL(a.NewEmplClassification,'')
         THEN CONCAT(ISNULL(a.OldEmplClassification,'<NULL>'),' -> ',ISNULL(a.NewEmplClassification,'<NULL>')) END AS EmplClassification_Change,
    CASE WHEN ISNULL(a.OldGrade,'') <> ISNULL(a.NewGrade,'')
         THEN CONCAT(ISNULL(a.OldGrade,'<NULL>'),' -> ',ISNULL(a.NewGrade,'<NULL>')) END AS Grade_Change,
    CASE WHEN ISNULL(a.OldStep,'') <> ISNULL(a.NewStep,'')
         THEN CONCAT(ISNULL(a.OldStep,'<NULL>'),' -> ',ISNULL(a.NewStep,'<NULL>')) END AS Step_Change,
    CASE WHEN ISNULL(a.OldSalaryType,'') <> ISNULL(a.NewSalaryType,'')
         THEN CONCAT(ISNULL(a.OldSalaryType,'<NULL>'),' -> ',ISNULL(a.NewSalaryType,'<NULL>')) END AS SalaryType_Change,
    CASE WHEN ISNULL(a.OldType,'') <> ISNULL(a.NewType,'')
         THEN CONCAT(ISNULL(a.OldType,'<NULL>'),' -> ',ISNULL(a.NewType,'<NULL>')) END AS Type_Change,
    CASE WHEN ISNULL(a.OldStandardHours,'') <> ISNULL(a.NewStandardHours,'')
         THEN CONCAT(ISNULL(a.OldStandardHours,'<NULL>'),' -> ',ISNULL(a.NewStandardHours,'<NULL>')) END AS StandardHours_Change,
    CASE WHEN ISNULL(a.OldBase,'') <> ISNULL(a.NewBase,'')
         THEN CONCAT(ISNULL(a.OldBase,'<NULL>'),' -> ',ISNULL(a.NewBase,'<NULL>')) END AS Base_Change,
    CASE WHEN ISNULL(a.OldName,'') <> ISNULL(a.NewName,'')
         THEN CONCAT(ISNULL(a.OldName,'<NULL>'),' -> ',ISNULL(a.NewName,'<NULL>')) END AS Name_Change,
    CASE WHEN ISNULL(a.OldEmplId,'') <> ISNULL(a.NewEmplId,'')
         THEN CONCAT(ISNULL(a.OldEmplId,'<NULL>'),' -> ',ISNULL(a.NewEmplId,'<NULL>')) END AS EmplIdColumn_Change,
    CASE WHEN ISNULL(a.OldEmplStatus,'') <> ISNULL(a.NewEmplStatus,'')
         THEN CONCAT(ISNULL(a.OldEmplStatus,'<NULL>'),' -> ',ISNULL(a.NewEmplStatus,'<NULL>')) END AS EmplStatus_Change,
    CASE WHEN ISNULL(a.OldAppt,'') <> ISNULL(a.NewAppt,'')
         THEN CONCAT(ISNULL(a.OldAppt,'<NULL>'),' -> ',ISNULL(a.NewAppt,'<NULL>')) END AS Appt_Change,
    CASE WHEN ISNULL(a.OldAge,'') <> ISNULL(a.NewAge,'')
         THEN CONCAT(ISNULL(a.OldAge,'<NULL>'),' -> ',ISNULL(a.NewAge,'<NULL>')) END AS Age_Change,
    CASE WHEN ISNULL(a.OldPosClassMax,'') <> ISNULL(a.NewPosClassMax,'')
         THEN CONCAT(ISNULL(a.OldPosClassMax,'<NULL>'),' -> ',ISNULL(a.NewPosClassMax,'<NULL>')) END AS PosClassMax_Change,
    CASE WHEN ISNULL(a.OldJobClassMax,'') <> ISNULL(a.NewJobClassMax,'')
         THEN CONCAT(ISNULL(a.OldJobClassMax,'<NULL>'),' -> ',ISNULL(a.NewJobClassMax,'<NULL>')) END AS JobClassMax_Change,
    CASE WHEN ISNULL(a.OldAnnual,'') <> ISNULL(a.NewAnnual,'')
         THEN CONCAT(ISNULL(a.OldAnnual,'<NULL>'),' -> ',ISNULL(a.NewAnnual,'<NULL>')) END AS Annual_Change,
    CASE WHEN ISNULL(a.OldAbbr,'') <> ISNULL(a.NewAbbr,'')
         THEN CONCAT(ISNULL(a.OldAbbr,'<NULL>'),' -> ',ISNULL(a.NewAbbr,'<NULL>')) END AS Abbr_Change,
    CASE WHEN ISNULL(a.OldAdminPlan,'') <> ISNULL(a.NewAdminPlan,'')
         THEN CONCAT(ISNULL(a.OldAdminPlan,'<NULL>'),' -> ',ISNULL(a.NewAdminPlan,'<NULL>')) END AS AdminPlan_Change,
    CASE WHEN ISNULL(a.OldAMA,'') <> ISNULL(a.NewAMA,'')
         THEN CONCAT(ISNULL(a.OldAMA,'<NULL>'),' -> ',ISNULL(a.NewAMA,'<NULL>')) END AS AMA_Change,
    CASE WHEN ISNULL(a.OldAMALimit,'') <> ISNULL(a.NewAMALimit,'')
         THEN CONCAT(ISNULL(a.OldAMALimit,'<NULL>'),' -> ',ISNULL(a.NewAMALimit,'<NULL>')) END AS AMALimit_Change,
    CASE WHEN ISNULL(a.OldCAD,'') <> ISNULL(a.NewCAD,'')
         THEN CONCAT(ISNULL(a.OldCAD,'<NULL>'),' -> ',ISNULL(a.NewCAD,'<NULL>')) END AS CAD_Change,
    CASE WHEN ISNULL(a.OldCADLimit,'') <> ISNULL(a.NewCADLimit,'')
         THEN CONCAT(ISNULL(a.OldCADLimit,'<NULL>'),' -> ',ISNULL(a.NewCADLimit,'<NULL>')) END AS CADLimit_Change,
    CASE WHEN ISNULL(a.OldSPP,'') <> ISNULL(a.NewSPP,'')
         THEN CONCAT(ISNULL(a.OldSPP,'<NULL>'),' -> ',ISNULL(a.NewSPP,'<NULL>')) END AS SPP_Change,
    CASE WHEN ISNULL(a.OldSPPLimit,'') <> ISNULL(a.NewSPPLimit,'')
         THEN CONCAT(ISNULL(a.OldSPPLimit,'<NULL>'),' -> ',ISNULL(a.NewSPPLimit,'<NULL>')) END AS SPPLimit_Change,
    CASE WHEN ISNULL(a.OldTAJ,'') <> ISNULL(a.NewTAJ,'')
         THEN CONCAT(ISNULL(a.OldTAJ,'<NULL>'),' -> ',ISNULL(a.NewTAJ,'<NULL>')) END AS TAJ_Change,
    CASE WHEN ISNULL(a.OldTAJLimit,'') <> ISNULL(a.NewTAJLimit,'')
         THEN CONCAT(ISNULL(a.OldTAJLimit,'<NULL>'),' -> ',ISNULL(a.NewTAJLimit,'<NULL>')) END AS TAJLimit_Change,
    CASE WHEN ISNULL(a.OldFutureTermDate,'') <> ISNULL(a.NewFutureTermDate,'')
         THEN CONCAT(ISNULL(a.OldFutureTermDate,'<NULL>'),' -> ',ISNULL(a.NewFutureTermDate,'<NULL>')) END AS FutureTermDate_Change,
    CASE WHEN ISNULL(a.OldFutureTermReason,'') <> ISNULL(a.NewFutureTermReason,'')
         THEN CONCAT(ISNULL(a.OldFutureTermReason,'<NULL>'),' -> ',ISNULL(a.NewFutureTermReason,'<NULL>')) END AS FutureTermReason_Change,
    CASE WHEN ISNULL(a.OldTAStatus,'') <> ISNULL(a.NewTAStatus,'')
         THEN CONCAT(ISNULL(a.OldTAStatus,'<NULL>'),' -> ',ISNULL(a.NewTAStatus,'<NULL>')) END AS TAStatus_Change,
    CASE WHEN ISNULL(a.OldTAStartDate,'') <> ISNULL(a.NewTAStartDate,'')
         THEN CONCAT(ISNULL(a.OldTAStartDate,'<NULL>'),' -> ',ISNULL(a.NewTAStartDate,'<NULL>')) END AS TAStartDate_Change,
    CASE WHEN ISNULL(a.OldTAReturnDate,'') <> ISNULL(a.NewTAReturnDate,'')
         THEN CONCAT(ISNULL(a.OldTAReturnDate,'<NULL>'),' -> ',ISNULL(a.NewTAReturnDate,'<NULL>')) END AS TAReturnDate_Change,
    CASE WHEN ISNULL(a.OldTAReturnTo,'') <> ISNULL(a.NewTAReturnTo,'')
         THEN CONCAT(ISNULL(a.OldTAReturnTo,'<NULL>'),' -> ',ISNULL(a.NewTAReturnTo,'<NULL>')) END AS TAReturnTo_Change,
    CASE WHEN ISNULL(a.OldTAReturnBU,'') <> ISNULL(a.NewTAReturnBU,'')
         THEN CONCAT(ISNULL(a.OldTAReturnBU,'<NULL>'),' -> ',ISNULL(a.NewTAReturnBU,'<NULL>')) END AS TAReturnBU_Change,
    CASE WHEN ISNULL(a.OldTAReturnDeptId,'') <> ISNULL(a.NewTAReturnDeptId,'')
         THEN CONCAT(ISNULL(a.OldTAReturnDeptId,'<NULL>'),' -> ',ISNULL(a.NewTAReturnDeptId,'<NULL>')) END AS TAReturnDeptId_Change,
    CASE WHEN ISNULL(a.OldTAReturnJobCode,'') <> ISNULL(a.NewTAReturnJobCode,'')
         THEN CONCAT(ISNULL(a.OldTAReturnJobCode,'<NULL>'),' -> ',ISNULL(a.NewTAReturnJobCode,'<NULL>')) END AS TAReturnJobCode_Change,
    CASE WHEN ISNULL(a.OldTAReturnGrade,'') <> ISNULL(a.NewTAReturnGrade,'')
         THEN CONCAT(ISNULL(a.OldTAReturnGrade,'<NULL>'),' -> ',ISNULL(a.NewTAReturnGrade,'<NULL>')) END AS TAReturnGrade_Change,
    CASE WHEN ISNULL(a.OldTAReturnPosition,'') <> ISNULL(a.NewTAReturnPosition,'')
         THEN CONCAT(ISNULL(a.OldTAReturnPosition,'<NULL>'),' -> ',ISNULL(a.NewTAReturnPosition,'<NULL>')) END AS TAReturnPosition_Change,
    CASE WHEN ISNULL(a.OldTAReturnSupervisor,'') <> ISNULL(a.NewTAReturnSupervisor,'')
         THEN CONCAT(ISNULL(a.OldTAReturnSupervisor,'<NULL>'),' -> ',ISNULL(a.NewTAReturnSupervisor,'<NULL>')) END AS TAReturnSupervisor_Change,
    CASE WHEN ISNULL(a.OldTAReturnAbbr,'') <> ISNULL(a.NewTAReturnAbbr,'')
         THEN CONCAT(ISNULL(a.OldTAReturnAbbr,'<NULL>'),' -> ',ISNULL(a.NewTAReturnAbbr,'<NULL>')) END AS TAReturnAbbr_Change,
    CASE WHEN ISNULL(a.OldLeaveReason,'') <> ISNULL(a.NewLeaveReason,'')
         THEN CONCAT(ISNULL(a.OldLeaveReason,'<NULL>'),' -> ',ISNULL(a.NewLeaveReason,'<NULL>')) END AS LeaveReason_Change,
    CASE WHEN ISNULL(a.OldLeaveStart,'') <> ISNULL(a.NewLeaveStart,'')
         THEN CONCAT(ISNULL(a.OldLeaveStart,'<NULL>'),' -> ',ISNULL(a.NewLeaveStart,'<NULL>')) END AS LeaveStart_Change,
    CASE WHEN ISNULL(a.OldLeaveReturn,'') <> ISNULL(a.NewLeaveReturn,'')
         THEN CONCAT(ISNULL(a.OldLeaveReturn,'<NULL>'),' -> ',ISNULL(a.NewLeaveReturn,'<NULL>')) END AS LeaveReturn_Change,
    CASE WHEN ISNULL(a.OldQ,'') <> ISNULL(a.NewQ,'')
         THEN CONCAT(ISNULL(a.OldQ,'<NULL>'),' -> ',ISNULL(a.NewQ,'<NULL>')) END AS Q_Change,
    CASE WHEN ISNULL(a.OldMaildropCity,'') <> ISNULL(a.NewMaildropCity,'')
         THEN CONCAT(ISNULL(a.OldMaildropCity,'<NULL>'),' -> ',ISNULL(a.NewMaildropCity,'<NULL>')) END AS MaildropCity_Change

FROM dbo.Peoplesoft_SO001HRORG_Audit a
INNER JOIN latest_run lr
    ON a.RunId = lr.RunId
LEFT JOIN dbo.Peoplesoft_SO001HRORG t
    ON  t.PosPosition = a.PosPosition
    AND t.EmplId      = a.EmplId
WHERE a.ActionType = 'UPDATE'
  -- Uncomment to filter by a specific business key:
  -- AND a.PosPosition = '00000000'
  -- AND a.EmplId      = ''
  -- Uncomment to exclude rows where no projected column actually changed:
  /*
  AND (
       ISNULL(a.OldOrganization,'')       <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldLevel1,'')              <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel2,'')              <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldLevel3,'')              <> ISNULL(a.NewLevel3,'')
    OR ISNULL(a.OldPosBusinessUnit,'')     <> ISNULL(a.NewPosBusinessUnit,'')
    OR ISNULL(a.OldPosBU,'')               <> ISNULL(a.NewPosBU,'')
    OR ISNULL(a.OldPosDepartment,'')       <> ISNULL(a.NewPosDepartment,'')
    OR ISNULL(a.OldPosDeptId,'')           <> ISNULL(a.NewPosDeptId,'')
    OR ISNULL(a.OldTitle,'')               <> ISNULL(a.NewTitle,'')
    OR ISNULL(a.OldPosRole,'')             <> ISNULL(a.NewPosRole,'')
    OR ISNULL(a.OldPosJobCode,'')          <> ISNULL(a.NewPosJobCode,'')
    OR ISNULL(a.OldPosClassification,'')   <> ISNULL(a.NewPosClassification,'')
    OR ISNULL(a.OldSupervisorPos,'')       <> ISNULL(a.NewSupervisorPos,'')
    OR ISNULL(a.OldSupervisorName,'')      <> ISNULL(a.NewSupervisorName,'')
    OR ISNULL(a.OldDirect,'')              <> ISNULL(a.NewDirect,'')
    OR ISNULL(a.OldIndirect,'')            <> ISNULL(a.NewIndirect,'')
    OR ISNULL(a.OldCity,'')                <> ISNULL(a.NewCity,'')
    OR ISNULL(a.OldStatus,'')              <> ISNULL(a.NewStatus,'')
    OR ISNULL(a.OldRT,'')                  <> ISNULL(a.NewRT,'')
    OR ISNULL(a.OldFP,'')                  <> ISNULL(a.NewFP,'')
    OR ISNULL(a.OldBudgetted,'')           <> ISNULL(a.NewBudgetted,'')
    OR ISNULL(a.OldEmpty,'')               <> ISNULL(a.NewEmpty,'')
    OR ISNULL(a.OldVacant,'')              <> ISNULL(a.NewVacant,'')
    OR ISNULL(a.OldTrueVacancy,'')         <> ISNULL(a.NewTrueVacancy,'')
    OR ISNULL(a.OldFuture,'')              <> ISNULL(a.NewFuture,'')
    OR ISNULL(a.OldLastFilled,'')          <> ISNULL(a.NewLastFilled,'')
    OR ISNULL(a.OldLastFilledB,'')         <> ISNULL(a.NewLastFilledB,'')
    OR ISNULL(a.OldLastFilledBase,'')      <> ISNULL(a.NewLastFilledBase,'')
    OR ISNULL(a.OldEmplBU,'')              <> ISNULL(a.NewEmplBU,'')
    OR ISNULL(a.OldEmplDeptId,'')          <> ISNULL(a.NewEmplDeptId,'')
    OR ISNULL(a.OldJobRole,'')             <> ISNULL(a.NewJobRole,'')
    OR ISNULL(a.OldEmplJobCode,'')         <> ISNULL(a.NewEmplJobCode,'')
    OR ISNULL(a.OldEmplClassification,'')  <> ISNULL(a.NewEmplClassification,'')
    OR ISNULL(a.OldGrade,'')               <> ISNULL(a.NewGrade,'')
    OR ISNULL(a.OldStep,'')                <> ISNULL(a.NewStep,'')
    OR ISNULL(a.OldSalaryType,'')          <> ISNULL(a.NewSalaryType,'')
    OR ISNULL(a.OldType,'')                <> ISNULL(a.NewType,'')
    OR ISNULL(a.OldStandardHours,'')       <> ISNULL(a.NewStandardHours,'')
    OR ISNULL(a.OldBase,'')                <> ISNULL(a.NewBase,'')
    OR ISNULL(a.OldName,'')                <> ISNULL(a.NewName,'')
    OR ISNULL(a.OldEmplId,'')              <> ISNULL(a.NewEmplId,'')
    OR ISNULL(a.OldEmplStatus,'')          <> ISNULL(a.NewEmplStatus,'')
    OR ISNULL(a.OldAppt,'')                <> ISNULL(a.NewAppt,'')
    OR ISNULL(a.OldAge,'')                 <> ISNULL(a.NewAge,'')
    OR ISNULL(a.OldPosClassMax,'')         <> ISNULL(a.NewPosClassMax,'')
    OR ISNULL(a.OldJobClassMax,'')         <> ISNULL(a.NewJobClassMax,'')
    OR ISNULL(a.OldAnnual,'')              <> ISNULL(a.NewAnnual,'')
    OR ISNULL(a.OldAbbr,'')                <> ISNULL(a.NewAbbr,'')
    OR ISNULL(a.OldAdminPlan,'')           <> ISNULL(a.NewAdminPlan,'')
    OR ISNULL(a.OldAMA,'')                 <> ISNULL(a.NewAMA,'')
    OR ISNULL(a.OldAMALimit,'')            <> ISNULL(a.NewAMALimit,'')
    OR ISNULL(a.OldCAD,'')                 <> ISNULL(a.NewCAD,'')
    OR ISNULL(a.OldCADLimit,'')            <> ISNULL(a.NewCADLimit,'')
    OR ISNULL(a.OldSPP,'')                 <> ISNULL(a.NewSPP,'')
    OR ISNULL(a.OldSPPLimit,'')            <> ISNULL(a.NewSPPLimit,'')
    OR ISNULL(a.OldTAJ,'')                 <> ISNULL(a.NewTAJ,'')
    OR ISNULL(a.OldTAJLimit,'')            <> ISNULL(a.NewTAJLimit,'')
    OR ISNULL(a.OldFutureTermDate,'')      <> ISNULL(a.NewFutureTermDate,'')
    OR ISNULL(a.OldFutureTermReason,'')    <> ISNULL(a.NewFutureTermReason,'')
    OR ISNULL(a.OldTAStatus,'')            <> ISNULL(a.NewTAStatus,'')
    OR ISNULL(a.OldTAStartDate,'')         <> ISNULL(a.NewTAStartDate,'')
    OR ISNULL(a.OldTAReturnDate,'')        <> ISNULL(a.NewTAReturnDate,'')
    OR ISNULL(a.OldTAReturnTo,'')          <> ISNULL(a.NewTAReturnTo,'')
    OR ISNULL(a.OldTAReturnBU,'')          <> ISNULL(a.NewTAReturnBU,'')
    OR ISNULL(a.OldTAReturnDeptId,'')      <> ISNULL(a.NewTAReturnDeptId,'')
    OR ISNULL(a.OldTAReturnJobCode,'')     <> ISNULL(a.NewTAReturnJobCode,'')
    OR ISNULL(a.OldTAReturnGrade,'')       <> ISNULL(a.NewTAReturnGrade,'')
    OR ISNULL(a.OldTAReturnPosition,'')    <> ISNULL(a.NewTAReturnPosition,'')
    OR ISNULL(a.OldTAReturnSupervisor,'')  <> ISNULL(a.NewTAReturnSupervisor,'')
    OR ISNULL(a.OldTAReturnAbbr,'')        <> ISNULL(a.NewTAReturnAbbr,'')
    OR ISNULL(a.OldLeaveReason,'')         <> ISNULL(a.NewLeaveReason,'')
    OR ISNULL(a.OldLeaveStart,'')          <> ISNULL(a.NewLeaveStart,'')
    OR ISNULL(a.OldLeaveReturn,'')         <> ISNULL(a.NewLeaveReturn,'')
    OR ISNULL(a.OldQ,'')                   <> ISNULL(a.NewQ,'')
    OR ISNULL(a.OldMaildropCity,'')        <> ISNULL(a.NewMaildropCity,'')
  )
  */
ORDER BY a.PosPosition, a.EmplId, a.AuditDtmUtc DESC;
