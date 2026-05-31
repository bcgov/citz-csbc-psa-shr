-- adhoc__dropped_records_review.sql
-- Review all dropped records from the Dropped staging table.
SET NOCOUNT ON;

SELECT
    DropReason,
    LoadDtmUtc,
    EmplId,
    EffDt,
    EffSeq,
    EmplRcd,
    MoveType,
    CompChange,
    NewDeptId,
    NewOrganization
FROM dbo.Stg_Peoplesoft_HEM_Dropped
ORDER BY LoadDtmUtc DESC, DropReason;
