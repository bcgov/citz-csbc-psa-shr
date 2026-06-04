@echo off
setlocal

set BASEDIR=E:\Projects\citz-shr-psa
set LOGDIR=%BASEDIR%\logs
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

set LOGFILE=%LOGDIR%\psa_time_in_position_etl.log

echo =================================================== > "%LOGFILE%"
echo Task started: %DATE% %TIME% >> "%LOGFILE%"
echo Running as: %USERNAME% >> "%LOGFILE%"
echo =================================================== >> "%LOGFILE%"

"E:\R\R-4.4.3\bin\Rscript.exe" --vanilla "%BASEDIR%\citz-shr-psa-r\psa_time_in_position_etl.R" >> "%LOGFILE%" 2>&1

echo. >> "%LOGFILE%"
echo Exit code: %ERRORLEVEL% >> "%LOGFILE%"
echo Task finished: %DATE% %TIME% >> "%LOGFILE%"

exit /b %ERRORLEVEL%
