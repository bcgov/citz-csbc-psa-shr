@echo off
REM ============================================================================
REM Task Scheduler wrapper for copy-api-data-to-sqp.R (Dept_Org_Levels ETL)
REM
REM Uses absolute paths and --vanilla so the script behaves identically whether
REM launched by Task Scheduler (cwd = system32) or from a console.
REM Captures stdout + stderr + exit code + timestamps to a per-script log.
REM ============================================================================
setlocal

set BASEDIR=E:\Projects\citz-shr-psa
set LOGDIR=%BASEDIR%\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

set LOGFILE=%LOGDIR%\psa_dept_org_levels_etl.log

echo =================================================== > "%LOGFILE%"
echo Task started: %DATE% %TIME% >> "%LOGFILE%"
echo Running as: %USERNAME% >> "%LOGFILE%"
echo =================================================== >> "%LOGFILE%"

"E:\R\R-4.4.3\bin\Rscript.exe" --vanilla "%BASEDIR%\citz-shr-psa-r\copy-api-data-to-sqp.R" >> "%LOGFILE%" 2>&1

echo. >> "%LOGFILE%"
echo Exit code: %ERRORLEVEL% >> "%LOGFILE%"
echo Task finished: %DATE% %TIME% >> "%LOGFILE%"

exit /b %ERRORLEVEL%
