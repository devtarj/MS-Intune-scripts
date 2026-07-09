<#
.SYNOPSIS
    Intune Proactive Remediation - REMEDIATION script for Python.

.DESCRIPTION
    Downloads and silently installs the latest stable 64-bit Python release
    from python.org for all users, then removes any older Python versions.
    Runs in SYSTEM context, 64-bit PowerShell.

.NOTES
    Exit 0 = success (includes reboot-required code 3010)
    Exit 1 = failure
#>

$ErrorActionPreference = 'Stop'

# --- Force TLS 1.2 so SYSTEM account can reach python.org ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logDir  = "$env:ProgramData\IntuneLogs"
$logFile = Join-Path $logDir "Python-Remediation.log"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$ts] $Message"
    Write-Output $line
    Add-Content -Path $logFile -Value $line
}

function Get-LatestPythonRelease {
    # page_size=50 avoids pagination cutting off recent releases.
    # We sort client-side to always get the true latest.
    $uri = "https://www.python.org/api/v2/downloads/release/?is_published=true&pre_release=false&page_size=50"
    $releases = Invoke-RestMethod -Uri $uri -UseBasicParsing -TimeoutSec 30
    $stable = $releases.results | Where-Object { $_.name -match '^Python (\d+\.\d+\.\d+)$' }
    $sorted  = $stable | Sort-Object { [version]($_.name -replace '^Python ','') } -Descending
    $top     = $sorted[0]
    $version = [version]($top.name -replace '^Python ','')

    $filesUri = "https://www.python.org/api/v2/downloads/release_file/?release=$($top.id)&page_size=50"
    $files    = Invoke-RestMethod -Uri $filesUri -UseBasicParsing -TimeoutSec 30
    $exe      = $files.results |
                    Where-Object { $_.url -match 'amd64\.exe$' -and $_.url -notmatch 'web' } |
                    Select-Object -First 1

    if (-not $exe) { throw "No 64-bit installer found for Python $version" }

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
    Write-Log "Attempting to remove: $($App.DisplayName)"
    try {
        if ($App.QuietUninstallString) {
            cmd.exe /c $App.QuietUninstallString | Out-Null
        }
        elseif ($App.UninstallString -match 'msiexec') {
            if ($App.UninstallString -match '\{[0-9A-Fa-f\-]+\}') {
                $code = $Matches[0]
                Start-Process msiexec.exe -ArgumentList "/x $code /quiet /norestart" -Wait
            }
        }
        elseif ($App.UninstallString) {
            $exePath = ($App.UninstallString -replace '"','').Trim()
            if (Test-Path $exePath) {
                Start-Process $exePath -ArgumentList "/uninstall /quiet" -Wait
            }
        }
        Write-Log "Removed: $($App.DisplayName)"
    }
    catch {
        Write-Log "WARNING: Could not remove $($App.DisplayName): $_"
    }
}

try {
    Write-Log "===== Python Remediation Started ====="

    # 1. Resolve latest version and installer URL
    Write-Log "Querying python.org for latest stable release..."
    $release = Get-LatestPythonRelease
    Write-Log "Latest version: $($release.Version)"
    Write-Log "Installer URL : $($release.Url)"

    # 2. Download installer to a safe, SYSTEM-accessible temp path
    $installerPath = "C:\Windows\Temp\python-$($release.Version)-amd64.exe"
    Write-Log "Downloading to $installerPath ..."

    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($release.Url, $installerPath)

    $fileSize = (Get-Item $installerPath).Length
    if ($fileSize -lt 1MB) {
        throw "Downloaded file is suspiciously small ($fileSize bytes) — download likely failed."
    }
    Write-Log "Download complete. File size: $([math]::Round($fileSize/1MB,1)) MB"

    # 3. Install silently for all users
    Write-Log "Running installer..."
    $installArgs = '/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1 Include_test=0 Include_pip=1'
    $proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    # Exit 0 = success, 3010 = success but reboot required - both are OK
    if ($proc.ExitCode -notin @(0, 3010)) {
        throw "Installer exited with unexpected code: $($proc.ExitCode)"
    }
    Write-Log "Python $($release.Version) installed. Exit code: $($proc.ExitCode)"

    # 4. Remove all other Python versions
    Write-Log "Scanning for older Python versions to remove..."
    $installedApps = Get-InstalledPythonApps
    foreach ($app in $installedApps) {
        if ($app.DisplayName -match '^Python (\d+\.\d+\.\d+)') {
            $ver = [version]$Matches[1]
            if ($ver -ne $release.Version) {
                Uninstall-PythonApp -App $app
            }
            else {
                Write-Log "Keeping: $($app.DisplayName)"
            }
        }
    }

    # 5. Cleanup
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    Write-Log "===== Remediation Completed Successfully ====="
    exit 0
}
catch {
    Write-Log "===== Remediation FAILED: $_ ====="
    exit 1
}