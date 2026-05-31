/*=============================================================================
File:    adhoc__dropped_records_review.sql
Purpose: Review records excluded from the pipeline due to upstream API
         data anomalies — persisted to quality tracking table by the R ETL.

DropReason values:
  'NULL_POSPOSITION'         — PosPosition was NULL or blank in the API response.
  'DUPLICATE_COMPOSITE_KEY'  — Duplicate on (PosPosition, EmplId); caused by
                                FutureTermReason reporting artifact.
=============================================================================*/

SET NOCOUNT ON;

-- Summary by DropReason
SELECT
    DropReason,
    COUNT(*)         AS DroppedRowCount,
    MIN(LoadDtmUtc)  AS FirstSeenUtc,
    MAX(LoadDtmUtc)  AS LastSeenUtc,
    COUNT(DISTINCT CAST(LoadDtmUtc AS date)) AS DistinctRunDays
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
GROUP BY DropReason
ORDER BY DroppedRowCount DESC;

-- Recent dropped records (100 most recent)
SELECT TOP (100)
    DropReason,
    LoadDtmUtc,
    PosPosition,
    EmplId,
    Name,
    Title,
    Organization,
    FutureTermReason,  -- diagnostic for DUPLICATE_COMPOSITE_KEY rows
    Status
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
ORDER BY LoadDtmUtc DESC;
