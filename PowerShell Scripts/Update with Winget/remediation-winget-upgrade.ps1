# ============================================================
# Remediation: winget presence check + upgrade --all with auto-launch suppression
# Intune Proactive Remediation - SYSTEM context
# ============================================================

$logDir = "C:\ProgramData\IntuneLogs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir "WingetUpgradeAll-Remediation.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
    Write-Output $Message
}

try {
    # --- Locate winget.exe (Get-Command fails under SYSTEM due to WindowsApps ACLs) ---
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    if (-not $wingetPath) {
        Write-Log "FAILED: winget.exe not found on device. App Installer is likely not installed - this is an environment issue, not a script error. Deploy App Installer to this device before this remediation can run."
        exit 1
    }

    Write-Log "winget.exe found at: $wingetPath"

    # --- SYSTEM profile env overrides so winget's source cache resolves correctly ---
    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"

    # --- Snapshot process IDs before the upgrade ---
    $before = (Get-Process).Id

    # --- Run the upgrade (& operator, not Start-Process, under SYSTEM) ---
    $wingetOutput = & $wingetPath upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    $wingetExit = $LASTEXITCODE

    Start-Sleep -Seconds 5

    # --- Close any package that auto-launched a UI window post-update ---
    Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Write-Log "Winget exit code: $wingetExit"
    Write-Log $wingetOutput

    # --- Exit code handling ---
    # 0                = success
    # -1978335189      = no applicable update found (treat as success)
    # 3010             = reboot required
    switch ($wingetExit) {
        0             { Write-Log "Remediation successful."; exit 0 }
        -1978335189   { Write-Log "No applicable updates found - treated as success."; exit 0 }
        3010          { Write-Log "Updates applied, reboot required."; exit 0 }
        default       { Write-Log "Remediation completed with non-zero exit code: $wingetExit"; exit 1 }
    }
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}