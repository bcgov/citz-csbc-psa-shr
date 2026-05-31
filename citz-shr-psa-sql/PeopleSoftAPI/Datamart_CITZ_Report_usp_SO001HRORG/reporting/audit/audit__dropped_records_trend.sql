/*=============================================================================
File:    audit__dropped_records_trend.sql
Purpose: Daily trend of dropped ETL records by DropReason.
         Reveals whether upstream data quality issues are improving or
         accumulating over time.

DropReason values:
  'NULL_POSPOSITION'         — PosPosition was NULL/blank in the API response.
  'DUPLICATE_COMPOSITE_KEY'  — Duplicate on (PosPosition, EmplId); caused by
                               FutureTermReason reporting artifact.

Usage:   Run for ongoing monitoring of upstream API data quality over time.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    CAST(LoadDtmUtc AS DATE)  AS AuditDate,
    DropReason,
    COUNT(*)                  AS DroppedRowCount
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
GROUP BY
    CAST(LoadDtmUtc AS DATE),
    DropReason
ORDER BY
    AuditDate DESC,
    DropReason;
