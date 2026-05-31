CREATE TABLE dbo.PeopleSoft_Dept_Org_Levels_Audit
(
    AuditId         BIGINT IDENTITY(1,1) PRIMARY KEY,
    RunId           UNIQUEIDENTIFIER NOT NULL,
    AuditDtmUtc     DATETIME2(0)     NOT NULL CONSTRAINT DF_PSA_AuditDtmUtc DEFAULT SYSUTCDATETIME(),

    ActionType      VARCHAR(12)      NOT NULL,  -- INSERT / UPDATE / SOFT_DELETE / REACTIVATE
    DepartmentID    VARCHAR(20)      NOT NULL,

    OldRowHash      VARBINARY(32)    NULL,
    NewRowHash      VARBINARY(32)    NULL,

    OldIsActive     BIT             NULL,
    NewIsActive     BIT             NULL,

    -- OLD values
    OldLevel1       NVARCHAR(255)   NULL,
    OldLevel1Key    INT            NULL,
    OldLevel2       NVARCHAR(255)   NULL,
    OldLevel2Key    INT            NULL,
    OldLevel3       NVARCHAR(255)   NULL,
    OldLevel3Key    INT            NULL,
    OldLevel4       NVARCHAR(255)   NULL,
    OldLevel4Key    INT            NULL,
    OldLevel5       NVARCHAR(255)   NULL,
    OldLevel5Key    INT            NULL,
    OldOrganization NVARCHAR(255)   NULL,

    -- NEW values
    NewLevel1       NVARCHAR(255)   NULL,
    NewLevel1Key    INT            NULL,
    NewLevel2       NVARCHAR(255)   NULL,
    NewLevel2Key    INT            NULL,
    NewLevel3       NVARCHAR(255)   NULL,
    NewLevel3Key    INT            NULL,
    NewLevel4       NVARCHAR(255)   NULL,
    NewLevel4Key    INT            NULL,
    NewLevel5       NVARCHAR(255)   NULL,
    NewLevel5Key    INT            NULL,
    NewOrganization NVARCHAR(255)   NULL
);
GO

CREATE INDEX IX_PeopleSoft_Dept_Org_Levels_Audit_RunId
ON dbo.PeopleSoft_Dept_Org_Levels_Audit(RunId, ActionType);
GO
