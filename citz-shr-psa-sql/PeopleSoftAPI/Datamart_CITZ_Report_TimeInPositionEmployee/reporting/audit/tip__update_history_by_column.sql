/*=============================================================================
File: tip__update_history_by_column.sql
Purpose:
  Column-level change diagnostic for UPDATE actions in the TIP audit table.
  Shows exactly which columns changed per row. Use to identify
  continuously-computed columns causing false updates.
Audit table : dbo.Peoplesoft_TIP_Audit
Target table: dbo.Peoplesoft_TIP
Business key: EmployeeId, Position, EntryDate, EntrySeq

Note: TIP uses the OR-comparison MERGE strategy (no RowHash), so the
OldRowHash / NewRowHash columns do not exist in this audit table.
=============================================================================*/

SET NOCOUNT ON;

;WITH latest_run AS (
    SELECT MAX(RunId) AS RunId FROM dbo.Peoplesoft_TIP_Audit
)
SELECT
    a.AuditDtmUtc,
    a.RunId,
    a.EmployeeId,
    a.Position,
    a.EntryDate,
    a.EntrySeq,
    t.EmployeeName AS CurrentEmployeeName,
    t.CurrentOrganization,

    CASE WHEN ISNULL(a.OldDaysInPosition,'') <> ISNULL(a.NewDaysInPosition,'')
         THEN CONCAT(ISNULL(a.OldDaysInPosition,'<NULL>'),' -> ',ISNULL(a.NewDaysInPosition,'<NULL>')) END AS DaysInPosition_Change,
    CASE WHEN ISNULL(a.OldYearsInPosition,'') <> ISNULL(a.NewYearsInPosition,'')
         THEN CONCAT(ISNULL(a.OldYearsInPosition,'<NULL>'),' -> ',ISNULL(a.NewYearsInPosition,'<NULL>')) END AS YearsInPosition_Change,
    CASE WHEN ISNULL(a.OldExitDate,'') <> ISNULL(a.NewExitDate,'')
         THEN CONCAT(ISNULL(a.OldExitDate,'<NULL>'),' -> ',ISNULL(a.NewExitDate,'<NULL>')) END AS ExitDate_Change,
    CASE WHEN ISNULL(a.OldExitAction,'') <> ISNULL(a.NewExitAction,'')
         THEN CONCAT(ISNULL(a.OldExitAction,'<NULL>'),' -> ',ISNULL(a.NewExitAction,'<NULL>')) END AS ExitAction_Change,
    CASE WHEN ISNULL(a.OldExitReason,'') <> ISNULL(a.NewExitReason,'')
         THEN CONCAT(ISNULL(a.OldExitReason,'<NULL>'),' -> ',ISNULL(a.NewExitReason,'<NULL>')) END AS ExitReason_Change,
    CASE WHEN ISNULL(a.OldExitReasonDescr,'') <> ISNULL(a.NewExitReasonDescr,'')
         THEN CONCAT(ISNULL(a.OldExitReasonDescr,'<NULL>'),' -> ',ISNULL(a.NewExitReasonDescr,'<NULL>')) END AS ExitReasonDescr_Change,
    CASE WHEN ISNULL(a.OldOrganization,'') <> ISNULL(a.NewOrganization,'')
         THEN CONCAT(ISNULL(a.OldOrganization,'<NULL>'),' -> ',ISNULL(a.NewOrganization,'<NULL>')) END AS Organization_Change,
    CASE WHEN ISNULL(a.OldLevel1,'') <> ISNULL(a.NewLevel1,'')
         THEN CONCAT(ISNULL(a.OldLevel1,'<NULL>'),' -> ',ISNULL(a.NewLevel1,'<NULL>')) END AS Level1_Change,
    CASE WHEN ISNULL(a.OldLevel2,'') <> ISNULL(a.NewLevel2,'')
         THEN CONCAT(ISNULL(a.OldLevel2,'<NULL>'),' -> ',ISNULL(a.NewLevel2,'<NULL>')) END AS Level2_Change,
    CASE WHEN ISNULL(a.OldDeptId,'') <> ISNULL(a.NewDeptId,'')
         THEN CONCAT(ISNULL(a.OldDeptId,'<NULL>'),' -> ',ISNULL(a.NewDeptId,'<NULL>')) END AS DeptId_Change,
    CASE WHEN ISNULL(a.OldClassificationGroupAtEntry,'') <> ISNULL(a.NewClassificationGroupAtEntry,'')
         THEN CONCAT(ISNULL(a.OldClassificationGroupAtEntry,'<NULL>'),' -> ',ISNULL(a.NewClassificationGroupAtEntry,'<NULL>')) END AS ClassificationGroupAtEntry_Change,
    CASE WHEN ISNULL(a.OldJobCodeAtEntry,'') <> ISNULL(a.NewJobCodeAtEntry,'')
         THEN CONCAT(ISNULL(a.OldJobCodeAtEntry,'<NULL>'),' -> ',ISNULL(a.NewJobCodeAtEntry,'<NULL>')) END AS JobCodeAtEntry_Change,
    CASE WHEN ISNULL(a.OldCurrentOrHistorical,'') <> ISNULL(a.NewCurrentOrHistorical,'')
         THEN CONCAT(ISNULL(a.OldCurrentOrHistorical,'<NULL>'),' -> ',ISNULL(a.NewCurrentOrHistorical,'<NULL>')) END AS CurrentOrHistorical_Change,
    CASE WHEN ISNULL(a.OldCurrentStatus,'') <> ISNULL(a.NewCurrentStatus,'')
         THEN CONCAT(ISNULL(a.OldCurrentStatus,'<NULL>'),' -> ',ISNULL(a.NewCurrentStatus,'<NULL>')) END AS CurrentStatus_Change,
    CASE WHEN ISNULL(a.OldCurrentOrganization,'') <> ISNULL(a.NewCurrentOrganization,'')
         THEN CONCAT(ISNULL(a.OldCurrentOrganization,'<NULL>'),' -> ',ISNULL(a.NewCurrentOrganization,'<NULL>')) END AS CurrentOrganization_Change,
    CASE WHEN ISNULL(a.OldCurrentDeptId,'') <> ISNULL(a.NewCurrentDeptId,'')
         THEN CONCAT(ISNULL(a.OldCurrentDeptId,'<NULL>'),' -> ',ISNULL(a.NewCurrentDeptId,'<NULL>')) END AS CurrentDeptId_Change

