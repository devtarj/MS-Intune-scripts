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
    # --include-unknown matches what remediation will actually attempt to upgrade;
    # without it, packages winget can't verify a current version for are hidden here
    # too, which would make detection and remediation disagree on what's pending.
    $result = & $wingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String

    if ($result -match "No installed package found" -or $result -match "No applicable update found") {
        Write-Output "COMPLIANT: No pending updates."
        exit 0
    }

    Write-Output "NONCOMPLIANT: Pending updates found."
    Write-Output $result
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}