<#
.SYNOPSIS
Force delete files or folders by taking ownership, granting full control, then deleting.

.DESCRIPTION
This script forcefully deletes locked files or folders. It will:
0. Check for and close processes that are locking the target file/folder
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
Version: 1.2
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path
)

#region Helper function to execute external commands and handle output
function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$SuccessMessage,
        [string]$WarningMessage,
        [string]$ErrorMessage
    )

    $cmdString = "$FilePath $Arguments"
    Write-Host "=== Executing command ===" -ForegroundColor Cyan
    Write-Host "Command: $cmdString" -ForegroundColor Gray

    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru

    Write-Host "=== Command completed ===" -ForegroundColor Cyan
    Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Gray

    if ($process.ExitCode -eq 0) {
        Write-Host $SuccessMessage -ForegroundColor Green
    } else {
        Write-Host "$WarningMessage Exit code: $($process.ExitCode)" -ForegroundColor Yellow
    }
}

#region Check admin rights
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "=== Script Execution ===" -ForegroundColor Cyan
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting script as administrator..." -ForegroundColor Yellow

    $scriptPath = $MyInvocation.MyCommand.Path
    Write-Host "Script path: $scriptPath" -ForegroundColor Gray
    Write-Host "Target path: $Path" -ForegroundColor Gray
    Write-Host "Arguments to pass: -File `"$scriptPath`" `"$Path`"" -ForegroundColor Gray

    $arguments = "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "`"$Path`""
    $startProcessParams = @{
        FilePath     = "powershell"
        Verb         = "RunAs"
        ArgumentList = $arguments
        Wait         = $true
        PassThru     = $true
    }

    try {
        $process = Start-Process @startProcessParams
        Write-Host "Elevated process completed with exit code: $($process.ExitCode)" -ForegroundColor Gray
        exit $process.ExitCode
    } catch {
        Write-Host "Error: Failed to restart as administrator - $_" -ForegroundColor Red
        Write-Host "Please try running the script as administrator manually." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "=== Force Delete Script Starting (Elevated) ===" -ForegroundColor Cyan
Write-Host "Running as: $(whoami)" -ForegroundColor Gray
Write-Host "Current directory: $PWD" -ForegroundColor Gray

#region Validate target path
Write-Host "`n=== Path Validation ===" -ForegroundColor Cyan
if (-not (Test-Path $Path)) {
    Write-Host "Error: Path '$Path' does not exist." -ForegroundColor Red
    Write-Host "Script exiting..." -ForegroundColor Yellow
    exit 1
}

$item = Get-Item $Path -ErrorAction SilentlyContinue
if ($null -eq $item) {
    Write-Host "Error: Cannot access path '$Path'." -ForegroundColor Red
    Write-Host "Script exiting..." -ForegroundColor Yellow
    exit 1
}

$isDirectory = $item.PSIsContainer
$TargetPath = $item.FullName

Write-Host "Target: $TargetPath" -ForegroundColor Green
Write-Host "Type: $(if ($isDirectory) { 'Directory' } else { 'File' })" -ForegroundColor Green
Write-Host "Attributes: $($item.Attributes)" -ForegroundColor Gray
if ($isDirectory) {
    $fileCount = (Get-ChildItem -Path $TargetPath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Total files/folders: $fileCount" -ForegroundColor Gray
}

#region Function: Close locking processes
function Close-LockingProcesses {
    param(
        [string]$TargetPath,
        [bool]$IsDirectory
    )

    Write-Host "`nStep 0: Checking for and closing processes locking the target..." -ForegroundColor Yellow

    try {
        $lockedFiles = @()

        if ($IsDirectory) {
            $files = Get-ChildItem -Path $TargetPath -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            $lockedFiles += $TargetPath
            $lockedFiles += $files
        } else {
            $lockedFiles += $TargetPath
        }

        $processesToClose = @{}

        foreach ($file in $lockedFiles) {
            if ([string]::IsNullOrWhiteSpace($file)) { continue }
            if (-not (Test-Path $file)) { continue }

            try {
                $fileStream = [System.IO.File]::Open($file, 'Open', 'ReadWrite', 'None')
                if ($fileStream) {
                    $fileStream.Close()
                }
            } catch [System.IO.IOException] {
                $wmiQuery = "ASSOCIATORS OF {Win32_LogicalFileAccess.Path='$file'} WHERE AssocClass=Win32_ProcessAccessedFile"

                try {
                    $lockingProcesses = Get-WmiObject -Query $wmiQuery -ErrorAction SilentlyContinue
                    foreach ($proc in $lockingProcesses) {
                        $procId = $proc.Handle
                        if (-not $processesToClose.ContainsKey($procId)) {
                            try {
                                $process = Get-Process -Id $procId -ErrorAction SilentlyContinue
                                if ($process) {
                                    $processesToClose[$procId] = $process
                                    Write-Host "Found locking process: $($process.ProcessName) (PID: $procId)" -ForegroundColor Magenta
                                }
                            } catch {
                                Write-Host "Found locking process PID: $procId (name could not be retrieved)" -ForegroundColor Magenta
                            }
                        }
                    }
                } catch {
                }
            } catch {
            }
        }

        if ($processesToClose.Count -eq 0) {
            $handlePath = Get-Command "handle.exe" -ErrorAction SilentlyContinue
            if ($handlePath) {
                Write-Host "Trying handle.exe to find locking processes..." -ForegroundColor Cyan
                try {
                    $handleOutput = & $handlePath.Path -accepteula "$TargetPath" 2>&1
                    foreach ($line in $handleOutput) {
                        if ($line -match 'pid: (\d+)\s+(\S+)') {
                            $procId = $matches[1]
                            $procName = $matches[2]
                            if (-not $processesToClose.ContainsKey($procId)) {
                                try {
                                    $process = Get-Process -Id $procId -ErrorAction SilentlyContinue
                                    if ($process) {
                                        $processesToClose[$procId] = $process
                                        Write-Host "Found locking process via handle.exe: $procName (PID: $procId)" -ForegroundColor Magenta
                                    }
                                } catch {
                                    Write-Host "Found locking process via handle.exe PID: $procId (name: $procName)" -ForegroundColor Magenta
                                }
                            }
                        }
                    }
                } catch {
                    Write-Host "handle.exe execution failed: $_" -ForegroundColor Yellow
                }
            }
        }

        if ($processesToClose.Count -eq 0) {
            Write-Host "No locking processes found." -ForegroundColor Green
            return
        }

        Write-Host "`nFound $($processesToClose.Count) process(es) locking the target." -ForegroundColor Yellow
        Write-Host "WARNING: Closing these processes may cause unsaved data to be lost!" -ForegroundColor Red

        $confirmation = Read-Host "Do you want to close these processes? (Y/N)"
        if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
            Write-Host "Skipping process closure. Continuing with deletion attempt..." -ForegroundColor Yellow
            return
        }

        foreach ($proc in $processesToClose.Values) {
            try {
                Write-Host "Closing process: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan

                $proc.CloseMainWindow() | Out-Null
                Start-Sleep -Milliseconds 500

                if (-not $proc.HasExited) {
                    Write-Host "Process did not close gracefully, forcing termination..." -ForegroundColor Yellow
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    Start-Sleep -Milliseconds 200
                }

                if ($proc.HasExited) {
                    Write-Host "Process closed successfully." -ForegroundColor Green
                } else {
                    Write-Host "Warning: Process may still be running." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error closing process $($proc.ProcessName) (PID: $($proc.Id)): $_" -ForegroundColor Red
            }
        }

        Write-Host "`nWaiting for processes to fully terminate..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2

    } catch {
        Write-Host "Warning: Error while checking for locking processes: $_" -ForegroundColor Yellow
        Write-Host "Continuing with deletion attempt..." -ForegroundColor Yellow
    }
}

Close-LockingProcesses -TargetPath $TargetPath -IsDirectory $isDirectory

#region Step 1: Take ownership
Write-Host "`nStep 1: Taking ownership..." -ForegroundColor Yellow

$success = $false
$maxRetries = 2
$retryCount = 0

while ($retryCount -lt $maxRetries -and -not $success) {
    $retryCount++
    Write-Host "`n=== Take ownership attempt $retryCount of $maxRetries ===" -ForegroundColor Cyan

    try {
        if ($isDirectory) {
            $takeownArgs = @("/f", "`"$TargetPath`"", "/r", "/d", "y")
        } else {
            $takeownArgs = @("/f", "`"$TargetPath`"")
        }

        Write-Host "Executing takeown with parameters: $takeownArgs"

        $takeownOutput = takeown @takeownArgs 2>&1
        Write-Host $takeownOutput -ForegroundColor Gray

        Write-Host "Ownership taken successfully." -ForegroundColor Green

        # Verify ownership was actually taken
        Write-Host "`n=== Verifying ownership ===" -ForegroundColor Cyan
        try {
            $acl = Get-Acl -Path $TargetPath
            $owner = $acl.Owner
            Write-Host "Current owner: $owner" -ForegroundColor Gray

            if ($owner -like "*\Administrators" -or $owner -like "Administrators\*" -or $owner -like "*Administrators" -or $owner -like "*\$env:USERNAME" -or $owner -eq $env:USERNAME) {
                Write-Host "✓ Ownership transferred to administrators or current user" -ForegroundColor Green
                $success = $true

                if ($isDirectory) {
                    Write-Host "`nChecking random file ownership inside directory..." -ForegroundColor Gray
                    $randomFile = Get-ChildItem -Path $TargetPath -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($randomFile) {
                        $randomFileAcl = Get-Acl -Path $randomFile.FullName
                        $randomOwner = $randomFileAcl.Owner
                        Write-Host "Random file owner: $randomOwner" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "✗ Owner still not in expected group: $owner" -ForegroundColor Red
                $success = $false
            }
        } catch {
            Write-Host "Error checking ownership: $_" -ForegroundColor Red
            $success = $false
        }

        if (-not $success -and $retryCount -lt $maxRetries) {
            Write-Host "Retrying ownership transfer in 1 second..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    } catch {
        Write-Host "Error executing takeown: $_" -ForegroundColor Red
        $success = $false

        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying ownership transfer in 1 second..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

if (-not $success) {
    Write-Host "`n❌ Failed to take ownership after $maxRetries attempts" -ForegroundColor Red
    Write-Host "Aborting deletion" -ForegroundColor Yellow
    exit 1
}

#region Step 2: Grant permissions
Write-Host "`nStep 2: Granting full control permissions..." -ForegroundColor Yellow

$success = $false
$maxRetries = 2
$retryCount = 0

while ($retryCount -lt $maxRetries -and -not $success) {
    $retryCount++
    Write-Host "`n=== Permission grant attempt $retryCount of $maxRetries ===" -ForegroundColor Cyan

    try {
        if ($isDirectory) {
            $icaclsArgs = @("`"$TargetPath`"", "/grant", "Everyone:(OI)(CI)F", "/T", "/C")
        } else {
            $icaclsArgs = @("`"$TargetPath`"", "/grant", "Everyone:F", "/C")
        }

        Write-Host "Executing icacls with parameters: $icaclsArgs"

        $icaclsOutput = icacls @icaclsArgs 2>&1
        Write-Host $icaclsOutput -ForegroundColor Gray

        Write-Host "Permissions granted successfully." -ForegroundColor Green

        # Verify permissions were actually set
        Write-Host "`n=== Verifying permissions ===" -ForegroundColor Cyan
        $permOutput = icacls `"$TargetPath`" 2>&1
        $hasEveryonePerm = $permOutput -match "Everyone.*\(F\)"

        if ($hasEveryonePerm) {
            Write-Host "✓ Everyone has full control permissions" -ForegroundColor Green
            $success = $true

            if ($isDirectory) {
                Write-Host "`nChecking random file permissions inside directory..." -ForegroundColor Gray
                $randomFile = Get-ChildItem -Path $TargetPath -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($randomFile) {
                    $randomFilePerm = icacls `"$($randomFile.FullName)`" 2>&1
                    $hasFilePerm = $randomFilePerm -match "Everyone.*\(F\)"
                    if ($hasFilePerm) {
                        Write-Host "✓ Random file has Everyone permissions" -ForegroundColor Green
                    } else {
                        Write-Host "✗ Random file does not have Everyone permissions" -ForegroundColor Red
                        $success = $false
                    }
                }
            }
        } else {
            Write-Host "✗ Everyone does NOT have full control permissions" -ForegroundColor Red
            $success = $false
        }

        if (-not $success -and $retryCount -lt $maxRetries) {
            Write-Host "Retrying permissions grant in 1 second..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    } catch {
        Write-Host "Error executing icacls: $_" -ForegroundColor Red
        $success = $false

        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying permissions grant in 1 second..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

if (-not $success) {
    Write-Host "`n❌ Failed to grant permissions after $maxRetries attempts" -ForegroundColor Red
    Write-Host "Aborting deletion" -ForegroundColor Yellow
    exit 1
}

#region Step 3: Delete target
Write-Host "`nStep 3: Deleting target..." -ForegroundColor Yellow

$maxRetries = 3
$retryCount = 0
$deleteSuccess = $false

while ($retryCount -lt $maxRetries -and -not $deleteSuccess) {
    $retryCount++
    Write-Host "`n=== Delete attempt $retryCount of $maxRetries ===" -ForegroundColor Cyan

    try {
        if ($isDirectory) {
            Write-Host "Deleting folder: $TargetPath" -ForegroundColor Magenta

            if (Test-Path $TargetPath) {
                Remove-Item -Path $TargetPath -Recurse -Force -ErrorAction Stop
            } else {
                Write-Host "Folder already no longer exists" -ForegroundColor Gray
            }
        } else {
            Write-Host "Deleting file: $TargetPath" -ForegroundColor Magenta

            if (Test-Path $TargetPath) {
                Remove-Item -Path $TargetPath -Force -ErrorAction Stop
            } else {
                Write-Host "File already no longer exists" -ForegroundColor Gray
            }
        }

        Start-Sleep -Milliseconds 500

        if (-not (Test-Path $TargetPath)) {
            Write-Host "Delete successful." -ForegroundColor Green
            $deleteSuccess = $true
        } else {
            Write-Host "Warning: Target still exists after delete attempt" -ForegroundColor Yellow

            if ($retryCount -lt $maxRetries) {
                Write-Host "Waiting 2 seconds before retry..." -ForegroundColor Gray
                Start-Sleep -Seconds 2
            }
        }
    } catch {
        Write-Host "Error: Delete failed - $_" -ForegroundColor Red

        if ($retryCount -lt $maxRetries) {
            Write-Host "Waiting 2 seconds before retry..." -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $deleteSuccess) {
    Write-Host "`n=== Delete failed after $maxRetries attempts ===" -ForegroundColor Red
    Write-Host "Final check - Target still exists: $(Test-Path $TargetPath)" -ForegroundColor Red

    if (Test-Path $TargetPath) {
        Write-Host "`n=== Additional diagnostics ===" -ForegroundColor Yellow
        Write-Host "Checking file attributes..." -ForegroundColor Gray
        try {
            $remainingItem = Get-Item $TargetPath -Force -ErrorAction SilentlyContinue
            if ($remainingItem) {
                Write-Host "Item attributes: $($remainingItem.Attributes)" -ForegroundColor Gray
                Write-Host "Item exists: $($remainingItem.Exists)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "Failed to get item details: $_" -ForegroundColor Gray
        }

        Write-Host "`nChecking for locked files..." -ForegroundColor Gray
        try {
            if ($isDirectory) {
                $lockedFiles = @()
                $testFiles = Get-ChildItem -Path $TargetPath -Recurse -ErrorAction SilentlyContinue
                foreach ($testFile in $testFiles) {
                    try {
                        $testStream = [System.IO.File]::Open($testFile.FullName, 'Open', 'ReadWrite', 'None')
                        if ($testStream) { $testStream.Close() }
                    } catch [System.IO.IOException] {
                        $lockedFiles += $testFile.FullName
                        Write-Host "Locked file found: $($testFile.FullName)" -ForegroundColor Magenta
                    } catch {
                    }
                }

                if ($lockedFiles.Count -eq 0) {
                    Write-Host "No locked files detected" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "Error checking for locked files: $_" -ForegroundColor Gray
        }
    }

    exit 1
}

Write-Host "`n=== Script Execution Complete ===" -ForegroundColor Cyan
Write-Host "Target has been successfully deleted." -ForegroundColor Green
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
