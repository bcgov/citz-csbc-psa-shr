-- epc_data_quality_check.sql
-- Data quality checks: NULL key, unexpected values, referential spot checks.

-- 1. Should always be 0 after a clean ETL run
SELECT 'NULL Position in target' AS Check_Name, COUNT(*) AS FailCount
FROM dbo.Peoplesoft_EPC
WHERE Position IS NULL

UNION ALL

-- 2. Active positions with no PositionTitle (unexpected)
SELECT 'Active position missing PositionTitle', COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive = 1
  AND (PositionTitle IS NULL OR PositionTitle = '')

UNION ALL

-- 3. Active positions with EmptyPosition not in expected set
SELECT 'Invalid EmptyPosition value', COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive = 1
  AND EmptyPosition NOT IN ('YES', 'NO')

UNION ALL

-- 4. Active positions with PositionEmptyGt1Year not in expected set
SELECT 'Invalid PositionEmptyGt1Year value', COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive = 1
  AND PositionEmptyGt1Year NOT IN ('YES', 'NO')

UNION ALL

-- 5. YearsEmpty negative (data anomaly)
SELECT 'Negative YearsEmpty', COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive     = 1
  AND YearsEmpty   < 0

UNION ALL

-- 6. PositionEmptyGt1Year = YES but YearsEmpty < 1 (inconsistency)
SELECT 'PositionEmptyGt1Year=YES but YearsEmpty < 1', COUNT(*)
FROM dbo.Peoplesoft_EPC
WHERE IsActive              = 1
  AND PositionEmptyGt1Year  = 'YES'
  AND YearsEmpty            < 1;
