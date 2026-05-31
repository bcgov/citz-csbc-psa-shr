-- =============================================================================
-- 03_audit.sql
-- Audit table: Datamart_CITZ_Report_TimeInPositionEmployee
-- Records every INSERT, UPDATE, SOFT_DELETE, and REACTIVATE from the MERGE proc.
-- Old/New pairs cover the most analytically relevant columns.
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_TIP_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_TIP_Audit;
GO

CREATE TABLE dbo.Peoplesoft_TIP_Audit (

    -- -------------------------------------------------------------------------
    -- Audit Metadata
    -- -------------------------------------------------------------------------
    AuditId                     BIGINT              NOT NULL  IDENTITY(1, 1),
    RunId                       UNIQUEIDENTIFIER    NOT NULL  DEFAULT NEWID(),
    AuditDtmUtc                 DATETIME2(0)        NOT NULL  DEFAULT SYSUTCDATETIME(),
    ActionType                  NVARCHAR(20)        NOT NULL, -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- -------------------------------------------------------------------------
    -- Business Key
    -- -------------------------------------------------------------------------
    EmployeeId                  NVARCHAR(20)        NULL,
    Position                    NVARCHAR(20)        NULL,
    EntryDate                   DATE                NULL,
    EntrySeq                    INT                 NULL,

    -- -------------------------------------------------------------------------
    -- IsActive Before / After
    -- -------------------------------------------------------------------------
    OldIsActive                 BIT                 NULL,
    NewIsActive                 BIT                 NULL,

    -- -------------------------------------------------------------------------
    -- Duration Metrics Before / After
    -- -------------------------------------------------------------------------
    OldDaysInPosition           INT                 NULL,
    NewDaysInPosition           INT                 NULL,
    OldYearsInPosition          DECIMAL(10, 4)      NULL,
    NewYearsInPosition          DECIMAL(10, 4)      NULL,

    -- -------------------------------------------------------------------------
    -- Exit Event Before / After (tracks employees leaving a position)
    -- -------------------------------------------------------------------------
    OldExitDate                 DATE                NULL,
    NewExitDate                 DATE                NULL,
    OldExitAction               NVARCHAR(10)        NULL,
    NewExitAction               NVARCHAR(10)        NULL,
    OldExitReason               NVARCHAR(10)        NULL,
    NewExitReason               NVARCHAR(10)        NULL,
    OldExitReasonDescr          NVARCHAR(255)       NULL,
    NewExitReasonDescr          NVARCHAR(255)       NULL,

    -- -------------------------------------------------------------------------
    -- Org Hierarchy Before / After
    -- -------------------------------------------------------------------------
    OldOrganization             NVARCHAR(255)       NULL,
    NewOrganization             NVARCHAR(255)       NULL,
    OldLevel1                   NVARCHAR(255)       NULL,
    NewLevel1                   NVARCHAR(255)       NULL,
    OldLevel2                   NVARCHAR(255)       NULL,
    NewLevel2                   NVARCHAR(255)       NULL,
    OldDeptId                   NVARCHAR(50)        NULL,
    NewDeptId                   NVARCHAR(50)        NULL,

    -- -------------------------------------------------------------------------
    -- Classification Before / After
    -- -------------------------------------------------------------------------
    OldClassificationGroupAtEntry   NVARCHAR(100)   NULL,
    NewClassificationGroupAtEntry   NVARCHAR(100)   NULL,
    OldJobCodeAtEntry               NVARCHAR(20)    NULL,
    NewJobCodeAtEntry               NVARCHAR(20)    NULL,

    -- -------------------------------------------------------------------------
    -- Current State Before / After
    -- -------------------------------------------------------------------------
    OldCurrentOrHistorical      NVARCHAR(20)        NULL,
    NewCurrentOrHistorical      NVARCHAR(20)        NULL,
    OldCurrentStatus            NVARCHAR(10)        NULL,
    NewCurrentStatus            NVARCHAR(10)        NULL,
    OldCurrentOrganization      NVARCHAR(255)       NULL,
    NewCurrentOrganization      NVARCHAR(255)       NULL,
    OldCurrentDeptId            NVARCHAR(50)        NULL,
    NewCurrentDeptId            NVARCHAR(50)        NULL,

    CONSTRAINT PK_Peoplesoft_TIP_Audit PRIMARY KEY (AuditId)
);
GO

CREATE NONCLUSTERED INDEX IX_Peoplesoft_TIP_Audit_RunId
    ON dbo.Peoplesoft_TIP_Audit (RunId)
    INCLUDE (ActionType, EmployeeId, Position, EntryDate);
GO

CREATE NONCLUSTERED INDEX IX_Peoplesoft_TIP_Audit_EmployeeId
    ON dbo.Peoplesoft_TIP_Audit (EmployeeId)
    INCLUDE (Position, EntryDate, ActionType, AuditDtmUtc);
GO
