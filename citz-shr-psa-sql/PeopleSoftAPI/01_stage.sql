CREATE TABLE dbo.Stg_Peoplesoft_Dept_Org_Levels
(
    DepartmentID     VARCHAR(20)  NOT NULL,

    Level1           NVARCHAR(255) NULL,
    Level1Key        INT           NULL,

    Level2           NVARCHAR(255) NULL,
    Level2Key        INT           NULL,

    Level3           NVARCHAR(255) NULL,
    Level3Key        INT           NULL,

    Level4           NVARCHAR(255) NULL,
    Level4Key        INT           NULL,

    Level5           NVARCHAR(255) NULL,
    Level5Key        INT           NULL,

    Organization     NVARCHAR(255) NULL,

    CONSTRAINT PK_Stg_Peoplesoft_Dept_Org_Levels
        PRIMARY KEY (DepartmentID)
);
GOs