<#
.SYNOPSIS
    Intune Proactive Remediation - Detection Script
    Checks whether Python (winget ID: Python.Python.3) is at the latest available version.
    Runs as SYSTEM.

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
    Write-Log "=== Detection started ==="

    # --- SYSTEM context fixes ---
    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Locate winget.exe (Get-ChildItem fails silently under SYSTEM due to WindowsApps ACLs) ---
    $wingetPath = $null
    $searchResult = cmd /c "dir /b /s `"C:\Program Files\WindowsApps\winget.exe`" 2>nul"
    if ($searchResult) {
        $wingetPath = ($searchResult -split "`r`n" | Select-Object -First 1).Trim()
    }

    if (-not $wingetPath -or -not (Test-Path $wingetPath)) {
        Write-Log "winget.exe not found. Cannot verify Python version."
        Write-Output "winget not found"
        exit 1
    }
    Write-Log "winget found at: $wingetPath"

    # Refresh sources so 'latest version' is accurate (best effort, ignore failures)
    & $wingetPath source update --accept-source-agreements 2>&1 | Out-Null

    # --- Installed version via winget list ---
    $listOutput = & $wingetPath list --id Python.Python.3 --accept-source-agreements 2>&1
    Write-Log "winget list output: $($listOutput -join ' | ')"

    $installedVersion = $null
    foreach ($line in $listOutput) {
        if ($line -match 'Python\.Python\.3\S*\s+([\d\.]+)') {
            $installedVersion = $matches[1]
            break
        }
    }

    # Fallback: py launcher, in case winget's tracked package doesn't match reality
    if (-not $installedVersion) {
        $pyCheck = cmd /c "py -3 --version 2>&1"
        if ($pyCheck -match '(\d+\.\d+\.\d+)') {
            $installedVersion = $matches[1]
        }
    }

    if (-not $installedVersion) {
        Write-Log "Python is not installed on this device."
        Write-Output "Python not installed"
        exit 1
    }
    Write-Log "Installed Python version: $installedVersion"

    # --- Latest available version via winget show ---
    $showOutput = & $wingetPath show --id Python.Python.3 --accept-source-agreements 2>&1
    Write-Log "winget show output: $($showOutput -join ' | ')"

    $latestVersion = $null
    foreach ($line in $showOutput) {
        if ($line -match '^Version:\s*([\d\.]+)') {
            $latestVersion = $matches[1]
            break
        }
    }

    if (-not $latestVersion) {
        Write-Log "Could not determine latest available Python version from winget show."
        Write-Output "Unable to determine latest version"
        exit 1
    }
    Write-Log "Latest available Python version: $latestVersion"

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