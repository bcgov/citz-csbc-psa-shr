-- adhoc__dropped_records_review.sql
-- Sample all dropped records from the quality log, most recent first.
-- Use to investigate data anomalies captured by the R ETL before staging.

SELECT TOP 100
    d.LoadDtmUtc,
    d.DropReason,
    d.EmplId,
    d.Name,
    d.EmplStatus,
    d.DeptDescr,
    d.Level1,
    d.Level2,
    d.AsOfDate
FROM dbo.Stg_Peoplesoft_SHR010HRORG_Dropped d
ORDER BY d.LoadDtmUtc DESC;
