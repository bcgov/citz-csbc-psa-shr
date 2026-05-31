-- =============================================================================
-- 02_target.sql
-- Target table: Datamart_CITZ_Report_TimeInPositionEmployee
-- Authoritative store. PK enforces business key uniqueness.
-- IsActive / soft-delete pattern. No RowHash needed (55 cols manageable).
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_TIP', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_TIP;
GO

CREATE TABLE dbo.Peoplesoft_TIP (

    -- -------------------------------------------------------------------------
    -- Business Key
    -- -------------------------------------------------------------------------
    EmployeeId                      NVARCHAR(20)       NOT NULL,
    Position                        NVARCHAR(20)       NOT NULL,
    EntryDate                       DATE               NOT NULL,
    EntrySeq                        INT                NOT NULL,

    -- -------------------------------------------------------------------------
    -- Employee Identifiers
    -- -------------------------------------------------------------------------
    EmployeeName                    NVARCHAR(255)      NULL,
    EmployeeRcd                     INT                NULL,
    Birthdate                       DATE               NULL,

    -- -------------------------------------------------------------------------
    -- Entry Event
    -- -------------------------------------------------------------------------
    EntryAction                     NVARCHAR(10)       NULL,
    EntryReason                     NVARCHAR(10)       NULL,
    EntryReasonDescr                NVARCHAR(255)      NULL,
    EntryRownumber                  INT                NULL,
    EntryStdHours                   INT                NULL,
    FirstDateInPosition             DATE               NULL,
    IncumbentCountAfterEntry        INT                NULL,

    -- -------------------------------------------------------------------------
    -- Exit Event
    -- -------------------------------------------------------------------------
    ExitAction                      NVARCHAR(10)       NULL,
    ExitDate                        DATE               NULL,
    ExitReason                      NVARCHAR(10)       NULL,
    ExitReasonDescr                 NVARCHAR(255)      NULL,
    ExitSeq                         INT                NULL,
    ExitStdHours                    INT                NULL,

    -- -------------------------------------------------------------------------
    -- Duration Metrics
    -- -------------------------------------------------------------------------
    DaysInPosition                  INT                NULL,
    YearsInPosition                 DECIMAL(10, 4)     NULL,
    AccumulatedYearsInPositions     DECIMAL(10, 4)     NULL,
    AgeAtEntry                      DECIMAL(10, 4)     NULL,
    AgeAtExit                       DECIMAL(10, 4)     NULL,

    -- -------------------------------------------------------------------------
    -- Classification at Entry
    -- -------------------------------------------------------------------------
    ClassificationGroupAtEntry      NVARCHAR(100)      NULL,
    JobCodeAtEntry                  NVARCHAR(20)       NULL,
    JobCodeDescAtEntry              NVARCHAR(255)      NULL,
    JobCodeDescGroupAtEntry         NVARCHAR(100)      NULL,

    -- -------------------------------------------------------------------------
    -- Current Position Details
    -- -------------------------------------------------------------------------
    CurrentApptStat                 NVARCHAR(10)       NULL,
    CurrentBase                     NVARCHAR(20)       NULL,
    CurrentDeptDescr                NVARCHAR(255)      NULL,
    CurrentDeptId                   NVARCHAR(50)       NULL,
    CurrentJobFunction              NVARCHAR(20)       NULL,
    CurrentJobcode                  NVARCHAR(20)       NULL,
    CurrentJobcodeDescr             NVARCHAR(255)      NULL,
    CurrentOrHistorical             NVARCHAR(20)       NULL,
    CurrentOrganization             NVARCHAR(255)      NULL,
    CurrentPosition                 NVARCHAR(20)       NULL,
    CurrentProgram                  NVARCHAR(100)      NULL,
    CurrentProgramBranch            NVARCHAR(255)      NULL,
    CurrentProgramDivision          NVARCHAR(255)      NULL,
    CurrentStatus                   NVARCHAR(10)       NULL,

    -- -------------------------------------------------------------------------
    -- Current Position Classification
    -- -------------------------------------------------------------------------
    PositionCurrentClassificationGroup     NVARCHAR(100)   NULL,
    PositionCurrentJobCode                 NVARCHAR(20)    NULL,
    PositionCurrentJobCodeDesc             NVARCHAR(255)   NULL,
    PositionCurrentJobCodeDescGroup        NVARCHAR(100)   NULL,
    PositionTitle                          NVARCHAR(255)   NULL,

    -- -------------------------------------------------------------------------
    -- Department and Org Hierarchy
    -- -------------------------------------------------------------------------
    Department                      NVARCHAR(255)      NULL,
    DeptId                          NVARCHAR(50)       NULL,
    Organization                    NVARCHAR(255)      NULL,
    Level1                          NVARCHAR(255)      NULL,
    Level2                          NVARCHAR(255)      NULL,
    Level3                          NVARCHAR(255)      NULL,

    -- -------------------------------------------------------------------------
    -- Other
    -- -------------------------------------------------------------------------
    Core                            NVARCHAR(20)       NULL,

    -- -------------------------------------------------------------------------
    -- Metadata
    -- -------------------------------------------------------------------------
    IsActive                        BIT                NOT NULL  DEFAULT 1,
    CreatedUtc                      DATETIME2(0)       NOT NULL  DEFAULT SYSUTCDATETIME(),
    LastUpdatedUtc                  DATETIME2(0)       NOT NULL  DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_Peoplesoft_TIP PRIMARY KEY (EmployeeId, Position, EntryDate, EntrySeq)
);
GO

-- Active records with key identifiers
CREATE NONCLUSTERED INDEX IX_Peoplesoft_TIP_IsActive
    ON dbo.Peoplesoft_TIP (IsActive)
    INCLUDE (EmployeeId, Position, EntryDate, ExitDate, DaysInPosition, YearsInPosition,
             Organization, Level1, ClassificationGroupAtEntry, CurrentOrHistorical);
GO

-- Employee lookup
CREATE NONCLUSTERED INDEX IX_Peoplesoft_TIP_EmployeeId
    ON dbo.Peoplesoft_TIP (EmployeeId)
    INCLUDE (Position, EntryDate, ExitDate, DaysInPosition, YearsInPosition,
             Organization, Level1, CurrentOrHistorical, IsActive);
GO

-- Organisation hierarchy lookup
CREATE NONCLUSTERED INDEX IX_Peoplesoft_TIP_OrgLevel
    ON dbo.Peoplesoft_TIP (Organization, Level1, Level2)
    INCLUDE (EmployeeId, Position, EntryDate, ExitDate, DaysInPosition,
             ClassificationGroupAtEntry, CurrentOrHistorical, IsActive);
GO
