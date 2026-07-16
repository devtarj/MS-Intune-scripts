<#
.SYNOPSIS
    Intune Proactive Remediation - Detection Script
    Checks whether the highest installed Python version matches the latest
    stable release published on python.org. Runs as SYSTEM.

    Does NOT use winget - source registration is unreliable under the SYSTEM
    account. Instead reads installed versions from the registry and checks
    the latest version via the public endoflife.date API.

.EXIT CODES
    0 = Compliant (Python installed and up to date)
    1 = Non-compliant (missing, outdated, or unable to verify) -> triggers remediation
#>

$logPath = "C:\ProgramData\IntuneLogs\PythonVersionCheck.log"
New-Item -Path (Split-Path $logPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logPath -Append -Encoding utf8
}

try {
    Write-Log "=== Detection started (registry + python.org method) ==="
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Installed version(s) via Uninstall registry keys ---
    # InstallAllUsers=1 installs register under HKLM, which is what we check for
    # and what the remediation script also uses - so detection and remediation agree.
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $fullVersions = @()
    foreach ($path in $uninstallPaths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match '^Python 3\.\d+\.\d+' } |
            ForEach-Object {
                if ($_.DisplayVersion -match '^\d+\.\d+\.\d+') {
                    $fullVersions += $_.DisplayVersion
                }
            }
    }

    Write-Log "Full installed versions found: $($fullVersions -join ', ')"

    if ($fullVersions.Count -eq 0) {
        Write-Log "Python not found via registry."
        Write-Output "Python not installed"
        exit 1
    }

    $installedVersion = ($fullVersions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
    Write-Log "Highest installed Python version: $installedVersion"

    # --- Latest available stable version via endoflife.date API ---
    try {
        $releases = Invoke-RestMethod -Uri "https://endoflife.date/api/python.json" -UseBasicParsing -TimeoutSec 30
    }
    catch {
        Write-Log "ERROR: Failed to query endoflife.date API: $($_.Exception.Message)"
        Write-Output "Unable to reach version API"
        exit 1
    }

    $stableLatest = $releases |
        Where-Object { $_.latest -match '^\d+\.\d+\.\d+$' } |
        ForEach-Object { [version]$_.latest } |
        Sort-Object -Descending |
        Select-Object -First 1

    if (-not $stableLatest) {
        Write-Log "ERROR: Could not parse latest version from API response."
        Write-Output "Unable to determine latest version"
        exit 1
    }

    $latestVersion = $stableLatest.ToString()
    Write-Log "Latest available stable Python version: $latestVersion"

    # --- Compare ---
    if ([version]$installedVersion -lt [version]$latestVersion) {
        Write-Log "Update required: $installedVersion -> $latestVersion"
        Write-Output "Update required: $installedVersion -> $latestVersion"
        exit 1
    }
    else {
        Write-Log "Python is up to date."
        Write-Output "Python is up to date ($installedVersion)"
        exit 0
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Output "Detection error: $($_.Exception.Message)"
    exit 1
}