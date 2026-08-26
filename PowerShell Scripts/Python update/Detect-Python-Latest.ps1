# ============================================================
# Detection: Python outdated version check - USER CONTEXT
# Intune Proactive Remediation - runs as logged-on user
# (catches per-user Python installs invisible to the SYSTEM-context version)
# ============================================================

function Get-PendingPackages {
    param([string]$WingetPath)

    $raw = & $WingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String
    $lines = $raw -split "`r?`n"

    $headerLine = $lines | Where-Object { $_ -match '^Name\s+Id\s+Version' } | Select-Object -First 1
    if (-not $headerLine) { return @() }

    $idPos = $headerLine.IndexOf("Id")
    $versionPos = $headerLine.IndexOf("Version")
    $availPos = $headerLine.IndexOf("Available")
    $headerIndex = [array]::IndexOf($lines, $headerLine)
    $results = @()

    for ($i = $headerIndex + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '' -or $line -match '^-+\s*$') { continue }
        if ($line -match '^\d+ upgrades? available' -or $line -match 'source agreements') { break }
        if ($line.Length -le $idPos) { continue }

        $name = $line.Substring(0, $idPos).Trim()
        $id = if ($versionPos -gt $idPos -and $line.Length -gt $idPos) {
            $endIdx = [Math]::Min($versionPos, $line.Length)
            $line.Substring($idPos, $endIdx - $idPos).Trim()
        } else { "" }
        $currentVer = if ($availPos -gt $versionPos -and $line.Length -gt $versionPos) {
            $endIdx = [Math]::Min($availPos, $line.Length)
            $line.Substring($versionPos, $endIdx - $versionPos).Trim()
        } else { "" }

        if ($id -ne "") {
            $results += [PSCustomObject]@{ Name = $name; Id = $id; CurrentVersion = $currentVer }
        }
    }
    return $results
}

try {
    # Note: NO SYSTEM profile env overrides here - this runs as the logged-on
    # user, whose LOCALAPPDATA/USERPROFILE are already correct. Overriding them
    # (as the SYSTEM-context script does) would be wrong in this context.
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1
    if (-not $wingetPath) {
        $wingetPath = (cmd /c dir /b /s "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1
    }

    if (-not $wingetPath) {
        Write-Output "NONCOMPLIANT: winget.exe not found for this user."
        exit 1
    }

    $pending = Get-PendingPackages -WingetPath $wingetPath
    $pythonPending = $pending | Where-Object { $_.Id -like "Python.Python.*" }

    if ($pythonPending.Count -eq 0) {
        Write-Output "COMPLIANT: No pending Python updates visible to this user."
        exit 0
    }

    $details = $pythonPending | ForEach-Object { "$($_.Id) (current: $($_.CurrentVersion))" }
    Write-Output "NONCOMPLIANT: Python update(s) pending: $($details -join '; ')"
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}