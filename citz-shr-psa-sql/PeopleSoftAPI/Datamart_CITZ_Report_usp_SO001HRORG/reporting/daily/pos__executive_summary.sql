/*=============================================================================
File:    pos__executive_summary.sql
Purpose: Single-query executive summary of SO001HRORG pipeline health.
         Four result sets covering current state, latest run activity,
         data quality, and trend indicators.

Usage:   Run after each ETL execution for a complete operational snapshot.
=============================================================================*/

SET NOCOUNT ON;

-- ============================================================
-- Section 1: Current State Snapshot
-- Active positions, fill rate, vacant count.
-- ============================================================
SELECT
    'Current State'                                                AS Section,
    COUNT(*)                                                       AS TotalActivePositions,
    SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)                 AS FilledPositions,
    SUM(CASE WHEN EmplId = '' THEN 1 ELSE 0 END)                  AS VacantPositions,
    CAST(
        100.0 * SUM(CASE WHEN EmplId <> '' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
    AS DECIMAL(5,1))                                               AS FillRatePct,
    SUM(CASE WHEN IsActive = 0 THEN 1 ELSE 0 END)                 AS SoftDeletedPositions,
    COUNT(DISTINCT Organization)                                   AS DistinctOrganizations,
    COUNT(DISTINCT Level1)                                         AS DistinctLevel1s
FROM dbo.Peoplesoft_SO001HRORG;


-- ============================================================
-- Section 2: Latest Run Activity
-- Change counts from the most recent ETL execution.
-- ============================================================
;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
)
SELECT
    'Latest Run Activity'                                          AS Section,
    a.RunId,
    MIN(a.AuditDtmUtc)                                            AS RunTimestampUtc,
    SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
    SUM(CASE WHEN a.ActionType = 'UPDATE'      THEN 1 ELSE 0 END) AS Updates,
    SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
    SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations,
    COUNT(*)                                                       AS TotalChanges
FROM dbo.Peoplesoft_SO001HRORG_Audit a
JOIN latest_run lr ON a.RunId = lr.RunId
GROUP BY a.RunId;


-- ============================================================
-- Section 3: Data Quality
-- Dropped records (NULL_POSPOSITION and DUPLICATE_COMPOSITE_KEY)
-- from the most recent load day.
-- ============================================================
;WITH latest_drop_day AS
(
    SELECT MAX(CAST(LoadDtmUtc AS DATE)) AS DropDate
    FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
)
SELECT
    'Data Quality'                        AS Section,
    d.DropDate,
    dr.DropReason,
    COUNT(*)                              AS DroppedRowCount
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped dr
CROSS JOIN latest_drop_day d
WHERE CAST(dr.LoadDtmUtc AS DATE) = d.DropDate
GROUP BY d.DropDate, dr.DropReason
ORDER BY dr.DropReason;


-- ============================================================
-- Section 4: Trend Indicators
-- Net position change from latest run and vacancy shift.
-- Latest run: Inserts - SoftDeletes + Reactivations = net active change.
-- Incumbent turnover: UPDATEs where EmplId changed.
-- ============================================================
;WITH latest_run AS
(
    SELECT MAX(RunId) AS RunId
    FROM dbo.Peoplesoft_SO001HRORG_Audit
),
run_activity AS
(
    SELECT
        SUM(CASE WHEN a.ActionType = 'INSERT'      THEN 1 ELSE 0 END) AS Inserts,
        SUM(CASE WHEN a.ActionType = 'SOFT_DELETE' THEN 1 ELSE 0 END) AS SoftDeletes,
        SUM(CASE WHEN a.ActionType = 'REACTIVATE'  THEN 1 ELSE 0 END) AS Reactivations,
        -- Incumbent change: an UPDATE where EmplId value changed
        SUM(
            CASE WHEN a.ActionType = 'UPDATE'
                      AND ISNULL(a.OldEmplId,'') <> ISNULL(a.NewEmplId,'')
                 THEN 1 ELSE 0 END
        )                                                              AS IncumbentChanges
    FROM dbo.Peoplesoft_SO001HRORG_Audit a
    JOIN latest_run lr ON a.RunId = lr.RunId
)
SELECT
    'Trend Indicators'                             AS Section,
    ra.Inserts - ra.SoftDeletes + ra.Reactivations AS NetActivePositionChange,
    ra.Inserts                                     AS NewPositions,
    ra.SoftDeletes                                 AS RemovedPositions,
    ra.Reactivations                               AS ReactivatedPositions,
    ra.IncumbentChanges                            AS IncumbentChanges
FROM run_activity ra;
