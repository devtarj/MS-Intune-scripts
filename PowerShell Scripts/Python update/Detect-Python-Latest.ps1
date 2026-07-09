<#
.SYNOPSIS
    Intune Proactive Remediation - DETECTION script for Python.

.DESCRIPTION
    Compares installed Python version(s) against latest stable release on python.org.

    Exit 0 = compliant  (one Python install, matches latest version)
    Exit 1 = non-compliant (triggers remediation)
#>

$ErrorActionPreference = 'SilentlyContinue'

# Force TLS 1.2 so SYSTEM account can reach python.org
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-LatestPythonRelease {
    try {
        $uri     = "https://www.python.org/api/v2/downloads/release/?is_published=true&pre_release=false&page_size=50"
        $releases = Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 30
        $stable  = $releases.results | Where-Object { $_.name -match '^Python (\d+\.\d+\.\d+)$' }
        $sorted  = $stable | Sort-Object { [version]($_.name -replace '^Python ','') } -Descending
        return [version]($sorted[0].name -replace '^Python ','')
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
    Write-Output "Could not determine latest Python version — transient network issue. Skipping."
    exit 0
}

if (-not $installed -or $installed.Count -eq 0) {
    Write-Output "Python is not installed. Remediation required."
    exit 1
}

if ($installed.Count -gt 1) {
    Write-Output "Multiple Python versions found: $($installed -join ', '). Remediation required."
    exit 1
}

if ($installed[0] -lt $latest) {
    Write-Output "Installed Python $($installed[0]) is older than latest $latest. Remediation required."
    exit 1
}

Write-Output "Python $($installed[0]) is up to date (latest: $latest). Compliant."
exit 0