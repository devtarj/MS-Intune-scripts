<#
.SYNOPSIS
    Intune Proactive Remediation - REMEDIATION script for PHP (Windows builds).

.DESCRIPTION
    Downloads and installs the latest available PHP build for the currently
    installed major.minor branch (or $TargetBranch if set) from the official
    windows.php.net release listing, matching the existing install's
    thread-safety (TS/NTS) and architecture. php.ini is preserved.

.NOTES
    Runs in SYSTEM context by default in Intune Proactive Remediations.
    Exit 0 = success / nothing to do. Exit 1 = failure.
#>

$ErrorActionPreference = 'Stop'

# ---- Config -------------------------------------------------------------
# Leave $null to match the currently-installed major.minor branch (safe default).
# Set e.g. "8.4" to force an update to a specific branch instead.
$TargetBranch = $null

$SearchRoots = @(
    "C:\php",
    "C:\Program Files\PHP",
    "C:\Program Files (x86)\PHP",
    "C:\tools\php"
)

# Windows services to stop/start around the file copy so locked DLLs/exe don't
# block the update. W3SVC (IIS) is safe to include by default - IIS respawns
# php-cgi.exe workers on demand. If PHP runs as an in-process Apache module,
# ADD YOUR APACHE SERVICE NAME HERE (e.g. "Apache2.4") or the module DLL may
# stay locked and the copy step below will fail.
$WebServerServicesToRestart = @("W3SVC")

