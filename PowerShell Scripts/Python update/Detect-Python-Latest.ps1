<#
.SYNOPSIS
    Intune Proactive Remediation - DETECTION script for Python.

.DESCRIPTION
    Compares installed Python version(s) on this device against the latest
    stable release published on python.org.

    Exit 0 = compliant (single, latest Python version installed)
    Exit 1 = non-compliant (Python missing, outdated, or multiple versions found)
             -> triggers the paired remediation script.

    Deploy this as the "Detection script" in an Intune Remediation, running
    in SYSTEM context, 64-bit PowerShell.
#>

$ErrorActionPreference = 'SilentlyContinue'

function Get-LatestPythonRelease {
    try {
        $uri = "https://www.python.org/api/v2/downloads/release/?is_published=true&pre_release=false"
        $releases = Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 30
        $stable = $releases | Where-Object { $_.name -match '^Python (\d+\.\d+\.\d+)$' }
        $sorted = $stable | Sort-Object { [version]($_.name -replace '^Python ', '') } -Descending
        return [version]($sorted[0].name -replace '^Python ', '')
    }
    catch {
        return $null
    }
}

function Get-InstalledPythonVersions {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '^Python \d+\.\d+\.\d+' }

    $versions = foreach ($a in $apps) {
        if ($a.DisplayName -match '^Python (\d+\.\d+\.\d+)') {
            try { [version]$Matches[1] } catch {}
        }
    }
    return $versions | Sort-Object -Unique
}

$latest    = Get-LatestPythonRelease
$installed = Get-InstalledPythonVersions

if (-not $latest) {
    # Couldn't reach python.org / parse response - don't force a remediation loop on a transient network issue
    Write-Output "Could not determine latest Python version from python.org. Skipping this run."
    exit 0
}

if (-not $installed -or $installed.Count -eq 0) {
    Write-Output "Python is not installed. Remediation required."
    exit 1
}

if ($installed.Count -gt 1) {
    Write-Output "Multiple Python versions detected: $($installed -join ', '). Remediation required."
    exit 1
}

if ($installed[0] -lt $latest) {
    Write-Output "Installed Python $($installed[0]) is older than latest available $latest. Remediation required."
    exit 1
}

Write-Output "Python $($installed[0]) is up to date (latest available: $latest)."
exit 0
