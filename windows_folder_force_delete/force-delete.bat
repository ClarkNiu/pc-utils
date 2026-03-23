@echo off
REM Force delete script wrapper
REM Usage: force-delete.bat ["path"]

setlocal

echo ========================================
echo Force Delete Script - Batch Wrapper
echo ========================================
echo.

REM Check if path is provided as argument, otherwise prompt user
if "%~1"=="" (
    echo Please enter the folder path to delete:
    set /p "TARGET_PATH="
) else (
    set "TARGET_PATH=%~1"
)

echo.
echo Target path: "%TARGET_PATH%"
echo.

REM Validate that target path was provided
if "%TARGET_PATH%"=="" (
    echo Error: Path cannot be empty.
    echo.
    pause
    exit /b 1
)

REM Get current script directory
set "SCRIPT_DIR=%~dp0"
echo Script directory: "%SCRIPT_DIR%"

REM Check if PowerShell script exists
if not exist "%SCRIPT_DIR%force-delete.ps1" (
    echo Error: PowerShell script not found: "%SCRIPT_DIR%force-delete.ps1"
    echo.
    pause
    exit /b 1
)

echo.
echo Launching PowerShell script...
echo ========================================
echo.

REM Call PowerShell script with unrestricted execution policy
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; & '%SCRIPT_DIR%force-delete.ps1' '%TARGET_PATH%'}"

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo ========================================
echo PowerShell script finished with exit code: %EXIT_CODE%
echo.

if %EXIT_CODE% EQU 0 (
    echo Operation completed successfully.
) else (
    echo Operation may have failed. Check above output for details.
)

echo.
pause
