/*=============================================================================
File:    audit__dropped_records_summary.sql
Purpose: Summarize dropped records captured during SO001HRORG ETL runs.
         Rows excluded from the main pipeline due to upstream API data anomalies
         are persisted to dbo.Stg_Peoplesoft_SO001HRORG_Dropped for transparency
         and SHR upstream data issue reporting.

DropReason values:
  'NULL_POSPOSITION'          — PosPosition was NULL or blank in the API response.
  'DUPLICATE_COMPOSITE_KEY'  — Duplicate on (PosPosition, EmplId) composite key;
                                caused by FutureTermReason reporting artifact.
=============================================================================*/

SET NOCOUNT ON;

-- Summary by DropReason
SELECT
    DropReason,
    COUNT(*)         AS DroppedRowCount,
    MIN(LoadDtmUtc)  AS FirstSeenUtc,
    MAX(LoadDtmUtc)  AS LastSeenUtc,
    COUNT(DISTINCT CAST(LoadDtmUtc AS DATE)) AS DistinctRunDays
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
GROUP BY DropReason
ORDER BY DroppedRowCount DESC;

-- Sample records (TOP 10 most recent per reason)
;WITH ranked AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY DropReason ORDER BY LoadDtmUtc DESC) AS rn
    FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
)
SELECT
    DropReason,
    LoadDtmUtc,
    PosPosition,
    EmplId,
    Name,
    Title,
    Organization,
    FutureTermReason,  -- key field for DUPLICATE_COMPOSITE_KEY diagnosis
    Status
FROM ranked
WHERE rn <= 10
ORDER BY DropReason, LoadDtmUtc DESC;
