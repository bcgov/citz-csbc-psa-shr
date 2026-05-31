-- tip__dropped_records_trend.sql
-- Daily dropped record counts by reason; monitors data quality over time.
SET NOCOUNT ON;

SELECT
    CAST(d.LoadDtmUtc AS DATE)    AS LoadDate,
    d.DropReason,
    COUNT(*)                       AS DroppedCount
FROM dbo.Stg_Peoplesoft_TIP_Dropped d
GROUP BY CAST(d.LoadDtmUtc AS DATE), d.DropReason
ORDER BY LoadDate DESC, DroppedCount DESC;
