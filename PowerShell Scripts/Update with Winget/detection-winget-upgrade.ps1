# ============================================================
# Detection: winget presence + pending updates check (per-package listing)
# Intune Proactive Remediation - SYSTEM context
# ============================================================

try {
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    if (-not $wingetPath) {
        Write-Output "NONCOMPLIANT: winget.exe not found on device. App Installer may not be installed."
        exit 1
    }

    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"

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