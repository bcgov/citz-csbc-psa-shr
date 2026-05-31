-- adhoc__dropped_records_by_org.sql
-- Dropped records grouped by organisation and reason.
-- Use to identify if a specific org/dept is repeatedly producing bad records.
SET NOCOUNT ON;

SELECT
    DropReason,
    CAST(LoadDtmUtc AS DATE)    AS LoadDate,
    NewOrganization,
    NewDeptId,
    NewDeptIdDescr,
    MoveType,
    COUNT(*)                     AS DroppedCount
FROM dbo.Stg_Peoplesoft_HEM_Dropped
GROUP BY
    DropReason,
    CAST(LoadDtmUtc AS DATE),
    NewOrganization,
    NewDeptId,
    NewDeptIdDescr,
    MoveType
ORDER BY LoadDate DESC, DroppedCount DESC;
