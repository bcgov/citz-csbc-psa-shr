SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================================
-- Procedure : dbo.usp_Merge_PeopleSoft_SHR010HRORG
-- Purpose   : UPSERT + soft delete + audit
-- Fix       : Excludes Age / AgeGroup* from change detection (derived columns)
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_Merge_PeopleSoft_SHR010HRORG
(
      @Force                 BIT = 0
    , @MinPctOfTarget        DECIMAL(5,2) = 0.80
    , @MaxPctOfTarget        DECIMAL(5,2) = 1.20
    , @MaxSoftDeletePct      DECIMAL(5,2) = 0.10
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RunId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StgCnt INT, @TgtCnt INT;

    SELECT @StgCnt = COUNT(*) FROM dbo.Stg_Peoplesoft_SHR010HRORG;
    SELECT @TgtCnt = COUNT(*) FROM dbo.Peoplesoft_SHR010HRORG;

    ------------------------------------------------------------------------
    -- Guardrails
    ------------------------------------------------------------------------
    IF (@StgCnt = 0 AND @Force = 0)
        THROW 51000, 'MERGE aborted: staging empty.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Stg_Peoplesoft_SHR010HRORG WHERE EmplId IS NULL OR EmplId = '')
        THROW 51001, 'MERGE aborted: NULL EmplId.', 1;

    IF (@TgtCnt > 0 AND @Force = 0)
    BEGIN
        IF (@StgCnt < CEILING(@TgtCnt * @MinPctOfTarget)
            OR @StgCnt > CEILING(@TgtCnt * @MaxPctOfTarget))
        BEGIN
            THROW 51002, 'MERGE aborted: rowcount variance.', 1;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        --------------------------------------------------------------------
        -- MERGE
        --------------------------------------------------------------------
        MERGE dbo.Peoplesoft_SHR010HRORG WITH (HOLDLOCK) tgt
        USING dbo.Stg_Peoplesoft_SHR010HRORG src
            ON tgt.EmplId = src.EmplId

        WHEN MATCHED AND (
               tgt.IsActive = 0

            -- ✅ identity
            OR ISNULL(tgt.Name,'')       <> ISNULL(src.Name,'')
            OR ISNULL(tgt.Idir,'')       <> ISNULL(src.Idir,'')
            OR ISNULL(tgt.EmailId,'')    <> ISNULL(src.EmailId,'')
            OR ISNULL(tgt.EmplStatus,'') <> ISNULL(src.EmplStatus,'')
            OR ISNULL(tgt.EmplType,'')   <> ISNULL(src.EmplType,'')

            -- ✅ org
            OR ISNULL(tgt.Organization,'') <> ISNULL(src.Organization,'')
            OR ISNULL(tgt.DeptId,'')       <> ISNULL(src.DeptId,'')
            OR ISNULL(tgt.Level1,'')       <> ISNULL(src.Level1,'')

            -- ✅ job
            OR ISNULL(tgt.JobCode,'')      <> ISNULL(src.JobCode,'')
            OR ISNULL(tgt.JobFunction,'')  <> ISNULL(src.JobFunction,'')

            -- ✅ numeric
            OR ISNULL(tgt.AnnualRt,-1) <> ISNULL(src.AnnualRt,-1)
            OR ISNULL(tgt.CompRate,-1) <> ISNULL(src.CompRate,-1)

            -- ✅ dates
            OR ISNULL(tgt.HireDt,'1900-01-01') <> ISNULL(src.HireDt,'1900-01-01')

            -- ✅ NOTE: Age / AgeGroup1 / AgeGroup2 REMOVED ✅
        )

        THEN UPDATE SET

            Name        = src.Name,
            Idir        = src.Idir,
            EmailId     = src.EmailId,
            EmplStatus  = src.EmplStatus,
            EmplType    = src.EmplType,

            Organization = src.Organization,
            DeptId       = src.DeptId,
            Level1       = src.Level1,

            JobCode     = src.JobCode,
            JobFunction = src.JobFunction,

            AnnualRt = src.AnnualRt,
            CompRate = src.CompRate,

            HireDt = src.HireDt,

            -- ✅ KEEP THESE (just not in change detection)
            Age        = src.Age,
            AgeGroup1  = src.AgeGroup1,
            AgeGroup2  = src.AgeGroup2,

            IsActive = 1,
            LastUpdatedUtc = SYSUTCDATETIME()

        WHEN NOT MATCHED BY TARGET
        THEN INSERT (
            EmplId,
            Name, Idir, EmailId,
            EmplStatus, EmplType,
            Organization, DeptId, Level1,
            JobCode, JobFunction,
            AnnualRt, CompRate,
            HireDt,
            Age, AgeGroup1, AgeGroup2,
            IsActive, CreatedUtc, LastUpdatedUtc
        )
        VALUES (
            src.EmplId,
            src.Name, src.Idir, src.EmailId,
            src.EmplStatus, src.EmplType,
            src.Organization, src.DeptId, src.Level1,
            src.JobCode, src.JobFunction,
            src.AnnualRt, src.CompRate,
            src.HireDt,
            src.Age, src.AgeGroup1, src.AgeGroup2,
            1, SYSUTCDATETIME(), SYSUTCDATETIME()
        )

        WHEN NOT MATCHED BY SOURCE AND tgt.IsActive = 1
        THEN UPDATE SET
            IsActive = 0,
            LastUpdatedUtc = SYSUTCDATETIME();

        COMMIT;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
