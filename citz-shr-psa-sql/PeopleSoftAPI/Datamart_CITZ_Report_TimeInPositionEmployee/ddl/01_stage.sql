-- =============================================================================
-- 01_stage.sql
-- Staging table: Datamart_CITZ_Report_TimeInPositionEmployee
-- Landing zone for raw API data. No PK (report-style). All columns nullable.
-- JSON field names are noted in comments where they differ from SQL column names.
-- =============================================================================

IF OBJECT_ID('dbo.Stg_Peoplesoft_TIP', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_TIP;
GO

CREATE TABLE dbo.Stg_Peoplesoft_TIP (

    -- -------------------------------------------------------------------------
    -- Business Key (JSON names match SQL names exactly except as noted)
    -- -------------------------------------------------------------------------
    EmployeeId                      NVARCHAR(20)       NULL,   -- JSON: "EmployeeID"
    Position                        NVARCHAR(20)       NULL,
    EntryDate                       DATE               NULL,   -- JSON: "Entry_Date"
    EntrySeq                        INT                NULL,   -- JSON: "Entry_Seq"

    -- -------------------------------------------------------------------------
    -- Employee Identifiers
    -- -------------------------------------------------------------------------
    EmployeeName                    NVARCHAR(255)      NULL,   -- JSON: "Employee_Name"
    EmployeeRcd                     INT                NULL,   -- JSON: "Employee_Rcd"
    Birthdate                       DATE               NULL,

    -- -------------------------------------------------------------------------
    -- Entry Event
    -- -------------------------------------------------------------------------
    EntryAction                     NVARCHAR(10)       NULL,   -- JSON: "Entry_Action"
    EntryReason                     NVARCHAR(10)       NULL,   -- JSON: "Entry_Reason"
    EntryReasonDescr                NVARCHAR(255)      NULL,   -- JSON: "Entry_Reason_Descr"
    EntryRownumber                  INT                NULL,   -- JSON: "Entry_Rownumber"
    EntryStdHours                   INT                NULL,   -- JSON: "Entry_Std_Hours"
    FirstDateInPosition             DATE               NULL,   -- JSON: "First_Date_In_Position"
    IncumbentCountAfterEntry        INT                NULL,   -- JSON: "Incumbent_Count_After_Entry"

    -- -------------------------------------------------------------------------
    -- Exit Event (NULL for current/active employees still in position)
    -- -------------------------------------------------------------------------
    ExitAction                      NVARCHAR(10)       NULL,   -- JSON: "Exit_Action"       ~2764 nulls
    ExitDate                        DATE               NULL,   -- JSON: "Exit_Date"         ~2764 nulls
    ExitReason                      NVARCHAR(10)       NULL,   -- JSON: "Exit_Reason"       ~2764 nulls
    ExitReasonDescr                 NVARCHAR(255)      NULL,   -- JSON: "Exit_Reason_Descr" ~2764 nulls
    ExitSeq                         INT                NULL,   -- JSON: "Exit_Seq"          ~2764 nulls
    ExitStdHours                    INT                NULL,   -- JSON: "Exit_Std_Hours"

    -- -------------------------------------------------------------------------
    -- Duration Metrics
    -- -------------------------------------------------------------------------
    DaysInPosition                  INT                NULL,   -- JSON: "Days_in_Position"
    YearsInPosition                 DECIMAL(10, 4)     NULL,   -- JSON: "Years_in_Position"
    AccumulatedYearsInPositions     DECIMAL(10, 4)     NULL,   -- JSON: "Accumulated_Years_in_Positions"
    AgeAtEntry                      DECIMAL(10, 4)     NULL,   -- JSON: "Age_at_Entry"
    AgeAtExit                       DECIMAL(10, 4)     NULL,   -- JSON: "Age_at_Exit"

    -- -------------------------------------------------------------------------
    -- Classification at Entry
    -- -------------------------------------------------------------------------
    ClassificationGroupAtEntry      NVARCHAR(100)      NULL,   -- JSON: "ClassificationGroup_at_Entry"
    JobCodeAtEntry                  NVARCHAR(20)       NULL,   -- JSON: "Job_Code_at_Entry"
    JobCodeDescAtEntry              NVARCHAR(255)      NULL,   -- JSON: "JobCodeDesc_at_Entry"
    JobCodeDescGroupAtEntry         NVARCHAR(100)      NULL,   -- JSON: "JobCodeDescGroup_at_Entry"

    -- -------------------------------------------------------------------------
    -- Current Position Details
    -- -------------------------------------------------------------------------
    CurrentApptStat                 NVARCHAR(10)       NULL,   -- JSON: "Current_Appt_Stat"
    CurrentBase                     NVARCHAR(20)       NULL,   -- JSON: "Current_Base"
    CurrentDeptDescr                NVARCHAR(255)      NULL,   -- JSON: "Current_Dept_Descr"
    CurrentDeptId                   NVARCHAR(50)       NULL,   -- JSON: "Current_DeptID"
    CurrentJobFunction              NVARCHAR(20)       NULL,   -- JSON: "Current_Job_Function"
    CurrentJobcode                  NVARCHAR(20)       NULL,   -- JSON: "Current_Jobcode"
    CurrentJobcodeDescr             NVARCHAR(255)      NULL,   -- JSON: "Current_Jobcode_Descr"
    CurrentOrHistorical             NVARCHAR(20)       NULL,   -- JSON: "Current_or_Historical"
    CurrentOrganization             NVARCHAR(255)      NULL,   -- JSON: "Current_Organization"
    CurrentPosition                 NVARCHAR(20)       NULL,   -- JSON: "Current_Position"
    CurrentProgram                  NVARCHAR(100)      NULL,   -- JSON: "Current_Program"
    CurrentProgramBranch            NVARCHAR(255)      NULL,   -- JSON: "Current_Program_Branch"  ~13 nulls
    CurrentProgramDivision          NVARCHAR(255)      NULL,   -- JSON: "Current_Program_Division"
    CurrentStatus                   NVARCHAR(10)       NULL,   -- JSON: "Current_Status"

    -- -------------------------------------------------------------------------
    -- Current Position Classification
    -- -------------------------------------------------------------------------
    PositionCurrentClassificationGroup     NVARCHAR(100)   NULL,  -- JSON: "Position_Current_ClassificationGroup" ~21 nulls
    PositionCurrentJobCode                 NVARCHAR(20)    NULL,  -- JSON: "Position_Current_Job_Code"
    PositionCurrentJobCodeDesc             NVARCHAR(255)   NULL,  -- JSON: "Position_Current_JobCodeDesc" ~21 nulls
    PositionCurrentJobCodeDescGroup        NVARCHAR(100)   NULL,  -- JSON: "Position_Current_JobCodeDescGroup" ~21 nulls
    PositionTitle                          NVARCHAR(255)   NULL,  -- JSON: "Position_Title"

    -- -------------------------------------------------------------------------
    -- Department and Org Hierarchy (at time of event)
    -- -------------------------------------------------------------------------
    Department                      NVARCHAR(255)      NULL,   -- JSON: "Department"   ~21 nulls
    DeptId                          NVARCHAR(50)       NULL,   -- JSON: "DEPTID"
    Organization                    NVARCHAR(255)      NULL,   -- JSON: "Organization"  ~21 nulls
    Level1                          NVARCHAR(255)      NULL,   -- JSON: "Level1"        ~21 nulls
    Level2                          NVARCHAR(255)      NULL,   -- JSON: "Level2"        ~87 nulls
    Level3                          NVARCHAR(255)      NULL,   -- JSON: "Level3"        ~1610 nulls

    -- -------------------------------------------------------------------------
    -- Other
    -- -------------------------------------------------------------------------
    Core                            NVARCHAR(20)       NULL    -- JSON: "core" (lowercase)  ~21 nulls

);
GO
