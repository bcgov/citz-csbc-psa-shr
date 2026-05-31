SELECT
    'pos_position alone' AS Test,
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT PosPosition) AS DistinctKeys,
    COUNT(*) - COUNT(DISTINCT PosPosition) AS Duplicates
FROM dbo.Stg_Peoplesoft_SO001HRORG

UNION ALL

SELECT
    'pos_position + emplid (NULL-safe)',
    COUNT(*),
    COUNT(DISTINCT CONCAT(PosPosition, '|', ISNULL(EmplId, '__VACANT__'))),
    COUNT(*) - COUNT(DISTINCT CONCAT(PosPosition, '|', ISNULL(EmplId, '__VACANT__')))
FROM dbo.Stg_Peoplesoft_SO001HRORG

UNION ALL

SELECT
    'pos_position + emplid + type',
    COUNT(*),
    COUNT(DISTINCT CONCAT(PosPosition, '|', ISNULL(EmplId, ''), '|', ISNULL(Type, ''))),
    COUNT(*) - COUNT(DISTINCT CONCAT(PosPosition, '|', ISNULL(EmplId, ''), '|', ISNULL(Type, '')))
FROM dbo.Stg_Peoplesoft_SO001HRORG;