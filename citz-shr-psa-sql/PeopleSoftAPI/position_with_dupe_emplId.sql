-- Check if ANY column differs between the duplicate pairs
SELECT
    *
FROM dbo.Stg_Peoplesoft_SO001HRORG
WHERE PosPosition IN ('00099991', '00099992', '00099993', '00099994')
ORDER BY PosPosition, EmplId;