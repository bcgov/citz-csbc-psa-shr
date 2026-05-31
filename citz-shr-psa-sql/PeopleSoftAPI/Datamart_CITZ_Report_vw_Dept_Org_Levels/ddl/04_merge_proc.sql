SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.usp_Merge_PeopleSoft_Dept_Org_Levels
(
      @Force                 BIT = 0
    , @MinPctOfTarget        DECIMAL(5,2) = 0.80  -- staging must be at least 80% of target
    , @MaxPctOfTarget        DECIMAL(5,2) = 1.20  -- staging must be at most 120% of target
    , @MaxSoftDeletePct      DECIMAL(5,2) = 0.10  -- max 10% of target allowed to be soft-deleted per run
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StgCnt INT, @TgtCnt INT;

    -- Row counts
    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_Dept_Org_Levels;
    SELECT @TgtCnt = COUNT(*) FROM dbo.PeopleSoft_Dept_Org_Levels;

    ------------------------------------------------------------------------
    -- Guardrail 0: staging must not be empty unless forced
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging table is empty (possible API failure). Use @Force=1 to override.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 0b: business key must not be NULL
    ------------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM dbo.Stg_Peoplesoft_Dept_Org_Levels WHERE DepartmentID IS NULL)
        THROW 51001, 'MERGE aborted: staging contains NULL DepartmentID.', 1;

    ------------------------------------------------------------------------
    -- Guardrail 1: rowcount variance (skip on first ever load)
    ------------------------------------------------------------------------
    IF (@TgtCnt > 0 AND @Force = 0)
    BEGIN
        IF (@StgCnt < CEILING(@TgtCnt * @MinPctOfTarget) OR @StgCnt > CEILING(@TgtCnt * @MaxPctOfTarget))
        BEGIN
            DECLARE @msg NVARCHAR(4000) =
                CONCAT('MERGE aborted: rowcount variance out of bounds. Staging=', @StgCnt,
                       ', Target=', @TgtCnt,
                       ', Bounds=[', @MinPctOfTarget, 'x..', @MaxPctOfTarget, 'x]. Use @Force=1 to override.');
            THROW 51002, @msg, 1;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        --------------------------------------------------------------------
        -- Guardrail 2: preview soft deletes (how many ACTIVE target rows are missing from source)
        --------------------------------------------------------------------
        DECLARE @WouldSoftDelete INT = 0;

        IF (@TgtCnt > 0)
        BEGIN
            SELECT @WouldSoftDelete = COUNT(*)
            FROM dbo.PeopleSoft_Dept_Org_Levels tgt
            LEFT JOIN dbo.Stg_Peoplesoft_Dept_Org_Levels src
                ON src.DepartmentID = tgt.DepartmentID
            WHERE src.DepartmentID IS NULL
              AND tgt.IsActive = 1;
        END

        IF (@TgtCnt > 0 AND @Force = 0)
        BEGIN
            IF (@WouldSoftDelete > CEILING(@TgtCnt * @MaxSoftDeletePct))
            BEGIN
                DECLARE @msg2 NVARCHAR(4000) =
                    CONCAT('MERGE aborted: would soft-delete too many rows. WouldSoftDelete=', @WouldSoftDelete,
                           ', Target=', @TgtCnt,
                           ', MaxAllowed=', CEILING(@TgtCnt * @MaxSoftDeletePct),
                           ' (', @MaxSoftDeletePct, ' of target). Use @Force=1 to override.');
                THROW 51003, @msg2, 1;
            END
        END

        --------------------------------------------------------------------
        -- MERGE (UPSERT) + SOFT DELETE + AUDIT OUTPUT
        --------------------------------------------------------------------
        ;MERGE dbo.PeopleSoft_Dept_Org_Levels WITH (HOLDLOCK) AS tgt
        USING dbo.Stg_Peoplesoft_Dept_Org_Levels AS src
            ON tgt.DepartmentID = src.DepartmentID

        -- UPDATE or REACTIVATE (IsActive 0 -> 1) when matched and different
        WHEN MATCHED AND (
               tgt.IsActive = 0
            OR ISNULL(tgt.Level1, '')       <> ISNULL(src.Level1, '')
            OR ISNULL(tgt.Level1Key, -1)    <> ISNULL(src.Level1Key, -1)
            OR ISNULL(tgt.Level2, '')       <> ISNULL(src.Level2, '')
            OR ISNULL(tgt.Level2Key, -1)    <> ISNULL(src.Level2Key, -1)
            OR ISNULL(tgt.Level3, '')       <> ISNULL(src.Level3, '')
            OR ISNULL(tgt.Level3Key, -1)    <> ISNULL(src.Level3Key, -1)
            OR ISNULL(tgt.Level4, '')       <> ISNULL(src.Level4, '')
            OR ISNULL(tgt.Level4Key, -1)    <> ISNULL(src.Level4Key, -1)
            OR ISNULL(tgt.Level5, '')       <> ISNULL(src.Level5, '')
            OR ISNULL(tgt.Level5Key, -1)    <> ISNULL(src.Level5Key, -1)
            OR ISNULL(tgt.Organization, '') <> ISNULL(src.Organization, '')
        )
        THEN UPDATE SET
            Level1         = src.Level1,
            Level1Key      = src.Level1Key,
            Level2         = src.Level2,
            Level2Key      = src.Level2Key,
            Level3         = src.Level3,
            Level3Key      = src.Level3Key,
            Level4         = src.Level4,
            Level4Key      = src.Level4Key,
            Level5         = src.Level5,
            Level5Key      = src.Level5Key,
            Organization   = src.Organization,
            IsActive       = 1,
            LastUpdatedUtc = SYSUTCDATETIME()

        -- INSERT new
        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            DepartmentID,
            Level1, Level1Key,
            Level2, Level2Key,
            Level3, Level3Key,
            Level4, Level4Key,
            Level5, Level5Key,
            Organization,
            IsActive,
            CreatedUtc,
            LastUpdatedUtc
        )
        VALUES (
            src.DepartmentID,
            src.Level1, src.Level1Key,
            src.Level2, src.Level2Key,
            src.Level3, src.Level3Key,
            src.Level4, src.Level4Key,
            src.Level5, src.Level5Key,
            src.Organization,
            1,
            SYSUTCDATETIME(),
            SYSUTCDATETIME()
        )

        -- SOFT DELETE (missing from source): mark inactive
        WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
        THEN UPDATE SET
            IsActive       = 0,
            LastUpdatedUtc = SYSUTCDATETIME()

        OUTPUT
            @RunId AS RunId,
            CASE
                WHEN $action = 'UPDATE' AND deleted.IsActive = 1 AND inserted.IsActive = 0 THEN 'SOFT_DELETE'
                WHEN $action = 'UPDATE' AND deleted.IsActive = 0 AND inserted.IsActive = 1 THEN 'REACTIVATE'
                ELSE $action
            END AS ActionType,
            COALESCE(inserted.DepartmentID, deleted.DepartmentID) AS DepartmentID,

            HASHBYTES('SHA2_256', CONCAT_WS('|',
                deleted.DepartmentID,
                COALESCE(deleted.Level1,''), COALESCE(CONVERT(varchar(20),deleted.Level1Key),''),
                COALESCE(deleted.Level2,''), COALESCE(CONVERT(varchar(20),deleted.Level2Key),''),
                COALESCE(deleted.Level3,''), COALESCE(CONVERT(varchar(20),deleted.Level3Key),''),
                COALESCE(deleted.Level4,''), COALESCE(CONVERT(varchar(20),deleted.Level4Key),''),
                COALESCE(deleted.Level5,''), COALESCE(CONVERT(varchar(20),deleted.Level5Key),''),
                COALESCE(deleted.Organization,''),
                COALESCE(CONVERT(varchar(1),deleted.IsActive),'')
            )) AS OldRowHash,

            HASHBYTES('SHA2_256', CONCAT_WS('|',
                inserted.DepartmentID,
                COALESCE(inserted.Level1,''), COALESCE(CONVERT(varchar(20),inserted.Level1Key),''),
                COALESCE(inserted.Level2,''), COALESCE(CONVERT(varchar(20),inserted.Level2Key),''),
                COALESCE(inserted.Level3,''), COALESCE(CONVERT(varchar(20),inserted.Level3Key),''),
                COALESCE(inserted.Level4,''), COALESCE(CONVERT(varchar(20),inserted.Level4Key),''),
                COALESCE(inserted.Level5,''), COALESCE(CONVERT(varchar(20),inserted.Level5Key),''),
                COALESCE(inserted.Organization,''),
                COALESCE(CONVERT(varchar(1),inserted.IsActive),'')
            )) AS NewRowHash,

            deleted.IsActive  AS OldIsActive,
            inserted.IsActive AS NewIsActive,

            deleted.Level1         AS OldLevel1,
            deleted.Level1Key      AS OldLevel1Key,
            deleted.Level2         AS OldLevel2,
            deleted.Level2Key      AS OldLevel2Key,
            deleted.Level3         AS OldLevel3,
            deleted.Level3Key      AS OldLevel3Key,
            deleted.Level4         AS OldLevel4,
            deleted.Level4Key      AS OldLevel4Key,
            deleted.Level5         AS OldLevel5,
            deleted.Level5Key      AS OldLevel5Key,
            deleted.Organization   AS OldOrganization,

            inserted.Level1        AS NewLevel1,
            inserted.Level1Key     AS NewLevel1Key,
            inserted.Level2        AS NewLevel2,
            inserted.Level2Key     AS NewLevel2Key,
            inserted.Level3        AS NewLevel3,
            inserted.Level3Key     AS NewLevel3Key,
            inserted.Level4        AS NewLevel4,
            inserted.Level4Key     AS NewLevel4Key,
            inserted.Level5        AS NewLevel5,
            inserted.Level5Key     AS NewLevel5Key,
            inserted.Organization  AS NewOrganization

        INTO dbo.PeopleSoft_Dept_Org_Levels_Audit
        (
            RunId, ActionType, DepartmentID,
            OldRowHash, NewRowHash,
            OldIsActive, NewIsActive,
            OldLevel1, OldLevel1Key, OldLevel2, OldLevel2Key, OldLevel3, OldLevel3Key,
            OldLevel4, OldLevel4Key, OldLevel5, OldLevel5Key, OldOrganization,
            NewLevel1, NewLevel1Key, NewLevel2, NewLevel2Key, NewLevel3, NewLevel3Key,
            NewLevel4, NewLevel4Key, NewLevel5, NewLevel5Key, NewOrganization
        );

        COMMIT;

        -- Return a concise run summary (handy for R logging)
        SELECT
            @RunId AS RunId,
            @StgCnt AS StagingRows,
            @TgtCnt AS TargetRows_Before,
            @WouldSoftDelete AS WouldSoftDelete_Preview,
            (SELECT COUNT(*) FROM dbo.PeopleSoft_Dept_Org_Levels) AS TargetRows_After,
            (SELECT COUNT(*) FROM dbo.PeopleSoft_Dept_Org_Levels_Audit WHERE RunId = @RunId) AS AuditEvents;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO