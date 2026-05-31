-- =============================================================================
-- 05_dropped_stage.sql
-- Dropped records log: Datamart_CITZ_Report_TimeInPositionEmployee
-- Append-only table capturing records rejected before staging load.
-- DropReason values: 'NULL_EMPLOYEEID', 'DUPLICATE_COMPOSITE_KEY'
-- =============================================================================

IF OBJECT_ID('dbo.Stg_Peoplesoft_TIP_Dropped', 'U') IS NOT NULL
    DROP TABLE dbo.Stg_Peoplesoft_TIP_Dropped;
GO

CREATE TABLE dbo.Stg_Peoplesoft_TIP_Dropped (

    -- -------------------------------------------------------------------------
    -- Drop Metadata
    -- -------------------------------------------------------------------------
    DropReason                          NVARCHAR(50)       NOT NULL,
    LoadDtmUtc                          DATETIME2(0)       NOT NULL  DEFAULT SYSUTCDATETIME(),

    -- -------------------------------------------------------------------------
    -- All staging columns (mirror of Stg_Peoplesoft_TIP)
    -- -------------------------------------------------------------------------
    EmployeeId                          NVARCHAR(20)       NULL,
    Position                            NVARCHAR(20)       NULL,
    EntryDate                           DATE               NULL,
    EntrySeq                            INT                NULL,
    EmployeeName                        NVARCHAR(255)      NULL,
    EmployeeRcd                         INT                NULL,
    Birthdate                           DATE               NULL,
    EntryAction                         NVARCHAR(10)       NULL,
    EntryReason                         NVARCHAR(10)       NULL,
    EntryReasonDescr                    NVARCHAR(255)      NULL,
    EntryRownumber                      INT                NULL,
    EntryStdHours                       INT                NULL,
    FirstDateInPosition                 DATE               NULL,
    IncumbentCountAfterEntry            INT                NULL,
    ExitAction                          NVARCHAR(10)       NULL,
    ExitDate                            DATE               NULL,
    ExitReason                          NVARCHAR(10)       NULL,
    ExitReasonDescr                     NVARCHAR(255)      NULL,
    ExitSeq                             INT                NULL,
    ExitStdHours                        INT                NULL,
    DaysInPosition                      INT                NULL,
    YearsInPosition                     DECIMAL(10, 4)     NULL,
    AccumulatedYearsInPositions         DECIMAL(10, 4)     NULL,
    AgeAtEntry                          DECIMAL(10, 4)     NULL,
    AgeAtExit                           DECIMAL(10, 4)     NULL,
    ClassificationGroupAtEntry          NVARCHAR(100)      NULL,
    JobCodeAtEntry                      NVARCHAR(20)       NULL,
    JobCodeDescAtEntry                  NVARCHAR(255)      NULL,
    JobCodeDescGroupAtEntry             NVARCHAR(100)      NULL,
    CurrentApptStat                     NVARCHAR(10)       NULL,
    CurrentBase                         NVARCHAR(20)       NULL,
    CurrentDeptDescr                    NVARCHAR(255)      NULL,
    CurrentDeptId                       NVARCHAR(50)       NULL,
    CurrentJobFunction                  NVARCHAR(20)       NULL,
    CurrentJobcode                      NVARCHAR(20)       NULL,
    CurrentJobcodeDescr                 NVARCHAR(255)      NULL,
    CurrentOrHistorical                 NVARCHAR(20)       NULL,
    CurrentOrganization                 NVARCHAR(255)      NULL,
    CurrentPosition                     NVARCHAR(20)       NULL,
    CurrentProgram                      NVARCHAR(100)      NULL,
    CurrentProgramBranch                NVARCHAR(255)      NULL,
    CurrentProgramDivision              NVARCHAR(255)      NULL,
    CurrentStatus                       NVARCHAR(10)       NULL,
    PositionCurrentClassificationGroup  NVARCHAR(100)      NULL,
    PositionCurrentJobCode              NVARCHAR(20)       NULL,
    PositionCurrentJobCodeDesc          NVARCHAR(255)      NULL,
    PositionCurrentJobCodeDescGroup     NVARCHAR(100)      NULL,
    PositionTitle                       NVARCHAR(255)      NULL,
    Department                          NVARCHAR(255)      NULL,
    DeptId                              NVARCHAR(50)       NULL,
    Organization                        NVARCHAR(255)      NULL,
    Level1                              NVARCHAR(255)      NULL,
    Level2                              NVARCHAR(255)      NULL,
    Level3                              NVARCHAR(255)      NULL,
    Core                                NVARCHAR(20)       NULL
);
GO

CREATE NONCLUSTERED INDEX IX_Stg_Peoplesoft_TIP_Dropped_Reason
    ON dbo.Stg_Peoplesoft_TIP_Dropped (DropReason, LoadDtmUtc)
    INCLUDE (EmployeeId, Position, EntryDate);
GO
