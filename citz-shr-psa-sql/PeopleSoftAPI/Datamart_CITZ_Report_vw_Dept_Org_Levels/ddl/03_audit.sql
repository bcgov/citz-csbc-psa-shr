-- =============================================================================
-- Audit table: PeopleSoft_Dept_Org_Levels_Audit
-- API: Datamart_CITZ_Report_vw_Dept_Org_Levels
-- Business key: DepartmentID
-- Tracks: INSERT, UPDATE, SOFT_DELETE, REACTIVATE actions from MERGE proc
-- Append-only; do NOT truncate between runs
--
-- TYPE-SAFETY STANDARD (applies to all APIs):
--   All Old/New columns are NVARCHAR(255). The MERGE OUTPUT clause CASTs
--   every deleted.*/inserted.* value to NVARCHAR(255) before insert.
--   Never use DATE/INT/DECIMAL/BIT for Old/New columns -- they break the
--   MERGE OUTPUT bind on schema drift.
-- =============================================================================

IF OBJECT_ID('dbo.PeopleSoft_Dept_Org_Levels_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.PeopleSoft_Dept_Org_Levels_Audit;
GO

CREATE TABLE dbo.PeopleSoft_Dept_Org_Levels_Audit
(
    AuditId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    RunId           UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc     DATETIME2(0)     NOT NULL CONSTRAINT DF_PSA_AuditDtmUtc DEFAULT SYSUTCDATETIME(),

    ActionType      VARCHAR(12)      NOT NULL,  -- INSERT / UPDATE / SOFT_DELETE / REACTIVATE
    DepartmentID    VARCHAR(20)      NOT NULL,

    OldRowHash      VARBINARY(32)    NULL,
    NewRowHash      VARBINARY(32)    NULL,

    OldIsActive     NVARCHAR(255)    NULL,
    NewIsActive     NVARCHAR(255)    NULL,

    -- OLD values (all NVARCHAR(255))
    OldLevel1       NVARCHAR(255)    NULL,
    OldLevel1Key    NVARCHAR(255)    NULL,
    OldLevel2       NVARCHAR(255)    NULL,
    OldLevel2Key    NVARCHAR(255)    NULL,
    OldLevel3       NVARCHAR(255)    NULL,
    OldLevel3Key    NVARCHAR(255)    NULL,
    OldLevel4       NVARCHAR(255)    NULL,
    OldLevel4Key    NVARCHAR(255)    NULL,
    OldLevel5       NVARCHAR(255)    NULL,
    OldLevel5Key    NVARCHAR(255)    NULL,
    OldOrganization NVARCHAR(255)    NULL,

    -- NEW values (all NVARCHAR(255))
    NewLevel1       NVARCHAR(255)    NULL,
    NewLevel1Key    NVARCHAR(255)    NULL,
    NewLevel2       NVARCHAR(255)    NULL,
    NewLevel2Key    NVARCHAR(255)    NULL,
    NewLevel3       NVARCHAR(255)    NULL,
    NewLevel3Key    NVARCHAR(255)    NULL,
    NewLevel4       NVARCHAR(255)    NULL,
    NewLevel4Key    NVARCHAR(255)    NULL,
    NewLevel5       NVARCHAR(255)    NULL,
    NewLevel5Key    NVARCHAR(255)    NULL,
    NewOrganization NVARCHAR(255)    NULL
);
GO

CREATE INDEX IX_PeopleSoft_Dept_Org_Levels_Audit_RunId
ON dbo.PeopleSoft_Dept_Org_Levels_Audit(RunId, ActionType);
GO
