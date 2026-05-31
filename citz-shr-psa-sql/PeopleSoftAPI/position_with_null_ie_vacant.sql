SELECT
    PosPosition,
    ISNULL(EmplId, '__VACANT__') AS SafeEmplId,
    EmplId,
    Name,
    Status,
    Type,
    Appt,
    TAStatus,
    EmplStatus,
    EmplBU,
    EmplDeptId
FROM dbo.Stg_Peoplesoft_SO001HRORG
WHERE CONCAT(PosPosition, '|', ISNULL(EmplId, '__VACANT__'))
IN (
    SELECT CONCAT(PosPosition, '|', ISNULL(EmplId, '__VACANT__'))
    FROM dbo.Stg_Peoplesoft_SO001HRORG
    GROUP BY CONCAT(PosPosition, '|', ISNULL(EmplId, '__VACANT__'))
    HAVING COUNT(*) > 1
)
ORDER BY PosPosition, EmplId;