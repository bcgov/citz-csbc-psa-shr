-- =============================================================================
-- Audit table: Peoplesoft_HEM_Audit
-- API: Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
-- Business key: composite (EmplId, EffDt, EffSeq, EmplRcd)
-- Tracks: INSERT, UPDATE, SOFT_DELETE, REACTIVATE actions from MERGE proc
-- Append-only; do NOT truncate between runs
--
-- TYPE-SAFETY STANDARD (applies to all APIs):
--   All Old/New columns are NVARCHAR(255). The MERGE OUTPUT clause CASTs
--   every deleted.*/inserted.* value to NVARCHAR(255) before insert.
--   Never use DATE/INT/DECIMAL/BIT for Old/New columns -- they break the
--   MERGE OUTPUT bind on schema drift.
-- =============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Peoplesoft_HEM_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_HEM_Audit;
GO

CREATE TABLE dbo.Peoplesoft_HEM_Audit
(
    -- Audit metadata
    AuditId         BIGINT           NOT NULL IDENTITY(1,1),
    RunId           UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc     DATETIME2(0)     NOT NULL DEFAULT SYSUTCDATETIME(),
    ActionType      VARCHAR(12)      NOT NULL,   -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- Business key (native types preserved)
    EmplId          NVARCHAR(20)     NOT NULL,
    EffDt           DATE             NOT NULL,
    EffSeq          INT              NOT NULL,
    EmplRcd         INT              NOT NULL,

    -- Row hashes
    OldRowHash      VARBINARY(32)    NULL,
    NewRowHash      VARBINARY(32)    NULL,

    -- IsActive change
    OldIsActive     NVARCHAR(255)    NULL,
    NewIsActive     NVARCHAR(255)    NULL,

    -- Header columns (Old / New) -- all NVARCHAR(255)
    OldCompChange               NVARCHAR(255) NULL,
    NewCompChange               NVARCHAR(255) NULL,
    OldMoveType                 NVARCHAR(255) NULL,
    NewMoveType                 NVARCHAR(255) NULL,
    OldMoveType1                NVARCHAR(255) NULL,
    NewMoveType1                NVARCHAR(255) NULL,
    OldMoveType2                NVARCHAR(255) NULL,
    NewMoveType2                NVARCHAR(255) NULL,
    OldFiscalYear               NVARCHAR(255) NULL,
    NewFiscalYear               NVARCHAR(255) NULL,
    OldName                     NVARCHAR(255) NULL,
    NewName                     NVARCHAR(255) NULL,

    -- New-state key columns (Old / New) -- all NVARCHAR(255)
    OldNewAction                NVARCHAR(255) NULL,
    NewNewAction                NVARCHAR(255) NULL,
    OldNewActionReasonDescr     NVARCHAR(255) NULL,
    NewNewActionReasonDescr     NVARCHAR(255) NULL,
    OldNewEmplStatus            NVARCHAR(255) NULL,
    NewNewEmplStatus            NVARCHAR(255) NULL,
    OldNewEmplCtg               NVARCHAR(255) NULL,
    NewNewEmplCtg               NVARCHAR(255) NULL,
    OldNewDeptId                NVARCHAR(255) NULL,
    NewNewDeptId                NVARCHAR(255) NULL,
    OldNewDeptIdDescr           NVARCHAR(255) NULL,
    NewNewDeptIdDescr           NVARCHAR(255) NULL,
    OldNewLevel1                NVARCHAR(255) NULL,
    NewNewLevel1                NVARCHAR(255) NULL,
    OldNewLevel2                NVARCHAR(255) NULL,
    NewNewLevel2                NVARCHAR(255) NULL,
    OldNewOrganization          NVARCHAR(255) NULL,
    NewNewOrganization          NVARCHAR(255) NULL,
    OldNewSalAdminPlan          NVARCHAR(255) NULL,
    NewNewSalAdminPlan          NVARCHAR(255) NULL,
    OldNewGrade                 NVARCHAR(255) NULL,
    NewNewGrade                 NVARCHAR(255) NULL,
    OldNewStep                  NVARCHAR(255) NULL,
    NewNewStep                  NVARCHAR(255) NULL,
    OldNewAnnualRt              NVARCHAR(255) NULL,
    NewNewAnnualRt              NVARCHAR(255) NULL,
    OldNewPositionNbr           NVARCHAR(255) NULL,
    NewNewPositionNbr           NVARCHAR(255) NULL,
    OldNewSupervisor            NVARCHAR(255) NULL,
    NewNewSupervisor            NVARCHAR(255) NULL,

    -- Prior-state key columns (Old / New) -- all NVARCHAR(255)
    OldPriorAction              NVARCHAR(255) NULL,
    NewPriorAction              NVARCHAR(255) NULL,
    OldPriorEmplStatus          NVARCHAR(255) NULL,
    NewPriorEmplStatus          NVARCHAR(255) NULL,
    OldPriorEmplCtg             NVARCHAR(255) NULL,
    NewPriorEmplCtg             NVARCHAR(255) NULL,
    OldPriorDeptId              NVARCHAR(255) NULL,
    NewPriorDeptId              NVARCHAR(255) NULL,
    OldPriorDeptIdDescr         NVARCHAR(255) NULL,
    NewPriorDeptIdDescr         NVARCHAR(255) NULL,
    OldPriorLevel1              NVARCHAR(255) NULL,
    NewPriorLevel1              NVARCHAR(255) NULL,
    OldPriorOrganization        NVARCHAR(255) NULL,
    NewPriorOrganization        NVARCHAR(255) NULL,
    OldPriorSalAdminPlan        NVARCHAR(255) NULL,
    NewPriorSalAdminPlan        NVARCHAR(255) NULL,
    OldPriorGrade               NVARCHAR(255) NULL,
    NewPriorGrade               NVARCHAR(255) NULL,
    OldPriorStep                NVARCHAR(255) NULL,
    NewPriorStep                NVARCHAR(255) NULL,
    OldPriorAnnualRt            NVARCHAR(255) NULL,
    NewPriorAnnualRt            NVARCHAR(255) NULL,

    CONSTRAINT PK_Peoplesoft_HEM_Audit PRIMARY KEY (AuditId)
);
GO

CREATE INDEX IX_Peoplesoft_HEM_Audit_RunId
ON dbo.Peoplesoft_HEM_Audit (RunId);
GO

CREATE INDEX IX_Peoplesoft_HEM_Audit_EmplId
ON dbo.Peoplesoft_HEM_Audit (EmplId, EffDt, EffSeq, EmplRcd);
GO
