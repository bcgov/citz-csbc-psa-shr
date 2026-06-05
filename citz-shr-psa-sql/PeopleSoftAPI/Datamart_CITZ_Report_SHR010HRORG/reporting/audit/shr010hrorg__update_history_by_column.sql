/*=============================================================================
File: shr010hrorg__update_history_by_column.sql
Purpose:
  Column-level change diagnostic for UPDATE actions in the SHR010HRORG audit table.
  Shows exactly which columns changed per row. Use to identify
  continuously-computed columns causing false updates.
Audit table : dbo.Peoplesoft_SHR010HRORG_Audit
Target table: dbo.Peoplesoft_SHR010HRORG
Business key: EmplId
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId FROM dbo.Peoplesoft_SHR010HRORG_Audit
)
SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.EmplId,
    t.Name AS CurrentName,
    t.Organization AS CurrentOrganization,
    a.OldRowHash,
    a.NewRowHash,

    CASE WHEN ISNULL(a.OldName,'') <> ISNULL(a.NewName,'')
         THEN CONCAT(ISNULL(a.OldName,'<NULL>'),' -> ',ISNULL(a.NewName,'<NULL>')) END AS Name_Change,
    CASE WHEN ISNULL(a.OldIdir,'') <> ISNULL(a.NewIdir,'')
         THEN CONCAT(ISNULL(a.OldIdir,'<NULL>'),' -> ',ISNULL(a.NewIdir,'<NULL>')) END AS Idir_Change,
    CASE WHEN ISNULL(a.OldEmailId,'') <> ISNULL(a.NewEmailId,'')
         THEN CONCAT(ISNULL(a.OldEmailId,'<NULL>'),' -> ',ISNULL(a.NewEmailId,'<NULL>')) END AS EmailId_Change,
    CASE WHEN ISNULL(a.OldEmplStatus,'') <> ISNULL(a.NewEmplStatus,'')
         THEN CONCAT(ISNULL(a.OldEmplStatus,'<NULL>'),' -> ',ISNULL(a.NewEmplStatus,'<NULL>')) END AS EmplStatus_Change,
    CASE WHEN ISNULL(a.OldEmplType,'') <> ISNULL(a.NewEmplType,'')
         THEN CONCAT(ISNULL(a.OldEmplType,'<NULL>'),' -> ',ISNULL(a.NewEmplType,'<NULL>')) END AS EmplType_Change,
    CASE WHEN ISNULL(a.OldEmplCtg,'') <> ISNULL(a.NewEmplCtg,'')
         THEN CONCAT(ISNULL(a.OldEmplCtg,'<NULL>'),' -> ',ISNULL(a.NewEmplCtg,'<NULL>')) END AS EmplCtg_Change,
    CASE WHEN ISNULL(a.OldEmplCtgL1,'') <> ISNULL(a.NewEmplCtgL1,'')
         THEN CONCAT(ISNULL(a.OldEmplCtgL1,'<NULL>'),' -> ',ISNULL(a.NewEmplCtgL1,'<NULL>')) END AS EmplCtgL1_Change,
    CASE WHEN ISNULL(a.OldEmplRcd,'') <> ISNULL(a.NewEmplRcd,'')
         THEN CONCAT(ISNULL(a.OldEmplRcd,'<NULL>'),' -> ',ISNULL(a.NewEmplRcd,'<NULL>')) END AS EmplRcd_Change,
    CASE WHEN ISNULL(a.OldApptStatus,'') <> ISNULL(a.NewApptStatus,'')
         THEN CONCAT(ISNULL(a.OldApptStatus,'<NULL>'),' -> ',ISNULL(a.NewApptStatus,'<NULL>')) END AS ApptStatus_Change,
    CASE WHEN ISNULL(a.OldApptStatusCode,'') <> ISNULL(a.NewApptStatusCode,'')
         THEN CONCAT(ISNULL(a.OldApptStatusCode,'<NULL>'),' -> ',ISNULL(a.NewApptStatusCode,'<NULL>')) END AS ApptStatusCode_Change,
    CASE WHEN ISNULL(a.OldBirthdate,'') <> ISNULL(a.NewBirthdate,'')
         THEN CONCAT(ISNULL(a.OldBirthdate,'<NULL>'),' -> ',ISNULL(a.NewBirthdate,'<NULL>')) END AS Birthdate_Change,
    CASE WHEN ISNULL(a.OldHireDt,'') <> ISNULL(a.NewHireDt,'')
         THEN CONCAT(ISNULL(a.OldHireDt,'<NULL>'),' -> ',ISNULL(a.NewHireDt,'<NULL>')) END AS HireDt_Change,
    CASE WHEN ISNULL(a.OldLastHireDt,'') <> ISNULL(a.NewLastHireDt,'')
         THEN CONCAT(ISNULL(a.OldLastHireDt,'<NULL>'),' -> ',ISNULL(a.NewLastHireDt,'<NULL>')) END AS LastHireDt_Change,
    CASE WHEN ISNULL(a.OldMostHistoricDate,'') <> ISNULL(a.NewMostHistoricDate,'')
         THEN CONCAT(ISNULL(a.OldMostHistoricDate,'<NULL>'),' -> ',ISNULL(a.NewMostHistoricDate,'<NULL>')) END AS MostHistoricDate_Change,
    CASE WHEN ISNULL(a.OldFirstDateInOrganization,'') <> ISNULL(a.NewFirstDateInOrganization,'')
         THEN CONCAT(ISNULL(a.OldFirstDateInOrganization,'<NULL>'),' -> ',ISNULL(a.NewFirstDateInOrganization,'<NULL>')) END AS FirstDateInOrganization_Change,
    CASE WHEN ISNULL(a.OldFirstDateInPosition,'') <> ISNULL(a.NewFirstDateInPosition,'')
         THEN CONCAT(ISNULL(a.OldFirstDateInPosition,'<NULL>'),' -> ',ISNULL(a.NewFirstDateInPosition,'<NULL>')) END AS FirstDateInPosition_Change,
    CASE WHEN ISNULL(a.OldFutureReturnDate,'') <> ISNULL(a.NewFutureReturnDate,'')
         THEN CONCAT(ISNULL(a.OldFutureReturnDate,'<NULL>'),' -> ',ISNULL(a.NewFutureReturnDate,'<NULL>')) END AS FutureReturnDate_Change,
    CASE WHEN ISNULL(a.OldPositionNbr,'') <> ISNULL(a.NewPositionNbr,'')
         THEN CONCAT(ISNULL(a.OldPositionNbr,'<NULL>'),' -> ',ISNULL(a.NewPositionNbr,'<NULL>')) END AS PositionNbr_Change,
    CASE WHEN ISNULL(a.OldTgbBasePosition,'') <> ISNULL(a.NewTgbBasePosition,'')
         THEN CONCAT(ISNULL(a.OldTgbBasePosition,'<NULL>'),' -> ',ISNULL(a.NewTgbBasePosition,'<NULL>')) END AS TgbBasePosition_Change,
    CASE WHEN ISNULL(a.OldPositionDataDescr,'') <> ISNULL(a.NewPositionDataDescr,'')
         THEN CONCAT(ISNULL(a.OldPositionDataDescr,'<NULL>'),' -> ',ISNULL(a.NewPositionDataDescr,'<NULL>')) END AS PositionDataDescr_Change,
    CASE WHEN ISNULL(a.OldJobCode,'') <> ISNULL(a.NewJobCode,'')
         THEN CONCAT(ISNULL(a.OldJobCode,'<NULL>'),' -> ',ISNULL(a.NewJobCode,'<NULL>')) END AS JobCode_Change,
    CASE WHEN ISNULL(a.OldJobCodeDescr,'') <> ISNULL(a.NewJobCodeDescr,'')
         THEN CONCAT(ISNULL(a.OldJobCodeDescr,'<NULL>'),' -> ',ISNULL(a.NewJobCodeDescr,'<NULL>')) END AS JobCodeDescr_Change,
    CASE WHEN ISNULL(a.OldJobFunction,'') <> ISNULL(a.NewJobFunction,'')
         THEN CONCAT(ISNULL(a.OldJobFunction,'<NULL>'),' -> ',ISNULL(a.NewJobFunction,'<NULL>')) END AS JobFunction_Change,
    CASE WHEN ISNULL(a.OldSalAdminPlan,'') <> ISNULL(a.NewSalAdminPlan,'')
         THEN CONCAT(ISNULL(a.OldSalAdminPlan,'<NULL>'),' -> ',ISNULL(a.NewSalAdminPlan,'<NULL>')) END AS SalAdminPlan_Change,
    CASE WHEN ISNULL(a.OldGrade,'') <> ISNULL(a.NewGrade,'')
         THEN CONCAT(ISNULL(a.OldGrade,'<NULL>'),' -> ',ISNULL(a.NewGrade,'<NULL>')) END AS Grade_Change,
    CASE WHEN ISNULL(a.OldStep,'') <> ISNULL(a.NewStep,'')
         THEN CONCAT(ISNULL(a.OldStep,'<NULL>'),' -> ',ISNULL(a.NewStep,'<NULL>')) END AS Step_Change,
    CASE WHEN ISNULL(a.OldStdHours,'') <> ISNULL(a.NewStdHours,'')
         THEN CONCAT(ISNULL(a.OldStdHours,'<NULL>'),' -> ',ISNULL(a.NewStdHours,'<NULL>')) END AS StdHours_Change,
    CASE WHEN ISNULL(a.OldAnnualRt,'') <> ISNULL(a.NewAnnualRt,'')
         THEN CONCAT(ISNULL(a.OldAnnualRt,'<NULL>'),' -> ',ISNULL(a.NewAnnualRt,'<NULL>')) END AS AnnualRt_Change,
    CASE WHEN ISNULL(a.OldCompRate,'') <> ISNULL(a.NewCompRate,'')
         THEN CONCAT(ISNULL(a.OldCompRate,'<NULL>'),' -> ',ISNULL(a.NewCompRate,'<NULL>')) END AS CompRate_Change,
    CASE WHEN ISNULL(a.OldHourlyRt,'') <> ISNULL(a.NewHourlyRt,'')
         THEN CONCAT(ISNULL(a.OldHourlyRt,'<NULL>'),' -> ',ISNULL(a.NewHourlyRt,'<NULL>')) END AS HourlyRt_Change,
    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'),' -> ',ISNULL(a.NewOrganization,'<NULL>')) END AS Organization_Change,
    CASE WHEN ISNULL(a.OldBusinessUnit,'') <> ISNULL(a.NewBusinessUnit,'')
         THEN CONCAT(ISNULL(a.OldBusinessUnit,'<NULL>'),' -> ',ISNULL(a.NewBusinessUnit,'<NULL>')) END AS BusinessUnit_Change,
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN CONCAT(ISNULL(a.OldDeptId,'<NULL>'),' -> ',ISNULL(a.NewDeptId,'<NULL>')) END AS DeptId_Change,
    CASE WHEN ISNULL(a.OldDeptDescr,'') <> ISNULL(a.NewDeptDescr,'')
         THEN CONCAT(ISNULL(a.OldDeptDescr,'<NULL>'),' -> ',ISNULL(a.NewDeptDescr,'<NULL>')) END AS DeptDescr_Change,
    CASE WHEN ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
         THEN CONCAT(ISNULL(a.OldLevel1,'<NULL>'),' -> ',ISNULL(a.NewLevel1,'<NULL>')) END AS Level1_Change,
    CASE WHEN ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
         THEN CONCAT(ISNULL(a.OldLevel2,'<NULL>'),' -> ',ISNULL(a.NewLevel2,'<NULL>')) END AS Level2_Change,
    CASE WHEN ISNULL(a.OldLevel3,'') <> ISNULL(a.NewLevel3,'')
         THEN CONCAT(ISNULL(a.OldLevel3,'<NULL>'),' -> ',ISNULL(a.NewLevel3,'<NULL>')) END AS Level3_Change,
    CASE WHEN ISNULL(a.OldDescr,'') <> ISNULL(a.NewDescr,'')
         THEN CONCAT(ISNULL(a.OldDescr,'<NULL>'),' -> ',ISNULL(a.NewDescr,'<NULL>')) END AS Descr_Change,
    CASE WHEN ISNULL(a.OldCore,'') <> ISNULL(a.NewCore,'')
         THEN CONCAT(ISNULL(a.OldCore,'<NULL>'),' -> ',ISNULL(a.NewCore,'<NULL>')) END AS Core_Change,
    CASE WHEN ISNULL(a.OldCoreGovernment,'') <> ISNULL(a.NewCoreGovernment,'')
         THEN CONCAT(ISNULL(a.OldCoreGovernment,'<NULL>'),' -> ',ISNULL(a.NewCoreGovernment,'<NULL>')) END AS CoreGovernment_Change,
    CASE WHEN ISNULL(a.OldSector,'') <> ISNULL(a.NewSector,'')
         THEN CONCAT(ISNULL(a.OldSector,'<NULL>'),' -> ',ISNULL(a.NewSector,'<NULL>')) END AS Sector_Change,
    CASE WHEN ISNULL(a.OldPublicService,'') <> ISNULL(a.NewPublicService,'')
         THEN CONCAT(ISNULL(a.OldPublicService,'<NULL>'),' -> ',ISNULL(a.NewPublicService,'<NULL>')) END AS PublicService_Change,
    CASE WHEN ISNULL(a.OldPublicServiceAct,'') <> ISNULL(a.NewPublicServiceAct,'')
         THEN CONCAT(ISNULL(a.OldPublicServiceAct,'<NULL>'),' -> ',ISNULL(a.NewPublicServiceAct,'<NULL>')) END AS PublicServiceAct_Change,
    CASE WHEN ISNULL(a.OldTreasuryBoard,'') <> ISNULL(a.NewTreasuryBoard,'')
         THEN CONCAT(ISNULL(a.OldTreasuryBoard,'<NULL>'),' -> ',ISNULL(a.NewTreasuryBoard,'<NULL>')) END AS TreasuryBoard_Change,
    CASE WHEN ISNULL(a.OldOfficerCode,'') <> ISNULL(a.NewOfficerCode,'')
         THEN CONCAT(ISNULL(a.OldOfficerCode,'<NULL>'),' -> ',ISNULL(a.NewOfficerCode,'<NULL>')) END AS OfficerCode_Change,
    CASE WHEN ISNULL(a.OldNocCode,'') <> ISNULL(a.NewNocCode,'')
         THEN CONCAT(ISNULL(a.OldNocCode,'<NULL>'),' -> ',ISNULL(a.NewNocCode,'<NULL>')) END AS NocCode_Change,
    CASE WHEN ISNULL(a.OldNocCodeDescr,'') <> ISNULL(a.NewNocCodeDescr,'')
         THEN CONCAT(ISNULL(a.OldNocCodeDescr,'<NULL>'),' -> ',ISNULL(a.NewNocCodeDescr,'<NULL>')) END AS NocCodeDescr_Change,
    CASE WHEN ISNULL(a.OldReportsTo,'') <> ISNULL(a.NewReportsTo,'')
         THEN CONCAT(ISNULL(a.OldReportsTo,'<NULL>'),' -> ',ISNULL(a.NewReportsTo,'<NULL>')) END AS ReportsTo_Change,
    CASE WHEN ISNULL(a.OldLocation,'') <> ISNULL(a.NewLocation,'')
         THEN CONCAT(ISNULL(a.OldLocation,'<NULL>'),' -> ',ISNULL(a.NewLocation,'<NULL>')) END AS Location_Change,
    CASE WHEN ISNULL(a.OldLocationCity,'') <> ISNULL(a.NewLocationCity,'')
         THEN CONCAT(ISNULL(a.OldLocationCity,'<NULL>'),' -> ',ISNULL(a.NewLocationCity,'<NULL>')) END AS LocationCity_Change,
    CASE WHEN ISNULL(a.OldAgeGroup1,'') <> ISNULL(a.NewAgeGroup1,'')
         THEN CONCAT(ISNULL(a.OldAgeGroup1,'<NULL>'),' -> ',ISNULL(a.NewAgeGroup1,'<NULL>')) END AS AgeGroup1_Change,
    CASE WHEN ISNULL(a.OldAgeGroup2,'') <> ISNULL(a.NewAgeGroup2,'')
         THEN CONCAT(ISNULL(a.OldAgeGroup2,'<NULL>'),' -> ',ISNULL(a.NewAgeGroup2,'<NULL>')) END AS AgeGroup2_Change,
    CASE WHEN ISNULL(a.OldAge,'') <> ISNULL(a.NewAge,'')
         THEN CONCAT(ISNULL(a.OldAge,'<NULL>'),' -> ',ISNULL(a.NewAge,'<NULL>')) END AS Age_Change,
    CASE WHEN ISNULL(a.OldGeneration,'') <> ISNULL(a.NewGeneration,'')
         THEN CONCAT(ISNULL(a.OldGeneration,'<NULL>'),' -> ',ISNULL(a.NewGeneration,'<NULL>')) END AS Generation_Change,
    CASE WHEN ISNULL(a.OldEligibleForPension,'') <> ISNULL(a.NewEligibleForPension,'')
         THEN CONCAT(ISNULL(a.OldEligibleForPension,'<NULL>'),' -> ',ISNULL(a.NewEligibleForPension,'<NULL>')) END AS EligibleForPension_Change,
    CASE WHEN ISNULL(a.OldEligibleForUnreducedPension,'') <> ISNULL(a.NewEligibleForUnreducedPension,'')
         THEN CONCAT(ISNULL(a.OldEligibleForUnreducedPension,'<NULL>'),' -> ',ISNULL(a.NewEligibleForUnreducedPension,'<NULL>')) END AS EligibleForUnreducedPension_Change,
    CASE WHEN ISNULL(a.OldSupervisor,'') <> ISNULL(a.NewSupervisor,'')
         THEN CONCAT(ISNULL(a.OldSupervisor,'<NULL>'),' -> ',ISNULL(a.NewSupervisor,'<NULL>')) END AS Supervisor_Change,
    CASE WHEN ISNULL(a.OldSupervEmail,'') <> ISNULL(a.NewSupervEmail,'')
         THEN CONCAT(ISNULL(a.OldSupervEmail,'<NULL>'),' -> ',ISNULL(a.NewSupervEmail,'<NULL>')) END AS SupervEmail_Change,
    CASE WHEN ISNULL(a.OldSupervSalPlan,'') <> ISNULL(a.NewSupervSalPlan,'')
         THEN CONCAT(ISNULL(a.OldSupervSalPlan,'<NULL>'),' -> ',ISNULL(a.NewSupervSalPlan,'<NULL>')) END AS SupervSalPlan_Change,
    CASE WHEN ISNULL(a.OldSupervisorStatus,'') <> ISNULL(a.NewSupervisorStatus,'')
         THEN CONCAT(ISNULL(a.OldSupervisorStatus,'<NULL>'),' -> ',ISNULL(a.NewSupervisorStatus,'<NULL>')) END AS SupervisorStatus_Change,
    CASE WHEN ISNULL(a.OldLayoffLeaveStopPayReason,'') <> ISNULL(a.NewLayoffLeaveStopPayReason,'')
         THEN CONCAT(ISNULL(a.OldLayoffLeaveStopPayReason,'<NULL>'),' -> ',ISNULL(a.NewLayoffLeaveStopPayReason,'<NULL>')) END AS LayoffLeaveStopPayReason_Change,
    CASE WHEN ISNULL(a.OldLayoffLeaveStopPayStartDate,'') <> ISNULL(a.NewLayoffLeaveStopPayStartDate,'')
         THEN CONCAT(ISNULL(a.OldLayoffLeaveStopPayStartDate,'<NULL>'),' -> ',ISNULL(a.NewLayoffLeaveStopPayStartDate,'<NULL>')) END AS LayoffLeaveStopPayStartDate_Change

FROM dbo.Peoplesoft_SHR010HRORG_Audit a
INNER JOIN latest_run lr
    ON a.RunId = lr.RunId
LEFT JOIN dbo.Peoplesoft_SHR010HRORG t
    ON t.EmplId = a.EmplId
WHERE a.ActionType = 'UPDATE'
  -- Uncomment to filter by a specific business key:
  -- AND a.EmplId = '000000'
  -- Uncomment to exclude rows where no projected column actually changed:
  /*
  AND (
       ISNULL(a.OldName,'')                          <> ISNULL(a.NewName,'')
    OR ISNULL(a.OldIdir,'')                          <> ISNULL(a.NewIdir,'')
    OR ISNULL(a.OldEmailId,'')                       <> ISNULL(a.NewEmailId,'')
    OR ISNULL(a.OldEmplStatus,'')                    <> ISNULL(a.NewEmplStatus,'')
    OR ISNULL(a.OldEmplType,'')                      <> ISNULL(a.NewEmplType,'')
    OR ISNULL(a.OldEmplCtg,'')                       <> ISNULL(a.NewEmplCtg,'')
    OR ISNULL(a.OldEmplCtgL1,'')                     <> ISNULL(a.NewEmplCtgL1,'')
    OR ISNULL(a.OldEmplRcd,'')                       <> ISNULL(a.NewEmplRcd,'')
    OR ISNULL(a.OldApptStatus,'')                    <> ISNULL(a.NewApptStatus,'')
    OR ISNULL(a.OldApptStatusCode,'')                <> ISNULL(a.NewApptStatusCode,'')
    OR ISNULL(a.OldBirthdate,'')                     <> ISNULL(a.NewBirthdate,'')
    OR ISNULL(a.OldHireDt,'')                        <> ISNULL(a.NewHireDt,'')
    OR ISNULL(a.OldLastHireDt,'')                    <> ISNULL(a.NewLastHireDt,'')
    OR ISNULL(a.OldMostHistoricDate,'')              <> ISNULL(a.NewMostHistoricDate,'')
    OR ISNULL(a.OldFirstDateInOrganization,'')       <> ISNULL(a.NewFirstDateInOrganization,'')
    OR ISNULL(a.OldFirstDateInPosition,'')           <> ISNULL(a.NewFirstDateInPosition,'')
    OR ISNULL(a.OldFutureReturnDate,'')              <> ISNULL(a.NewFutureReturnDate,'')
    OR ISNULL(a.OldPositionNbr,'')                   <> ISNULL(a.NewPositionNbr,'')
    OR ISNULL(a.OldTgbBasePosition,'')               <> ISNULL(a.NewTgbBasePosition,'')
    OR ISNULL(a.OldPositionDataDescr,'')             <> ISNULL(a.NewPositionDataDescr,'')
    OR ISNULL(a.OldJobCode,'')                       <> ISNULL(a.NewJobCode,'')
    OR ISNULL(a.OldJobCodeDescr,'')                  <> ISNULL(a.NewJobCodeDescr,'')
    OR ISNULL(a.OldJobFunction,'')                   <> ISNULL(a.NewJobFunction,'')
    OR ISNULL(a.OldSalAdminPlan,'')                  <> ISNULL(a.NewSalAdminPlan,'')
    OR ISNULL(a.OldGrade,'')                         <> ISNULL(a.NewGrade,'')
    OR ISNULL(a.OldStep,'')                          <> ISNULL(a.NewStep,'')
    OR ISNULL(a.OldStdHours,'')                      <> ISNULL(a.NewStdHours,'')
    OR ISNULL(a.OldAnnualRt,'')                      <> ISNULL(a.NewAnnualRt,'')
    OR ISNULL(a.OldCompRate,'')                      <> ISNULL(a.NewCompRate,'')
    OR ISNULL(a.OldHourlyRt,'')                      <> ISNULL(a.NewHourlyRt,'')
    OR ISNULL(a.OldOrganization,'')                  <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldBusinessUnit,'')                  <> ISNULL(a.NewBusinessUnit,'')
    OR ISNULL(a.OldDeptId,'')                        <> ISNULL(a.NewDeptId,'')
    OR ISNULL(a.OldDeptDescr,'')                     <> ISNULL(a.NewDeptDescr,'')
    OR ISNULL(a.OldLevel1,'')                        <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel2,'')                        <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldLevel3,'')                        <> ISNULL(a.NewLevel3,'')
    OR ISNULL(a.OldDescr,'')                         <> ISNULL(a.NewDescr,'')
    OR ISNULL(a.OldCore,'')                          <> ISNULL(a.NewCore,'')
    OR ISNULL(a.OldCoreGovernment,'')                <> ISNULL(a.NewCoreGovernment,'')
    OR ISNULL(a.OldSector,'')                        <> ISNULL(a.NewSector,'')
    OR ISNULL(a.OldPublicService,'')                 <> ISNULL(a.NewPublicService,'')
    OR ISNULL(a.OldPublicServiceAct,'')              <> ISNULL(a.NewPublicServiceAct,'')
    OR ISNULL(a.OldTreasuryBoard,'')                 <> ISNULL(a.NewTreasuryBoard,'')
    OR ISNULL(a.OldOfficerCode,'')                   <> ISNULL(a.NewOfficerCode,'')
    OR ISNULL(a.OldNocCode,'')                       <> ISNULL(a.NewNocCode,'')
    OR ISNULL(a.OldNocCodeDescr,'')                  <> ISNULL(a.NewNocCodeDescr,'')
    OR ISNULL(a.OldReportsTo,'')                     <> ISNULL(a.NewReportsTo,'')
    OR ISNULL(a.OldLocation,'')                      <> ISNULL(a.NewLocation,'')
    OR ISNULL(a.OldLocationCity,'')                  <> ISNULL(a.NewLocationCity,'')
    OR ISNULL(a.OldAgeGroup1,'')                     <> ISNULL(a.NewAgeGroup1,'')
    OR ISNULL(a.OldAgeGroup2,'')                     <> ISNULL(a.NewAgeGroup2,'')
    OR ISNULL(a.OldAge,'')                           <> ISNULL(a.NewAge,'')
    OR ISNULL(a.OldGeneration,'')                    <> ISNULL(a.NewGeneration,'')
    OR ISNULL(a.OldEligibleForPension,'')            <> ISNULL(a.NewEligibleForPension,'')
    OR ISNULL(a.OldEligibleForUnreducedPension,'')   <> ISNULL(a.NewEligibleForUnreducedPension,'')
    OR ISNULL(a.OldSupervisor,'')                    <> ISNULL(a.NewSupervisor,'')
    OR ISNULL(a.OldSupervEmail,'')                   <> ISNULL(a.NewSupervEmail,'')
    OR ISNULL(a.OldSupervSalPlan,'')                 <> ISNULL(a.NewSupervSalPlan,'')
    OR ISNULL(a.OldSupervisorStatus,'')              <> ISNULL(a.NewSupervisorStatus,'')
    OR ISNULL(a.OldLayoffLeaveStopPayReason,'')      <> ISNULL(a.NewLayoffLeaveStopPayReason,'')
    OR ISNULL(a.OldLayoffLeaveStopPayStartDate,'')   <> ISNULL(a.NewLayoffLeaveStopPayStartDate,'')
  )
  */
ORDER BY a.EmplId, a.AuditDtmUtc DESC;
