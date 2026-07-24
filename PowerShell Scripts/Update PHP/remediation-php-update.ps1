<#
.SYNOPSIS
    Intune Proactive Remediation - REMEDIATION script - deletes orphaned XAMPP
    php_backup_<timestamp> folders (both C:\xampp and per-user-profile installs).

.DESCRIPTION
    Only removes folders matching the exact pattern "php_backup_<digits>" directly
    under an "xampp" directory. Does not touch the live "php" folder, does not
    touch anything under Downloads, and does not touch any other folder naming.
    Triggers an Intune + Defender sync afterward so the cleared finding refreshes
    sooner.
#>

$ErrorActionPreference = 'Stop'
$LogFile = "C:\ProgramData\IntuneLogs\PHP-BackupCleanup-Remediate.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

try {
    $searchParents = @("C:\xampp")
    $searchParents += Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "xampp" } |
        Where-Object { Test-Path $_ }

    $foundBackups = @()
    foreach ($parent in $searchParents) {
        if (Test-Path $parent) {
            $backups = Get-ChildItem -Path $parent -Directory -Filter "php_backup_*" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^php_backup_\d+$' }
            foreach ($b in $backups) { $foundBackups += $b.FullName }
        }
    }

    if ($foundBackups.Count -eq 0) {
        Write-Log "No orphaned backup folders found. Nothing to do."
        Write-Host "Nothing to clean up"
        exit 0
    }

    $deleted = @()
    $failed = @()
    foreach ($folder in $foundBackups) {
        try {
            Remove-Item -Path $folder -Recurse -Force
            Write-Log "Deleted: $folder"
            $deleted += $folder
        }
        catch {
            Write-Log "FAILED to delete ${folder}: $($_.Exception.Message)"
            $failed += $folder
        }
    }

    if ($failed.Count -gt 0) {
        throw "Deleted $($deleted.Count) of $($foundBackups.Count) folder(s); $($failed.Count) failed (see log for details)"
    }

    Write-Log "SUCCESS: removed $($deleted.Count) orphaned backup folder(s)"

    # --- Trigger Intune + Defender sync so the cleared finding refreshes sooner ---
    try {
        $syncTask = Get-ScheduledTask -TaskName "PushLaunch" -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskPath -like "*EnterpriseMgmt*" } | Select-Object -First 1
        if ($syncTask) {
            Start-ScheduledTask -TaskPath $syncTask.TaskPath -TaskName $syncTask.TaskName
            Write-Log "Triggered Intune sync"
        }
    }
    catch { Write-Log "WARNING: Intune sync trigger failed - $($_.Exception.Message)" }

    try {
        $senseService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
        if ($senseService) {
            Restart-Service -Name "Sense" -Force -ErrorAction SilentlyContinue
            Write-Log "Restarted Sense service"
        }
    }
    catch { Write-Log "WARNING: Sense service restart failed - $($_.Exception.Message)" }

    Write-Host "Removed $($deleted.Count) orphaned XAMPP backup folder(s)"
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Remediation failed: $($_.Exception.Message)"
    exit 1
}