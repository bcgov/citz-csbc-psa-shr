/*=============================================================================
File:    adhoc__dropped_records_by_org.sql
Purpose: Break down dropped ETL records by Organization and DropReason.
         Useful for identifying which organizations have the most upstream
         data quality issues (NULL PosPosition or duplicate composite keys).

DropReason values:
  'NULL_POSPOSITION'         — PosPosition was NULL/blank in the API response.
  'DUPLICATE_COMPOSITE_KEY'  — Duplicate on (PosPosition, EmplId); caused by
                               FutureTermReason reporting artifact.

Usage:   Run ad hoc to investigate upstream data issues by organization.
=============================================================================*/

SET NOCOUNT ON;

SELECT
    ISNULL(Organization, '<NULL>')  AS Organization,
    DropReason,
    COUNT(*)                        AS DroppedRowCount,
    MIN(LoadDtmUtc)                 AS FirstSeenUtc,
    MAX(LoadDtmUtc)                 AS LastSeenUtc
FROM dbo.Stg_Peoplesoft_SO001HRORG_Dropped
GROUP BY
    Organization,
    DropReason
ORDER BY
    DroppedRowCount DESC,
    Organization,
    DropReason;
