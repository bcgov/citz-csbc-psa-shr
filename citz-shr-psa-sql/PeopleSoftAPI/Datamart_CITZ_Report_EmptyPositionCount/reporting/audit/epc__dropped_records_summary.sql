-- epc__dropped_records_summary.sql
-- Summary of dropped records (protective null-key captures) across all ETL runs.

SELECT
    CAST(d.LoadDtmUtc AS DATE)                      AS DropDate,
    d.DropReason,
    COUNT(*)                                        AS DroppedCount
FROM dbo.Stg_Peoplesoft_EPC_Dropped AS d
GROUP BY
    CAST(d.LoadDtmUtc AS DATE),
    d.DropReason
ORDER BY DropDate DESC, d.DropReason;
