-- =============================================================================
-- DELETE corrupted EPC audit rows
-- =============================================================================
-- Root cause: 04_merge_proc.sql INTO column list was interleaved (Old1,New1,...)
--             but OUTPUT clause was sequential (all Olds, then all News).
--             SQL Server maps by position — every value was written to the wrong
--             column. All audit rows from the first two runs are corrupted.
--
-- Evidence:
--   OldCreateEffDt = 'YES'          (should be a date; received OldEmptyPosition)
--   NewCreateEffDt = 'Included'     (should be a date; received OldExcludedOrIncluded)
--   NewEmptyEffDt  = 'Monk,Deborah M' (should be a date; received OldLastIncumbents)
--   OldJobReqOpenDate = '00075546'  (should be a date; received OldReportsTo)
--
-- Fix applied: ddl/04_merge_proc.sql INTO clause rewritten to sequential order
--              matching the OUTPUT clause on <date of fix>.
--
-- Affected runs (all rows in Peoplesoft_EPC_Audit are corrupted):
--   RunId 1132CFF2-F530-49D8-A04D-B2DE166D7353  (2026-06-01 load, 3859 INSERTs)
--   RunId 29ED0179-43F6-4455-AB1C-89BB4C23165D  (2026-06-02 load, 1231 UPDATEs)
--
-- ACTION: Run the DELETE below, then re-execute the MERGE proc after the next
--         R ETL staging load to regenerate clean audit records.
-- =============================================================================

-- Preview first (comment out DELETE, uncomment SELECT)
-- SELECT COUNT(*) AS RowsToDelete FROM dbo.Peoplesoft_EPC_Audit;

DELETE FROM dbo.Peoplesoft_EPC_Audit
WHERE RunId IN (
    '1132CFF2-F530-49D8-A04D-B2DE166D7353',  -- 2026-06-01: 3859 corrupted INSERTs
    '29ED0179-43F6-4455-AB1C-89BB4C23165D'   -- 2026-06-02: 1231 corrupted UPDATEs
);

-- Verify table is now empty (expected: 0 rows until next clean MERGE run)
SELECT COUNT(*) AS RemainingRows FROM dbo.Peoplesoft_EPC_Audit;
