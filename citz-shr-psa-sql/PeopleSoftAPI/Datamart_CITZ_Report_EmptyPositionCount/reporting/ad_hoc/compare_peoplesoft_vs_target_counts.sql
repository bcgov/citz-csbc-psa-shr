-- compare_peoplesoft_vs_target_counts.sql
-- Compare staging row count vs target row count after the most recent ETL run.

SELECT
    'Staging (Stg_Peoplesoft_EPC)'     AS TableName,
    COUNT(*)                            AS RowCount
FROM dbo.Stg_Peoplesoft_EPC

UNION ALL

SELECT
    'Target (Peoplesoft_EPC) - Active'  AS TableName,
    COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive = 1

UNION ALL

SELECT
    'Target (Peoplesoft_EPC) - All'     AS TableName,
    COUNT(*)
FROM dbo.Peoplesoft_EPC;
