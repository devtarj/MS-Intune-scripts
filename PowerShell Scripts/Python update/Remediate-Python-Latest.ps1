<#
.SYNOPSIS
    Intune Proactive Remediation - Remediation Script
    Installs Python if missing, or upgrades it to the latest version via winget.
    Runs as SYSTEM.

.EXIT CODES
    0 = Success
    1 = Failure
#>

$logPath = "C:\ProgramData\IntuneLogs\PythonUpdate.log"
New-Item -Path (Split-Path $logPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logPath -Append -Encoding utf8
}

try {
    Write-Log "=== Remediation started ==="

    # --- SYSTEM context fixes ---
    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Locate winget.exe ---
    $wingetPath = $null
    $searchResult = cmd /c "dir /b /s `"C:\Program Files\WindowsApps\winget.exe`" 2>nul"
    if ($searchResult) {
        $wingetPath = ($searchResult -split "`r`n" | Select-Object -First 1).Trim()
    }

    if (-not $wingetPath -or -not (Test-Path $wingetPath)) {
        Write-Log "ERROR: winget.exe not found. Cannot proceed."
        exit 1
    }
    Write-Log "winget found at: $wingetPath"

    & $wingetPath source update --accept-source-agreements 2>&1 | Out-Null

    # --- Determine install vs upgrade ---
    $listOutput = & $wingetPath list --id Python.Python.3 --accept-source-agreements 2>&1
    $isInstalled = ($listOutput -join "`n") -match 'Python\.Python\.3'

    if ($isInstalled) {
        Write-Log "Python found. Attempting upgrade..."
        $result = & $wingetPath upgrade --id Python.Python.3 --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity 2>&1
        Write-Log "Upgrade output: $($result -join ' | ')"
    }
    else {
        Write-Log "Python not found. Attempting fresh install..."
        $result = & $wingetPath install --id Python.Python.3 --silent `
            --accept-package-agreements --accept-source-agreements `
            --disable-interactivity 2>&1
        Write-Log "Install output: $($result -join ' | ')"
    }

    $exitCode = $LASTEXITCODE
    Write-Log "winget exit code: $exitCode"

    # 0 = success. -1978335189 (0x8A15002B) = "no applicable update found" - treat as success too.
    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
        Write-Log "Python updated/installed successfully (or already current)."
        exit 0
    }
    else {
        Write-Log "winget returned non-zero exit code: $exitCode"
        exit 1
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}