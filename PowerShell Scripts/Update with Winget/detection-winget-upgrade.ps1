# ============================================================
# Detection: winget presence + pending updates check
# Intune Proactive Remediation - SYSTEM context
# ============================================================

try {
    # --- Locate winget.exe (Get-Command fails under SYSTEM due to WindowsApps ACLs) ---
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    if (-not $wingetPath) {
        Write-Output "NONCOMPLIANT: winget.exe not found on device. App Installer may not be installed."
        exit 1
    }

    # --- SYSTEM profile env overrides so winget's source cache resolves correctly ---
    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"

    # --- Check for pending updates ---
    $result = & $wingetPath upgrade --accept-source-agreements 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq -1978335189) {
        # No applicable update found
        Write-Output "COMPLIANT: No pending updates."
        exit 0
    }

    if ($result -match "No installed package found" -or $result -match "No applicable update found") {
        Write-Output "COMPLIANT: No pending updates."
        exit 0
    }

    # Any other outcome (updates listed, or an unexpected winget error) triggers remediation
    Write-Output "NONCOMPLIANT: Pending updates found or winget returned an unexpected result (exit $exitCode)."
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}