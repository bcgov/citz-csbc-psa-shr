/*=============================================================================
File: epc__update_history_by_column.sql
Purpose:
  Column-level change diagnostic for UPDATE actions in the EPC audit table.
  Shows exactly which columns changed per row. Use to identify
  continuously-computed columns causing false updates.
Audit table : dbo.Peoplesoft_EPC_Audit
Target table: dbo.Peoplesoft_EPC
Business key: Position
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId FROM dbo.Peoplesoft_EPC_Audit
)
SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.Position,
    t.PositionTitle AS CurrentPositionTitle,
    t.Organization  AS CurrentOrganization,
    a.OldRowHash,
    a.NewRowHash,

    CASE WHEN ISNULL(a.OldBaseIncumbents,'') <> ISNULL(a.NewBaseIncumbents,'')
         THEN CONCAT(ISNULL(a.OldBaseIncumbents,'<NULL>'),' -> ',ISNULL(a.NewBaseIncumbents,'<NULL>')) END AS BaseIncumbents_Change,
    CASE WHEN ISNULL(a.OldBusinessUnitDescr,'') <> ISNULL(a.NewBusinessUnitDescr,'')
         THEN CONCAT(ISNULL(a.OldBusinessUnitDescr,'<NULL>'),' -> ',ISNULL(a.NewBusinessUnitDescr,'<NULL>')) END AS BusinessUnitDescr_Change,
    CASE WHEN ISNULL(a.OldCity,'') <> ISNULL(a.NewCity,'')
         THEN CONCAT(ISNULL(a.OldCity,'<NULL>'),' -> ',ISNULL(a.NewCity,'<NULL>')) END AS City_Change,
    CASE WHEN ISNULL(a.OldClassificationGroup,'') <> ISNULL(a.NewClassificationGroup,'')
         THEN CONCAT(ISNULL(a.OldClassificationGroup,'<NULL>'),' -> ',ISNULL(a.NewClassificationGroup,'<NULL>')) END AS ClassificationGroup_Change,
    CASE WHEN ISNULL(a.OldCore,'') <> ISNULL(a.NewCore,'')
         THEN CONCAT(ISNULL(a.OldCore,'<NULL>'),' -> ',ISNULL(a.NewCore,'<NULL>')) END AS Core_Change,
    CASE WHEN ISNULL(a.OldCreateEffDt,'') <> ISNULL(a.NewCreateEffDt,'')
         THEN CONCAT(ISNULL(a.OldCreateEffDt,'<NULL>'),' -> ',ISNULL(a.NewCreateEffDt,'<NULL>')) END AS CreateEffDt_Change,
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN CONCAT(ISNULL(a.OldDeptId,'<NULL>'),' -> ',ISNULL(a.NewDeptId,'<NULL>')) END AS DeptId_Change,
    CASE WHEN ISNULL(a.OldDeptIdDesc,'') <> ISNULL(a.NewDeptIdDesc,'')
         THEN CONCAT(ISNULL(a.OldDeptIdDesc,'<NULL>'),' -> ',ISNULL(a.NewDeptIdDesc,'<NULL>')) END AS DeptIdDesc_Change,
    CASE WHEN ISNULL(a.OldDevelopmentRegion,'') <> ISNULL(a.NewDevelopmentRegion,'')
         THEN CONCAT(ISNULL(a.OldDevelopmentRegion,'<NULL>'),' -> ',ISNULL(a.NewDevelopmentRegion,'<NULL>')) END AS DevelopmentRegion_Change,
    CASE WHEN ISNULL(a.OldEmptyEffDt,'') <> ISNULL(a.NewEmptyEffDt,'')
         THEN CONCAT(ISNULL(a.OldEmptyEffDt,'<NULL>'),' -> ',ISNULL(a.NewEmptyEffDt,'<NULL>')) END AS EmptyEffDt_Change,
    CASE WHEN ISNULL(a.OldEmptyPosition,'') <> ISNULL(a.NewEmptyPosition,'')
         THEN CONCAT(ISNULL(a.OldEmptyPosition,'<NULL>'),' -> ',ISNULL(a.NewEmptyPosition,'<NULL>')) END AS EmptyPosition_Change,
    CASE WHEN ISNULL(a.OldExcludedOrIncluded,'') <> ISNULL(a.NewExcludedOrIncluded,'')
         THEN CONCAT(ISNULL(a.OldExcludedOrIncluded,'<NULL>'),' -> ',ISNULL(a.NewExcludedOrIncluded,'<NULL>')) END AS ExcludedOrIncluded_Change,
    CASE WHEN ISNULL(a.OldIncumbentCount,'') <> ISNULL(a.NewIncumbentCount,'')
         THEN CONCAT(ISNULL(a.OldIncumbentCount,'<NULL>'),' -> ',ISNULL(a.NewIncumbentCount,'<NULL>')) END AS IncumbentCount_Change,
    CASE WHEN ISNULL(a.OldIncumbents,'') <> ISNULL(a.NewIncumbents,'')
         THEN CONCAT(ISNULL(a.OldIncumbents,'<NULL>'),' -> ',ISNULL(a.NewIncumbents,'<NULL>')) END AS Incumbents_Change,
    CASE WHEN ISNULL(a.OldJobCode,'') <> ISNULL(a.NewJobCode,'')
         THEN CONCAT(ISNULL(a.OldJobCode,'<NULL>'),' -> ',ISNULL(a.NewJobCode,'<NULL>')) END AS JobCode_Change,
    CASE WHEN ISNULL(a.OldJobCodeDesc,'') <> ISNULL(a.NewJobCodeDesc,'')
         THEN CONCAT(ISNULL(a.OldJobCodeDesc,'<NULL>'),' -> ',ISNULL(a.NewJobCodeDesc,'<NULL>')) END AS JobCodeDesc_Change,
    CASE WHEN ISNULL(a.OldJobFunc,'') <> ISNULL(a.NewJobFunc,'')
         THEN CONCAT(ISNULL(a.OldJobFunc,'<NULL>'),' -> ',ISNULL(a.NewJobFunc,'<NULL>')) END AS JobFunc_Change,
    CASE WHEN ISNULL(a.OldJobReqOpenDate,'') <> ISNULL(a.NewJobReqOpenDate,'')
         THEN CONCAT(ISNULL(a.OldJobReqOpenDate,'<NULL>'),' -> ',ISNULL(a.NewJobReqOpenDate,'<NULL>')) END AS JobReqOpenDate_Change,
    CASE WHEN ISNULL(a.OldJobReqStatus,'') <> ISNULL(a.NewJobReqStatus,'')
         THEN CONCAT(ISNULL(a.OldJobReqStatus,'<NULL>'),' -> ',ISNULL(a.NewJobReqStatus,'<NULL>')) END AS JobReqStatus_Change,
    CASE WHEN ISNULL(a.OldLastIncumbents,'') <> ISNULL(a.NewLastIncumbents,'')
         THEN CONCAT(ISNULL(a.OldLastIncumbents,'<NULL>'),' -> ',ISNULL(a.NewLastIncumbents,'<NULL>')) END AS LastIncumbents_Change,
    CASE WHEN ISNULL(a.OldLocation,'') <> ISNULL(a.NewLocation,'')
         THEN CONCAT(ISNULL(a.OldLocation,'<NULL>'),' -> ',ISNULL(a.NewLocation,'<NULL>')) END AS Location_Change,
    CASE WHEN ISNULL(a.OldNocCode,'') <> ISNULL(a.NewNocCode,'')
         THEN CONCAT(ISNULL(a.OldNocCode,'<NULL>'),' -> ',ISNULL(a.NewNocCode,'<NULL>')) END AS NocCode_Change,
    CASE WHEN ISNULL(a.OldNocCodeDescr,'') <> ISNULL(a.NewNocCodeDescr,'')
         THEN CONCAT(ISNULL(a.OldNocCodeDescr,'<NULL>'),' -> ',ISNULL(a.NewNocCodeDescr,'<NULL>')) END AS NocCodeDescr_Change,
    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'),' -> ',ISNULL(a.NewOrganization,'<NULL>')) END AS Organization_Change,
    CASE WHEN ISNULL(a.OldPosStatusDescr,'') <> ISNULL(a.NewPosStatusDescr,'')
         THEN CONCAT(ISNULL(a.OldPosStatusDescr,'<NULL>'),' -> ',ISNULL(a.NewPosStatusDescr,'<NULL>')) END AS PosStatusDescr_Change,
    CASE WHEN ISNULL(a.OldPositionEmptyGt1Year,'') <> ISNULL(a.NewPositionEmptyGt1Year,'')
         THEN CONCAT(ISNULL(a.OldPositionEmptyGt1Year,'<NULL>'),' -> ',ISNULL(a.NewPositionEmptyGt1Year,'<NULL>')) END AS PositionEmptyGt1Year_Change,
    CASE WHEN ISNULL(a.OldPositionHasBaseIncumbent,'') <> ISNULL(a.NewPositionHasBaseIncumbent,'')
         THEN CONCAT(ISNULL(a.OldPositionHasBaseIncumbent,'<NULL>'),' -> ',ISNULL(a.NewPositionHasBaseIncumbent,'<NULL>')) END AS PositionHasBaseIncumbent_Change,
    CASE WHEN ISNULL(a.OldPositionTitle,'') <> ISNULL(a.NewPositionTitle,'')
         THEN CONCAT(ISNULL(a.OldPositionTitle,'<NULL>'),' -> ',ISNULL(a.NewPositionTitle,'<NULL>')) END AS PositionTitle_Change,
    CASE WHEN ISNULL(a.OldProgram,'') <> ISNULL(a.NewProgram,'')
         THEN CONCAT(ISNULL(a.OldProgram,'<NULL>'),' -> ',ISNULL(a.NewProgram,'<NULL>')) END AS Program_Change,
    CASE WHEN ISNULL(a.OldProgramBranch,'') <> ISNULL(a.NewProgramBranch,'')
         THEN CONCAT(ISNULL(a.OldProgramBranch,'<NULL>'),' -> ',ISNULL(a.NewProgramBranch,'<NULL>')) END AS ProgramBranch_Change,
    CASE WHEN ISNULL(a.OldProgramDivision,'') <> ISNULL(a.NewProgramDivision,'')
         THEN CONCAT(ISNULL(a.OldProgramDivision,'<NULL>'),' -> ',ISNULL(a.NewProgramDivision,'<NULL>')) END AS ProgramDivision_Change,
    CASE WHEN ISNULL(a.OldProvincialQuadrant,'') <> ISNULL(a.NewProvincialQuadrant,'')
         THEN CONCAT(ISNULL(a.OldProvincialQuadrant,'<NULL>'),' -> ',ISNULL(a.NewProvincialQuadrant,'<NULL>')) END AS ProvincialQuadrant_Change,
    CASE WHEN ISNULL(a.OldRegDistrictDesc,'') <> ISNULL(a.NewRegDistrictDesc,'')
         THEN CONCAT(ISNULL(a.OldRegDistrictDesc,'<NULL>'),' -> ',ISNULL(a.NewRegDistrictDesc,'<NULL>')) END AS RegDistrictDesc_Change,
    CASE WHEN ISNULL(a.OldRegOrTempDescr,'') <> ISNULL(a.NewRegOrTempDescr,'')
         THEN CONCAT(ISNULL(a.OldRegOrTempDescr,'<NULL>'),' -> ',ISNULL(a.NewRegOrTempDescr,'<NULL>')) END AS RegOrTempDescr_Change,
    CASE WHEN ISNULL(a.OldReportsTo,'') <> ISNULL(a.NewReportsTo,'')
         THEN CONCAT(ISNULL(a.OldReportsTo,'<NULL>'),' -> ',ISNULL(a.NewReportsTo,'<NULL>')) END AS ReportsTo_Change,
    CASE WHEN ISNULL(a.OldSupervisor,'') <> ISNULL(a.NewSupervisor,'')
         THEN CONCAT(ISNULL(a.OldSupervisor,'<NULL>'),' -> ',ISNULL(a.NewSupervisor,'<NULL>')) END AS Supervisor_Change,
    CASE WHEN ISNULL(a.OldYearsEmpty,'') <> ISNULL(a.NewYearsEmpty,'')
         THEN CONCAT(ISNULL(a.OldYearsEmpty,'<NULL>'),' -> ',ISNULL(a.NewYearsEmpty,'<NULL>')) END AS YearsEmpty_Change

FROM dbo.Peoplesoft_EPC_Audit a
INNER JOIN latest_run lr
    ON a.RunId = lr.RunId
LEFT JOIN dbo.Peoplesoft_EPC t
    ON t.Position = a.Position
WHERE a.ActionType = 'UPDATE'
  -- Uncomment to filter by a specific business key:
  -- AND a.Position = '00000000'
  -- Uncomment to exclude rows where no projected column actually changed:
  /*
  AND (
       ISNULL(a.OldBaseIncumbents,'')              <> ISNULL(a.NewBaseIncumbents,'')
    OR ISNULL(a.OldBusinessUnitDescr,'')           <> ISNULL(a.NewBusinessUnitDescr,'')
    OR ISNULL(a.OldCity,'')                        <> ISNULL(a.NewCity,'')
    OR ISNULL(a.OldClassificationGroup,'')         <> ISNULL(a.NewClassificationGroup,'')
    OR ISNULL(a.OldCore,'')                        <> ISNULL(a.NewCore,'')
    OR ISNULL(a.OldCreateEffDt,'')                 <> ISNULL(a.NewCreateEffDt,'')
    OR ISNULL(a.OldDeptId,'')                      <> ISNULL(a.NewDeptId,'')
    OR ISNULL(a.OldDeptIdDesc,'')                  <> ISNULL(a.NewDeptIdDesc,'')
    OR ISNULL(a.OldDevelopmentRegion,'')           <> ISNULL(a.NewDevelopmentRegion,'')
    OR ISNULL(a.OldEmptyEffDt,'')                  <> ISNULL(a.NewEmptyEffDt,'')
    OR ISNULL(a.OldEmptyPosition,'')               <> ISNULL(a.NewEmptyPosition,'')
    OR ISNULL(a.OldExcludedOrIncluded,'')          <> ISNULL(a.NewExcludedOrIncluded,'')
    OR ISNULL(a.OldIncumbentCount,'')              <> ISNULL(a.NewIncumbentCount,'')
    OR ISNULL(a.OldIncumbents,'')                  <> ISNULL(a.NewIncumbents,'')
    OR ISNULL(a.OldJobCode,'')                     <> ISNULL(a.NewJobCode,'')
    OR ISNULL(a.OldJobCodeDesc,'')                 <> ISNULL(a.NewJobCodeDesc,'')
    OR ISNULL(a.OldJobFunc,'')                     <> ISNULL(a.NewJobFunc,'')
    OR ISNULL(a.OldJobReqOpenDate,'')              <> ISNULL(a.NewJobReqOpenDate,'')
    OR ISNULL(a.OldJobReqStatus,'')                <> ISNULL(a.NewJobReqStatus,'')
    OR ISNULL(a.OldLastIncumbents,'')              <> ISNULL(a.NewLastIncumbents,'')
    OR ISNULL(a.OldLocation,'')                    <> ISNULL(a.NewLocation,'')
    OR ISNULL(a.OldNocCode,'')                     <> ISNULL(a.NewNocCode,'')
    OR ISNULL(a.OldNocCodeDescr,'')                <> ISNULL(a.NewNocCodeDescr,'')
    OR ISNULL(a.OldOrganization,'')                <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldPosStatusDescr,'')              <> ISNULL(a.NewPosStatusDescr,'')
    OR ISNULL(a.OldPositionEmptyGt1Year,'')        <> ISNULL(a.NewPositionEmptyGt1Year,'')
    OR ISNULL(a.OldPositionHasBaseIncumbent,'')    <> ISNULL(a.NewPositionHasBaseIncumbent,'')
    OR ISNULL(a.OldPositionTitle,'')               <> ISNULL(a.NewPositionTitle,'')
    OR ISNULL(a.OldProgram,'')                     <> ISNULL(a.NewProgram,'')
    OR ISNULL(a.OldProgramBranch,'')               <> ISNULL(a.NewProgramBranch,'')
    OR ISNULL(a.OldProgramDivision,'')             <> ISNULL(a.NewProgramDivision,'')
    OR ISNULL(a.OldProvincialQuadrant,'')          <> ISNULL(a.NewProvincialQuadrant,'')
    OR ISNULL(a.OldRegDistrictDesc,'')             <> ISNULL(a.NewRegDistrictDesc,'')
    OR ISNULL(a.OldRegOrTempDescr,'')              <> ISNULL(a.NewRegOrTempDescr,'')
    OR ISNULL(a.OldReportsTo,'')                   <> ISNULL(a.NewReportsTo,'')
    OR ISNULL(a.OldSupervisor,'')                  <> ISNULL(a.NewSupervisor,'')
    OR ISNULL(a.OldYearsEmpty,'')                  <> ISNULL(a.NewYearsEmpty,'')
  )
  */
ORDER BY a.Position, a.AuditDtmUtc DESC;
