-- =============================================================================
-- 03_audit.sql
-- Audit table: Peoplesoft_TIP_Audit
-- API: Datamart_CITZ_Report_TimeInPositionEmployee
-- Business key: composite (EmployeeId, Position, EntryDate, EntrySeq)
-- Tracks: INSERT, UPDATE, SOFT_DELETE, REACTIVATE actions from MERGE proc
-- Append-only; do NOT truncate between runs
--
-- TYPE-SAFETY STANDARD (applies to all APIs):
--   All Old/New columns are NVARCHAR(255). The MERGE OUTPUT clause CASTs
--   every deleted.*/inserted.* value to NVARCHAR(255) before insert.
--   Never use DATE/INT/DECIMAL/BIT for Old/New columns -- they break the
--   MERGE OUTPUT bind on schema drift.
-- =============================================================================

IF OBJECT_ID('dbo.Peoplesoft_TIP_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_TIP_Audit;
GO

CREATE TABLE dbo.Peoplesoft_TIP_Audit (

    -- Audit Metadata
    AuditId                     BIGINT              NOT NULL  IDENTITY(1, 1),
    RunId                       UNIQUEIDENTIFIER    NOT NULL  DEFAULT NEWID(),
    AuditDtmUtc                 DATETIME2(0)        NOT NULL  DEFAULT SYSUTCDATETIME(),
    ActionType                  VARCHAR(12)         NOT NULL, -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- Business Key (native types preserved)
    EmployeeId                  NVARCHAR(20)        NULL,
    Position                    NVARCHAR(20)        NULL,
    EntryDate                   DATE                NULL,
    EntrySeq                    INT                 NULL,

    -- IsActive Before / After
    OldIsActive                 NVARCHAR(255)       NULL,
    NewIsActive                 NVARCHAR(255)       NULL,

    -- Duration Metrics Before / After
    OldDaysInPosition           NVARCHAR(255)       NULL,
    NewDaysInPosition           NVARCHAR(255)       NULL,
    OldYearsInPosition          NVARCHAR(255)       NULL,
    NewYearsInPosition          NVARCHAR(255)       NULL,

    -- Exit Event Before / After
    OldExitDate                 NVARCHAR(255)       NULL,
    NewExitDate                 NVARCHAR(255)       NULL,
    OldExitAction               NVARCHAR(255)       NULL,
    NewExitAction               NVARCHAR(255)       NULL,
    OldExitReason               NVARCHAR(255)       NULL,
    NewExitReason               NVARCHAR(255)       NULL,
    OldExitReasonDescr          NVARCHAR(255)       NULL,
    NewExitReasonDescr          NVARCHAR(255)       NULL,

    -- Org Hierarchy Before / After
    OldOrganization             NVARCHAR(255)       NULL,
    NewOrganization             NVARCHAR(255)       NULL,
    OldLevel1                   NVARCHAR(255)       NULL,
    NewLevel1                   NVARCHAR(255)       NULL,
    OldLevel2                   NVARCHAR(255)       NULL,
    NewLevel2                   NVARCHAR(255)       NULL,
    OldDeptId                   NVARCHAR(255)       NULL,
    NewDeptId                   NVARCHAR(255)       NULL,

    -- Classification Before / After
    OldClassificationGroupAtEntry   NVARCHAR(255)   NULL,
    NewClassificationGroupAtEntry   NVARCHAR(255)   NULL,
    OldJobCodeAtEntry               NVARCHAR(255)   NULL,
    NewJobCodeAtEntry               NVARCHAR(255)   NULL,

    -- Current State Before / After
    OldCurrentOrHistorical      NVARCHAR(255)       NULL,
    NewCurrentOrHistorical      NVARCHAR(255)       NULL,
    OldCurrentStatus            NVARCHAR(255)       NULL,
    NewCurrentStatus            NVARCHAR(255)       NULL,
    OldCurrentOrganization      NVARCHAR(255)       NULL,
    NewCurrentOrganization      NVARCHAR(255)       NULL,
    OldCurrentDeptId            NVARCHAR(255)       NULL,
    NewCurrentDeptId            NVARCHAR(255)       NULL,

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
