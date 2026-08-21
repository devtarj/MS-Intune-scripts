# ============================================================
# Detection: winget presence + pending updates check (per-package listing)
# Intune Proactive Remediation - SYSTEM context
# ============================================================

# Keep this list identical to the one in the remediation script.
# These are shared-framework packages winget lists as "upgradable" but
# that shouldn't be treated as an actionable pending update.
$excludedPackageIds = @(
    "Microsoft.UI.Xaml.2.7",
    "Microsoft.UI.Xaml.2.8"
)

function Get-PendingPackages {
    param([string]$WingetPath)

    $raw = & $WingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String
    $lines = $raw -split "`r?`n"

    $headerLine = $lines | Where-Object { $_ -match '^Name\s+Id\s+Version' } | Select-Object -First 1
    if (-not $headerLine) { return @() }

    $idPos = $headerLine.IndexOf("Id")
    $versionPos = $headerLine.IndexOf("Version")
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

        if ($id -ne "") {
            $results += [PSCustomObject]@{ Name = $name; Id = $id }
        }
    }
    return $results
}

try {
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    if (-not $wingetPath) {
        Write-Output "NONCOMPLIANT: winget.exe not found on device. App Installer may not be installed."
        exit 1
    }

    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"

    $pending = Get-PendingPackages -WingetPath $wingetPath
    $actionable = $pending | Where-Object { $excludedPackageIds -notcontains $_.Id }

    if ($actionable.Count -eq 0) {
        Write-Output "COMPLIANT: No actionable pending updates."
        exit 0
    }

    Write-Output "NONCOMPLIANT: $($actionable.Count) pending update(s): $($actionable.Id -join ', ')"
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}