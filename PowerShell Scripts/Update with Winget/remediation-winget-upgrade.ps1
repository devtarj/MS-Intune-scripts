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

function Invoke-WingetUpgradeAll {
    param([string]$WingetPath)

    # --include-unknown: upgrade packages winget can't verify the current version for
    #                    (silently skipped otherwise - this is the #1 cause of "listed
    #                    but never actually upgraded")
    # --force:           bypass winget treating a package as "already handled" and
    #                    actually reinstall/upgrade it
    $output = & $WingetPath upgrade --all --silent --include-unknown --force `
        --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    return @{ Output = $output; ExitCode = $LASTEXITCODE }
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

    # --- Pass 1 ---
    Write-Log "Starting upgrade pass 1..."
    $pass1 = Invoke-WingetUpgradeAll -WingetPath $wingetPath
    Write-Log "Pass 1 exit code: $($pass1.ExitCode)"
    Write-Log $pass1.Output

    # --- Confirm what's left; retry once if anything remains ---
    # (some packages fail a first pass because the app was in use, or a transient
    # download/lock issue - a second pass clears most of these)
    $remaining = & $wingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String
    $stillPending = -not ($remaining -match "No installed package found" -or $remaining -match "No applicable update found")

    if ($stillPending) {
        Write-Log "Packages still pending after pass 1 - running pass 2..."
        Start-Sleep -Seconds 5
        $pass2 = Invoke-WingetUpgradeAll -WingetPath $wingetPath
        Write-Log "Pass 2 exit code: $($pass2.ExitCode)"
        Write-Log $pass2.Output
    }

    Start-Sleep -Seconds 5

    # --- Close any package that auto-launched a UI window post-update ---
    Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    # --- Final check: did everything actually clear? ---
    $final = & $wingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String
    $finalPending = -not ($final -match "No installed package found" -or $final -match "No applicable update found")

    if ($finalPending) {
        Write-Log "REMEDIATION INCOMPLETE: Packages remain after retry. Final listing below - check for packages requiring manual intervention (e.g. blocked by an interactive prompt winget can't suppress)."
        Write-Log $final
        exit 1
    }

    Write-Log "Remediation successful - all packages upgraded."
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}