$LogFile   = "C:\ProgramData\IntuneLogs\PHP-Remediate.log"
$BackupRoot = "C:\ProgramData\IntuneLogs\PHP-Backups"
# ---------------------------------------------------------------------------

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- 1. Locate php.exe ---------------------------------------------------
    $phpExe = $null
    foreach ($root in $SearchRoots) {
        if (Test-Path $root) {
            $found = cmd /c "dir /b /s `"$root\php.exe`" 2>nul"
            if ($found) {
                $phpExe = ($found -split "`r`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
                if ($phpExe) { break }
            }
        }
    }
    if (-not $phpExe) {
        $whereResult = cmd /c "where php.exe 2>nul"
        if ($whereResult) {
            $phpExe = ($whereResult -split "`r`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
        }
    }

    if (-not $phpExe -or -not (Test-Path $phpExe)) {
        Write-Log "PHP not found on this device. Nothing to remediate (this script updates existing installs only)."
        Write-Host "PHP not found"
        exit 0
    }

    $installDir = Split-Path $phpExe -Parent
    Write-Log "PHP found at $phpExe (install dir: $installDir)"

    # --- 2. Installed version / thread safety / architecture -----------------
    $verOutput = & $phpExe -v 2>$null
    if ($verOutput -notmatch 'PHP\s+(\d+\.\d+\.\d+)') { throw "Could not parse installed PHP version" }
    $installedVersion = $Matches[1]

    $infoOutput = & $phpExe -i 2>$null
    $isThreadSafe = ($infoOutput -match 'Thread Safety\s*=>\s*enabled')
    $arch = 'x64'
    if ($infoOutput -match 'Architecture\s*=>\s*(x\d+)') { $arch = $Matches[1] }

    $branch = if ($TargetBranch) { $TargetBranch } else { ($installedVersion -split '\.')[0..1] -join '.' }
    Write-Log "Installed: $installedVersion | Branch: $branch | $(if ($isThreadSafe) {'TS'} else {'NTS'}) | $arch"

    # --- 3. Find latest matching build on windows.php.net ---------------------
    $releasesUrl = "https://windows.php.net/downloads/releases/"
    $html = (New-Object System.Net.WebClient).DownloadString($releasesUrl)

    $ntsTag = if ($isThreadSafe) { '' } else { '-nts' }
    $branchEscaped = [regex]::Escape($branch)
    $pattern = "php-$branchEscaped\.\d+$ntsTag-Win32-(?:vc|vs)\d+-$arch\.zip"
    $found = [regex]::Matches($html, $pattern) | ForEach-Object { $_.Value } | Select-Object -Unique

    if (-not $found -or $found.Count -eq 0) {
        throw "No matching Windows build found for branch $branch (arch=$arch, nts=$(-not $isThreadSafe))"
    }

    $downloadFile = $found | Sort-Object {
        [version]([regex]::Match($_, '\d+\.\d+\.\d+').Value)
    } -Descending | Select-Object -First 1

    $latestVersion = [regex]::Match($downloadFile, '\d+\.\d+\.\d+').Value
    Write-Log "Latest available build: $downloadFile ($latestVersion)"

    if ([version]$installedVersion -ge [version]$latestVersion) {
        Write-Log "Already up to date ($installedVersion). No action taken."
        Write-Host "PHP already up to date ($installedVersion)"
        exit 0
    }

    Write-Log "Updating PHP: $installedVersion -> $latestVersion"

    # --- 4. Download -----------------------------------------------------------
    $downloadUrl = "$releasesUrl$downloadFile"
    $zipPath = Join-Path "C:\Windows\Temp" $downloadFile
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $zipPath)

    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -lt 1MB) {
        throw "Downloaded file missing or too small ($zipPath) - download likely failed"
    }
    Write-Log "Downloaded $downloadUrl to $zipPath"

    # --- 5. Backup php.ini (zip distributions don't ship a real php.ini, only
    #        templates, so this is a safety net rather than a real conflict) ---
    $backupDir = Join-Path $BackupRoot "$installedVersion-to-$latestVersion-$(Get-Date -Format yyyyMMddHHmmss)"
    New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    $phpIniPath = Join-Path $installDir "php.ini"
    if (Test-Path $phpIniPath) {
        Copy-Item $phpIniPath (Join-Path $backupDir "php.ini") -Force
        Write-Log "Backed up php.ini to $backupDir"
    }

    # --- 6. Stop web server / PHP processes so files aren't locked -------------
    foreach ($svc in $WebServerServicesToRestart) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Log "Stopping service $svc"
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
    }
    Get-Process -Name "php-cgi", "php" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    # --- 7. Extract and copy over the existing install (php.ini excluded) ------
    $extractTemp = Join-Path "C:\Windows\Temp" "php-extract-$latestVersion"
    if (Test-Path $extractTemp) { Remove-Item $extractTemp -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractTemp -Force

    Copy-Item -Path (Join-Path $extractTemp '*') -Destination $installDir -Recurse -Force -Exclude "php.ini"
    Write-Log "Copied new build into $installDir"

    if ((Test-Path (Join-Path $backupDir "php.ini")) -and -not (Test-Path $phpIniPath)) {
        Copy-Item (Join-Path $backupDir "php.ini") $phpIniPath -Force
        Write-Log "Restored php.ini (was missing after copy)"
    }

    # --- 8. Restart web server services -----------------------------------------
    foreach ($svc in $WebServerServicesToRestart) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Starting service $svc"
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
    }

    # --- 9. Cleanup ---------------------------------------------------------------
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractTemp -Recurse -Force -ErrorAction SilentlyContinue

    # --- 10. Verify ----------------------------------------------------------------
    $newVerOutput = & $phpExe -v 2>$null
    $newVersion = $null
    if ($newVerOutput -match 'PHP\s+(\d+\.\d+\.\d+)') { $newVersion = $Matches[1] }
    Write-Log "Post-update version reported: $newVersion"

    if ($newVersion -and ([version]$newVersion -ge [version]$latestVersion)) {
        Write-Log "SUCCESS: PHP updated to $newVersion"
        Write-Host "PHP updated to $newVersion"
        exit 0
    }
    else {
        throw "Post-update verification failed - php.exe reports '$newVersion', expected '$latestVersion'"
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Remediation failed: $($_.Exception.Message)"
    exit 1
}