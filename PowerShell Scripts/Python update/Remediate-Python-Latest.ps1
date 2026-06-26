<#
.SYNOPSIS
    Intune Proactive Remediation - REMEDIATION script for Python.

.DESCRIPTION
    Downloads and silently installs the latest stable 64-bit Python release
    from python.org for all users, then removes any other Python versions
    found on the device so exactly one (the latest) remains.

    Deploy this as the "Remediation script" in an Intune Remediation, running
    in SYSTEM context, 64-bit PowerShell.

.NOTES
    Requires outbound internet access to www.python.org from the SYSTEM
    account (proxy/firewall must allow it).
#>

$ErrorActionPreference = 'Stop'
$logDir  = "$env:ProgramData\IntuneLogs"
$logFile = Join-Path $logDir "Python-Remediation.log"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Start-Transcript -Path $logFile -Append | Out-Null

function Get-LatestPythonRelease {
    $uri = "https://www.python.org/api/v2/downloads/release/?is_published=true&pre_release=false"
    $releases = Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 30
    $stable = $releases | Where-Object { $_.name -match '^Python (\d+\.\d+\.\d+)$' }
    $sorted = $stable | Sort-Object { [version]($_.name -replace '^Python ', '') } -Descending
    $top     = $sorted[0]
    $version = [version]($top.name -replace '^Python ', '')

    $filesUri = "https://www.python.org/api/v2/downloads/release_file/?release=$($top.id)"
    $files = Invoke-RestMethod -Uri $filesUri -UseBasicParsing -TimeoutSec 30
    $exe = $files | Where-Object { $_.url -match 'amd64\.exe$' -and $_.url -notmatch 'webinstall' } |
        Select-Object -First 1

    if (-not $exe) { throw "Could not find a 64-bit installer for Python $version" }

    [PSCustomObject]@{ Version = $version; Url = $exe.url }
}

function Get-InstalledPythonApps {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '^Python \d+\.\d+\.\d+' }
}

function Uninstall-PythonApp {
    param($App)
    try {
        if ($App.QuietUninstallString) {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($App.QuietUninstallString)`"" -Wait -ErrorAction Stop
        }
        elseif ($App.UninstallString -match 'msiexec') {
            if ($App.UninstallString -match '\{[0-9A-Fa-f\-]+\}') {
                $productCode = $Matches[0]
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -ErrorAction Stop
            }
        }
        elseif ($App.UninstallString) {
            $exePath = $App.UninstallString.Trim('"')
            Start-Process -FilePath $exePath -ArgumentList "/uninstall /quiet" -Wait -ErrorAction Stop
        }
        Write-Output "Removed: $($App.DisplayName)"
    }
    catch {
        Write-Output "Failed to uninstall $($App.DisplayName): $_"
    }
}

try {
    $release = Get-LatestPythonRelease
    Write-Output "Latest available Python version: $($release.Version)"

    $installerPath = Join-Path $env:TEMP "python-$($release.Version)-amd64.exe"
    Write-Output "Downloading installer from $($release.Url)"
    Invoke-WebRequest -Uri $release.Url -OutFile $installerPath -UseBasicParsing

    Write-Output "Installing Python $($release.Version) silently for all users..."
    $installArgs = @(
        "/quiet",
        "InstallAllUsers=1",
        "PrependPath=1",
        "Include_launcher=1",
        "Include_test=0",
        "Include_pip=1"
    )
    $proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        throw "Python installer exited with code $($proc.ExitCode)"
    }
    Write-Output "Python $($release.Version) installed successfully."

    # Remove any other Python installations so only the latest remains
    $installedApps = Get-InstalledPythonApps
    foreach ($app in $installedApps) {
        if ($app.DisplayName -match '^Python (\d+\.\d+\.\d+)') {
            $ver = [version]$Matches[1]
            if ($ver -ne $release.Version) {
                Write-Output "Removing older Python version: $($app.DisplayName)"
                Uninstall-PythonApp -App $app
            }
        }
    }

    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    Write-Output "Remediation completed successfully."
    Stop-Transcript | Out-Null
    exit 0
}
catch {
    Write-Output "Remediation failed: $_"
    Stop-Transcript | Out-Null
    exit 1
}
