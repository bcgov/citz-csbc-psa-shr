-- adhoc__dropped_records_by_org.sql
-- Dropped records summarized by organizational unit and drop reason.
-- Use to determine whether data-quality issues are concentrated in
-- specific departments or ministry areas.

SELECT
    ISNULL(d.Level1,   '(Unknown)')   AS Level1,
    ISNULL(d.Level2,   '(Unknown)')   AS Level2,
    ISNULL(d.DeptDescr,'(Unknown)')   AS DeptDescr,
    d.DropReason,
    COUNT(*)                          AS DroppedCount,
    MIN(d.LoadDtmUtc)                 AS FirstSeen,
    MAX(d.LoadDtmUtc)                 AS LastSeen
FROM dbo.Stg_Peoplesoft_SHR010HRORG_Dropped d
GROUP BY
    d.Level1,
    d.Level2,
    d.DeptDescr,
    d.DropReason
ORDER BY
    DroppedCount DESC,
    d.Level1,
    d.Level2,
    d.DeptDescr;
