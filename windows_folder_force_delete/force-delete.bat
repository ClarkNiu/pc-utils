@echo off
REM Force delete script wrapper
REM Usage: force-delete.bat "path"

setlocal

if "%~1"=="" (
    echo Error: Please specify file or folder path to delete.
    echo Usage: %~nx0 "path"
    echo Example: %~nx0 "C:\test\locked_folder"
    pause
    exit /b 1
)

set "TARGET_PATH=%~1"

REM Check if path exists
if not exist "%TARGET_PATH%" (
    echo Error: Path "%TARGET_PATH%" does not exist.
    pause
    exit /b 1
)

echo ========================================
echo Force Delete Script
echo Target: %TARGET_PATH%
echo ========================================
echo.

REM Get current script directory
set "SCRIPT_DIR=%~dp0"

REM Call PowerShell script
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%force-delete.ps1" "%TARGET_PATH%"

echo.
pause