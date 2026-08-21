# ============================================================
# Remediation: winget presence check + per-package upgrade with diagnostics
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

# Known winget / installer exit codes, for a readable reason in the log
# instead of just a raw number.
$exitCodeMeanings = @{
    0            = "Success"
    3010         = "Success - reboot required"
    -1978335189  = "No applicable update found"
    -1978335212  = "No newer version available for this package"
    -1978335216  = "Install failed"
    -1978335215  = "Installer download failed"
    1618         = "Another installation is already in progress (MSI mutex locked)"
    1603         = "Fatal error during installation"
    5            = "Access denied"
}

function Get-ExitCodeMeaning {
    param([int]$Code)
    if ($exitCodeMeanings.ContainsKey($Code)) { return $exitCodeMeanings[$Code] }
    return "Unrecognized exit code - check winget/installer docs"
}

# Parses winget's table output into structured rows using the header's
# column positions, so we get each package's actual Name/Id rather than
# just raw text.
function Get-PendingPackages {
    param([string]$WingetPath)

    $raw = & $WingetPath upgrade --include-unknown --accept-source-agreements 2>&1 | Out-String
    $lines = $raw -split "`r?`n"

    $headerLine = $lines | Where-Object { $_ -match '^Name\s+Id\s+Version' } | Select-Object -First 1
    if (-not $headerLine) { return @() }

    $idPos = $headerLine.IndexOf("Id")
    $versionPos = $headerLine.IndexOf("Version")
    $availPos = $headerLine.IndexOf("Available")
    $sourcePos = $headerLine.IndexOf("Source")

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

# Known shared-framework/runtime packages that winget lists as "upgradable"
# but that should NOT be force-upgraded - they're side-by-side runtime
# dependencies other apps rely on staying at their current version, and
# forcing an upgrade/reinstall on them reliably fails or breaks the apps
# that depend on them. Add to this list as you discover more.
$excludedPackageIds = @(
    "Microsoft.UI.Xaml.2.7",
    "Microsoft.UI.Xaml.2.8"
)

try {
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    if (-not $wingetPath) {
        Write-Log "FAILED: winget.exe not found on device. App Installer is likely not installed."
        exit 1
    }

    Write-Log "winget.exe found at: $wingetPath"

    $env:LOCALAPPDATA = "C:\Windows\System32\config\systemprofile\AppData\Local"
    $env:USERPROFILE  = "C:\Windows\System32\config\systemprofile"

    $before = (Get-Process).Id

    $pending = Get-PendingPackages -WingetPath $wingetPath

    if ($pending.Count -eq 0) {
        Write-Log "No pending packages found at remediation time (may have been resolved since detection ran)."
        exit 0
    }

    Write-Log "Found $($pending.Count) pending package(s): $($pending.Id -join ', ')"

    $stillFailing = @()

    foreach ($pkg in $pending) {
        if ($excludedPackageIds -contains $pkg.Id) {
            Write-Log "Skipping $($pkg.Id) - known shared-framework package, excluded from forced upgrade."
            continue
        }

        Write-Log "--- Upgrading: $($pkg.Name) [$($pkg.Id)] ---"
        $output = & $wingetPath upgrade --id $pkg.Id --exact --silent --include-unknown --force `
            --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
        $code = $LASTEXITCODE
        $meaning = Get-ExitCodeMeaning -Code $code

        Write-Log "Exit code: $code ($meaning)"
        Write-Log $output

        if ($code -ne 0 -and $code -ne 3010 -and $code -ne -1978335189) {
            $stillFailing += [PSCustomObject]@{ Id = $pkg.Id; Code = $code; Meaning = $meaning }
        }
    }

    Start-Sleep -Seconds 5

    # Close anything that auto-launched a UI window post-update
    Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    if ($stillFailing.Count -gt 0) {
        Write-Log "REMEDIATION INCOMPLETE. Packages that did not upgrade:"
        foreach ($f in $stillFailing) {
            Write-Log "  $($f.Id): exit $($f.Code) - $($f.Meaning)"
        }
        exit 1
    }

    Write-Log "Remediation successful - all pending packages upgraded."
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}