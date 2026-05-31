CREATE TABLE dbo.PeopleSoft_Dept_Org_Levels
(
    DepartmentID      VARCHAR(20)   NOT NULL,

    Level1            NVARCHAR(255) NULL,
    Level1Key         INT           NULL,

    Level2            NVARCHAR(255) NULL,
    Level2Key         INT           NULL,

    Level3            NVARCHAR(255) NULL,
    Level3Key         INT           NULL,

    Level4            NVARCHAR(255) NULL,
    Level4Key         INT           NULL,

    Level5            NVARCHAR(255) NULL,
    Level5Key         INT           NULL,

    Organization      NVARCHAR(255) NULL,

    -- Soft delete flag
    IsActive          BIT           NOT NULL
        CONSTRAINT DF_PeopleSoft_Dept_Org_Levels_IsActive DEFAULT (1),

    -- Operational traceability
    CreatedUtc        DATETIME2(0)  NOT NULL
        CONSTRAINT DF_PeopleSoft_Dept_Org_Levels_CreatedUtc DEFAULT SYSUTCDATETIME(),
    LastUpdatedUtc    DATETIME2(0)  NOT NULL
        CONSTRAINT DF_PeopleSoft_Dept_Org_Levels_LastUpdatedUtc DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_PeopleSoft_Dept_Org_Levels PRIMARY KEY (DepartmentID)
);
GO

-- Helpful index for consumers filtering active rows
CREATE INDEX IX_PeopleSoft_Dept_Org_Levels_IsActive
ON dbo.PeopleSoft_Dept_Org_Levels(IsActive)
INCLUDE (Organization, Level1, Level2, Level3, Level4, Level5);
GO