-- Audit table for Datamart_CITZ_API_vw_Hires_Exits_and_Internal_Movements_CITZ
-- Captures INSERT / UPDATE / SOFT_DELETE / REACTIVATE actions from each MERGE run.
-- Full row hashes capture any column-level change; key analytical columns tracked Old/New.

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.Peoplesoft_HEM_Audit', 'U') IS NOT NULL
    DROP TABLE dbo.Peoplesoft_HEM_Audit;
GO

CREATE TABLE dbo.Peoplesoft_HEM_Audit
(
    -- ── Audit metadata ────────────────────────────────────────────────────────
    AuditId         BIGINT        NOT NULL IDENTITY(1,1),
    RunId           UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc     DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    ActionType      NVARCHAR(20)  NOT NULL,   -- INSERT | UPDATE | SOFT_DELETE | REACTIVATE

    -- ── Business key ─────────────────────────────────────────────────────────
    EmplId          NVARCHAR(20)  NOT NULL,
    EffDt           DATE          NOT NULL,
    EffSeq          INT           NOT NULL,
    EmplRcd         INT           NOT NULL,

    -- ── Row hash (full-row change detection) ─────────────────────────────────
    OldRowHash      VARBINARY(32) NULL,
    NewRowHash      VARBINARY(32) NULL,

    -- ── IsActive change ───────────────────────────────────────────────────────
    OldIsActive     BIT           NULL,
    NewIsActive     BIT           NULL,

    -- ── Key event header columns (Old / New) ─────────────────────────────────
    OldCompChange               NVARCHAR(100)  NULL,
    NewCompChange               NVARCHAR(100)  NULL,
    OldMoveType                 NVARCHAR(50)   NULL,
    NewMoveType                 NVARCHAR(50)   NULL,
    OldMoveType1                NVARCHAR(50)   NULL,
    NewMoveType1                NVARCHAR(50)   NULL,
    OldMoveType2                NVARCHAR(100)  NULL,
    NewMoveType2                NVARCHAR(100)  NULL,
    OldFiscalYear               INT            NULL,
    NewFiscalYear               INT            NULL,
    OldName                     NVARCHAR(255)  NULL,
    NewName                     NVARCHAR(255)  NULL,

    -- ── Key New-state columns (Old / New) ─────────────────────────────────────
    OldNewAction                NVARCHAR(10)   NULL,
    NewNewAction                NVARCHAR(10)   NULL,
    OldNewActionReasonDescr     NVARCHAR(255)  NULL,
    NewNewActionReasonDescr     NVARCHAR(255)  NULL,
    OldNewEmplStatus            NVARCHAR(10)   NULL,
    NewNewEmplStatus            NVARCHAR(10)   NULL,
    OldNewEmplCtg               NVARCHAR(20)   NULL,
    NewNewEmplCtg               NVARCHAR(20)   NULL,
    OldNewDeptId                NVARCHAR(50)   NULL,
    NewNewDeptId                NVARCHAR(50)   NULL,
    OldNewDeptIdDescr           NVARCHAR(255)  NULL,
    NewNewDeptIdDescr           NVARCHAR(255)  NULL,
    OldNewLevel1                NVARCHAR(255)  NULL,
    NewNewLevel1                NVARCHAR(255)  NULL,
    OldNewLevel2                NVARCHAR(255)  NULL,
    NewNewLevel2                NVARCHAR(255)  NULL,
    OldNewOrganization          NVARCHAR(255)  NULL,
    NewNewOrganization          NVARCHAR(255)  NULL,
    OldNewSalAdminPlan          NVARCHAR(20)   NULL,
    NewNewSalAdminPlan          NVARCHAR(20)   NULL,
    OldNewGrade                 NVARCHAR(20)   NULL,
    NewNewGrade                 NVARCHAR(20)   NULL,
    OldNewStep                  INT            NULL,
    NewNewStep                  INT            NULL,
    OldNewAnnualRt              DECIMAL(18,4)  NULL,
    NewNewAnnualRt              DECIMAL(18,4)  NULL,
    OldNewPositionNbr           NVARCHAR(20)   NULL,
    NewNewPositionNbr           NVARCHAR(20)   NULL,
    OldNewSupervisor            NVARCHAR(255)  NULL,
    NewNewSupervisor            NVARCHAR(255)  NULL,

    -- ── Key Prior-state columns (Old / New) ───────────────────────────────────
    OldPriorAction              NVARCHAR(10)   NULL,
    NewPriorAction              NVARCHAR(10)   NULL,
    OldPriorEmplStatus          NVARCHAR(10)   NULL,
    NewPriorEmplStatus          NVARCHAR(10)   NULL,
    OldPriorEmplCtg             NVARCHAR(20)   NULL,
    NewPriorEmplCtg             NVARCHAR(20)   NULL,
    OldPriorDeptId              NVARCHAR(50)   NULL,
    NewPriorDeptId              NVARCHAR(50)   NULL,
    OldPriorDeptIdDescr         NVARCHAR(255)  NULL,
    NewPriorDeptIdDescr         NVARCHAR(255)  NULL,
    OldPriorLevel1              NVARCHAR(255)  NULL,
    NewPriorLevel1              NVARCHAR(255)  NULL,
    OldPriorOrganization        NVARCHAR(255)  NULL,
    NewPriorOrganization        NVARCHAR(255)  NULL,
    OldPriorSalAdminPlan        NVARCHAR(20)   NULL,
    NewPriorSalAdminPlan        NVARCHAR(20)   NULL,
    OldPriorGrade               NVARCHAR(20)   NULL,
    NewPriorGrade               NVARCHAR(20)   NULL,
    OldPriorStep                INT            NULL,
    NewPriorStep                INT            NULL,
    OldPriorAnnualRt            DECIMAL(18,4)  NULL,
    NewPriorAnnualRt            DECIMAL(18,4)  NULL,

    CONSTRAINT PK_Peoplesoft_HEM_Audit PRIMARY KEY (AuditId)
);
GO

CREATE INDEX IX_Peoplesoft_HEM_Audit_RunId
ON dbo.Peoplesoft_HEM_Audit (RunId);
GO

CREATE INDEX IX_Peoplesoft_HEM_Audit_EmplId
ON dbo.Peoplesoft_HEM_Audit (EmplId, EffDt, EffSeq, EmplRcd);
GO
