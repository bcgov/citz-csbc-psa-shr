-- adhoc__dropped_records_review.sql
-- Review all dropped records from the TIP Dropped staging table.
SET NOCOUNT ON;

SELECT
    DropReason,
    LoadDtmUtc,
    EmployeeId,
    Position,
    EntryDate,
    EntrySeq,
    Organization,
    Level1,
    DeptId,
    ClassificationGroupAtEntry
FROM dbo.Stg_Peoplesoft_TIP_Dropped
ORDER BY LoadDtmUtc DESC, DropReason;