FROM dbo.Peoplesoft_TIP_Audit a
INNER JOIN latest_run lr
    ON a.RunId = lr.RunId
LEFT JOIN dbo.Peoplesoft_TIP t
    ON  t.EmployeeId = a.EmployeeId
    AND t.Position   = a.Position
    AND t.EntryDate  = a.EntryDate
    AND t.EntrySeq   = a.EntrySeq
WHERE a.ActionType = 'UPDATE'
  -- Uncomment to filter by a specific business key:
  -- AND a.EmployeeId = '000000'
  -- AND a.Position   = '00000000'
  -- AND a.EntryDate  = '2022-01-01'
  -- AND a.EntrySeq   = 0
  -- Uncomment to exclude rows where no projected column actually changed:
  /*
  AND (
       ISNULL(a.OldDaysInPosition,'')              <> ISNULL(a.NewDaysInPosition,'')
    OR ISNULL(a.OldYearsInPosition,'')             <> ISNULL(a.NewYearsInPosition,'')
    OR ISNULL(a.OldExitDate,'')                    <> ISNULL(a.NewExitDate,'')
    OR ISNULL(a.OldExitAction,'')                  <> ISNULL(a.NewExitAction,'')
    OR ISNULL(a.OldExitReason,'')                  <> ISNULL(a.NewExitReason,'')
    OR ISNULL(a.OldExitReasonDescr,'')             <> ISNULL(a.NewExitReasonDescr,'')
    OR ISNULL(a.OldOrganization,'')                <> ISNULL(a.NewOrganization,'')
    OR ISNULL(a.OldLevel1,'')                      <> ISNULL(a.NewLevel1,'')
    OR ISNULL(a.OldLevel2,'')                      <> ISNULL(a.NewLevel2,'')
    OR ISNULL(a.OldDeptId,'')                      <> ISNULL(a.NewDeptId,'')
    OR ISNULL(a.OldClassificationGroupAtEntry,'')  <> ISNULL(a.NewClassificationGroupAtEntry,'')
    OR ISNULL(a.OldJobCodeAtEntry,'')              <> ISNULL(a.NewJobCodeAtEntry,'')
    OR ISNULL(a.OldCurrentOrHistorical,'')         <> ISNULL(a.NewCurrentOrHistorical,'')
    OR ISNULL(a.OldCurrentStatus,'')               <> ISNULL(a.NewCurrentStatus,'')
    OR ISNULL(a.OldCurrentOrganization,'')         <> ISNULL(a.NewCurrentOrganization,'')
    OR ISNULL(a.OldCurrentDeptId,'')               <> ISNULL(a.NewCurrentDeptId,'')
  )
  */
ORDER BY a.EmployeeId, a.Position, a.EntryDate, a.EntrySeq, a.AuditDtmUtc DESC;
