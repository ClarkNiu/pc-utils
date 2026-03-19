<#
.SYNOPSIS
Force delete files or folders by taking ownership, granting full control, then deleting.

.DESCRIPTION
This script forcefully deletes locked files or folders. It will:
1. Use takeown command to take ownership of file/folder
2. Use icacls command to grant full control to all users
3. Use Remove-Item to force delete

Script requires administrator privileges.

.PARAMETER Path
Path to the file or folder to delete.

.EXAMPLE
.\force-delete.ps1 -Path "C:\test\locked_folder"
.\force-delete.ps1 -Path "C:\test\locked_file.txt"

.NOTES
Author: Auto-generated script
Version: 1.1
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path
)

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting script as administrator..." -ForegroundColor Yellow

    # Restart as administrator
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-File `"$scriptPath`" `"$Path`""

    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Write-Host "=== Force Delete Script Starting ===" -ForegroundColor Cyan

# Check if path exists
if (-not (Test-Path $Path)) {
    Write-Host "Error: Path '$Path' does not exist." -ForegroundColor Red
    exit 1
}

# Get path type (file or folder)
$item = Get-Item $Path -ErrorAction SilentlyContinue
if ($null -eq $item) {
    Write-Host "Error: Cannot access path '$Path'." -ForegroundColor Red
    exit 1
}

$isDirectory = $item.PSIsContainer
Write-Host "Target: $($item.FullName)" -ForegroundColor Green
if ($isDirectory) {
    Write-Host "Type: Directory" -ForegroundColor Green
} else {
    Write-Host "Type: File" -ForegroundColor Green
}

# Step 1: Take ownership
Write-Host "`nStep 1: Taking ownership..." -ForegroundColor Yellow
try {
    if ($isDirectory) {
        # For directories, use /r recursive, /d y suppress directory prompts
        $takeownArgs = @("/f", "`"$($item.FullName)`"", "/r", "/d", "y")
    } else {
        # For files, don't use /r
        $takeownArgs = @("/f", "`"$($item.FullName)`"")
    }

    Write-Host "Executing: takeown $takeownArgs"
    $process = Start-Process -FilePath "takeown" -ArgumentList $takeownArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Host "Ownership taken successfully." -ForegroundColor Green
    } else {
        Write-Host "Warning: takeown returned exit code $($process.ExitCode), may not have fully succeeded." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: Failed to execute takeown: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Grant full control permissions
Write-Host "`nStep 2: Granting full control permissions..." -ForegroundColor Yellow
try {
    if ($isDirectory) {
        # For directories, use /T recursive, /C continue on errors, /Q quiet mode
        # (OI) - Object Inherit, (CI) - Container Inherit, F - Full control
        $icaclsArgs = @("`"$($item.FullName)`"", "/grant", "Everyone:(OI)(CI)F", "/T", "/C", "/Q")
    } else {
        # For files, don't use /T
        $icaclsArgs = @("`"$($item.FullName)`"", "/grant", "Everyone:F", "/C", "/Q")
    }

    Write-Host "Executing: icacls $icaclsArgs"
    $process = Start-Process -FilePath "icacls" -ArgumentList $icaclsArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Host "Permissions granted successfully." -ForegroundColor Green
    } else {
        Write-Host "Warning: icacls returned exit code $($process.ExitCode), may not have fully succeeded." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: Failed to execute icacls: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Delete file or folder
Write-Host "`nStep 3: Deleting target..." -ForegroundColor Yellow
try {
    if ($isDirectory) {
        Write-Host "Deleting folder: $($item.FullName)" -ForegroundColor Magenta
        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
    } else {
        Write-Host "Deleting file: $($item.FullName)" -ForegroundColor Magenta
        Remove-Item -Path $item.FullName -Force -ErrorAction Stop
    }

    Write-Host "Delete successful." -ForegroundColor Green
} catch {
    Write-Host "Error: Delete failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Script Execution Complete ===" -ForegroundColor Cyan
Write-Host "Target has been successfully deleted." -ForegroundColor Green