@echo off
:: Check for administrative privileges
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo This script requires administrative privileges.
    echo Right click on the file and select "Run As Administrator"
    pause
    exit /b
)

:: Get the directory the batch file is located in
SET "scriptdir=%~dp0"

:: Derive the PowerShell script name from the batch file name
SET "PS_SCRIPT_NAME=%~n0.ps1"

:: Debug: Print the script being executed
echo Executing PowerShell script: "%PS_SCRIPT_NAME%"

:: Change to that directory
cd /d "%scriptdir%"

:: Debug: Print the current working directory
echo Current working directory: "%cd%"

:: Run the PowerShell script with admin privileges
call :RunPowerShellScript "%PS_SCRIPT_NAME%"

if %errorlevel% equ 0 pause

goto :eof

:RunPowerShellScript
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "PowerShell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0%~1\"
if %errorlevel% neq 0 goto :ErrorHandler

echo.
echo PowerShell script executed successfully.
goto :eof

:ErrorHandler
echo There was an error. We stop here.
pause
exit /b %errorlevel%

:eof
