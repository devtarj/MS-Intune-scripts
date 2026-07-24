<#
.SYNOPSIS
    Intune Proactive Remediation - DETECTION script for orphaned XAMPP php_backup_*
    folders. These are leftovers from manual PHP swaps (rename old "php" folder to
    "php_backup_<timestamp>", drop in a new one) - they aren't live/serving anything,
    but they still contain old php.exe binaries that Defender will keep flagging as
    vulnerable until removed.

.DESCRIPTION
    Scope is intentionally narrow: only folders directly under an "xampp" directory
    matching the pattern "php_backup_<digits>" - both system-wide (C:\xampp\...) and
    per-user-profile (C:\Users\<user>\xampp\...) installs are covered. This does NOT
    touch anything under Downloads or other locations - only confirmed dead backup
    folders are in scope.

    Exit 0 = compliant (no orphaned backup folders found).
    Exit 1 = non-compliant, triggers remediation.
#>

$ErrorActionPreference = 'Stop'
$LogFile = "C:\ProgramData\IntuneLogs\PHP-BackupCleanup-Detect.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

try {
    # Search both the system-wide XAMPP location and every user profile's XAMPP location.
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
        Write-Log "No orphaned php_backup_* folders found. Compliant."
        Write-Host "No orphaned XAMPP backup folders found"
        exit 0
    }
    else {
        foreach ($f in $foundBackups) { Write-Log "Found orphaned backup folder: $f" }
        Write-Host "Found $($foundBackups.Count) orphaned XAMPP backup folder(s)"
        exit 1
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Detection error: $($_.Exception.Message)"
    exit 1
}