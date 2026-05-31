-- Check if ANY column differs between the duplicate pairs
SELECT
    *
FROM dbo.Stg_Peoplesoft_SO001HRORG
WHERE PosPosition IN ('00046542', '00089046', '00099642', '00116666')
ORDER BY PosPosition, EmplId;