-- adhoc__dropped_records_by_org.sql
-- Dropped records grouped by organisation and drop reason.
SET NOCOUNT ON;

SELECT
    DropReason,
    CAST(LoadDtmUtc AS DATE)    AS LoadDate,
    Organization,
    Level1,
    DeptId,
    ClassificationGroupAtEntry,
    COUNT(*)                     AS DroppedCount
FROM dbo.Stg_Peoplesoft_TIP_Dropped
GROUP BY
    DropReason,
    CAST(LoadDtmUtc AS DATE),
    Organization,
    Level1,
    DeptId,
    ClassificationGroupAtEntry
ORDER BY LoadDate DESC, DroppedCount DESC;
