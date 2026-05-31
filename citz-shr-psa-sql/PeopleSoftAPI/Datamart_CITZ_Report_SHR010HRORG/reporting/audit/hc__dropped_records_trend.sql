-- hc__dropped_records_trend.sql
-- Dropped records by load date and reason.
-- Tracks data quality events captured by the R ETL before staging load.
-- Current DropReason values: 'NULL_EMPLID'

SELECT
    CAST(d.LoadDtmUtc AS DATE)   AS LoadDate,
    d.DropReason,
    COUNT(*)                     AS DroppedCount
FROM dbo.Stg_Peoplesoft_SHR010HRORG_Dropped d
GROUP BY
    CAST(d.LoadDtmUtc AS DATE),
    d.DropReason
ORDER BY
    LoadDate DESC,
    d.DropReason;
