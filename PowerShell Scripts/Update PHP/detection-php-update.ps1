<#
.SYNOPSIS
    Intune Proactive Remediation - DETECTION script for PHP (Windows builds).

.DESCRIPTION
    Locates an existing PHP installation, compares its version against the latest
    available build on windows.php.net for the SAME major.minor branch (safe default -
    avoids jumping major versions, e.g. 8.1 -> 8.4, which can break application code).

    Exit 0 = compliant / nothing to do (includes "PHP not installed" - this script
             updates existing installs, it does not deploy PHP fresh).
    Exit 1 = non-compliant, triggers the paired remediation script.

.NOTES
    Runs in SYSTEM context by default in Intune Proactive Remediations.
#>

$ErrorActionPreference = 'Stop'

# ---- Config -----------------------------------------------------------
# Leave $null to match the currently-installed major.minor branch (safe default).
# Set e.g. "8.4" to force detection against a specific branch instead.
$TargetBranch = $null

$SearchRoots = @(
    "C:\php",
    "C:\Program Files\PHP",
    "C:\Program Files (x86)\PHP",
    "C:\tools\php",
    "C:\xampp\php",
    "C:\wamp64\bin\php",
    "C:\wamp\bin\php",
    "C:\laragon\bin\php",
    "C:\inetpub\php"
)

$LogFile = "C:\ProgramData\IntuneLogs\PHP-Detect.log"
# -------------------------------------------------------------------------

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- 1. Locate php.exe -------------------------------------------------
    # Get-ChildItem/Get-Command are unreliable for ACL-locked paths under SYSTEM
    # (see .NET/Python remediation notes) - C:\php etc. aren't ACL-restricted like
    # WindowsApps, but we use the same cmd /c dir /b /s pattern for consistency
    # and because it's proven reliable under SYSTEM across all prior scripts.
    $phpExe = $null
    foreach ($root in $SearchRoots) {
        if (Test-Path $root) {
            $found = cmd /c "dir /b /s `"$root\php.exe`" 2>nul"
            if ($found) {
                $phpExe = ($found -split "`r`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
                if ($phpExe) { break }
            }
        }
    }
    if (-not $phpExe) {
        $whereResult = cmd /c "where php.exe 2>nul"
        if ($whereResult) {
            $phpExe = ($whereResult -split "`r`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
        }
    }

    if (-not $phpExe -or -not (Test-Path $phpExe)) {
        Write-Log "PHP not found on this device via configured search roots or PATH. Nothing to remediate."
        Write-Host "PHP not installed on this device"
        exit 0
    }
    Write-Log "Found PHP executable: $phpExe"

    # --- 2. Installed version -----------------------------------------------
    $verOutput = & $phpExe -v 2>$null
    if ($verOutput -notmatch 'PHP\s+(\d+\.\d+\.\d+)') {
        throw "Could not parse installed PHP version from '$phpExe -v' output"
    }
    $installedVersion = $Matches[1]
    Write-Log "Installed version: $installedVersion"

    # --- 3. Thread safety + architecture -------------------------------------
    $infoOutput = & $phpExe -i 2>$null
    $isThreadSafe = ($infoOutput -match 'Thread Safety\s*=>\s*enabled')
    $arch = 'x64'
    if ($infoOutput -match 'Architecture\s*=>\s*(x\d+)') { $arch = $Matches[1] }
    Write-Log "Thread Safety: $(if ($isThreadSafe) {'TS'} else {'NTS'})  |  Architecture: $arch"

    # --- 4. Determine target branch and latest release ------------------------
    $branch = if ($TargetBranch) { $TargetBranch } else { ($installedVersion -split '\.')[0..1] -join '.' }

    $releasesUrl = "https://windows.php.net/downloads/releases/"
    $html = (New-Object System.Net.WebClient).DownloadString($releasesUrl)

    $ntsTag = if ($isThreadSafe) { '' } else { '-nts' }
    $branchEscaped = [regex]::Escape($branch)
    $pattern = "php-($branchEscaped\.\d+)$ntsTag-Win32-(?:vc|vs)\d+-$arch\.zip"
    $found = [regex]::Matches($html, $pattern)

    if ($found.Count -eq 0) {
        throw "No matching Windows build found on windows.php.net for branch $branch (arch=$arch, nts=$(-not $isThreadSafe)). The branch may be EOL/removed from the current releases listing."
    }

    $latestVersion = $found |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object { [version]$_ } -Descending |
        Select-Object -First 1

    Write-Log "Latest available in branch ${branch}: $latestVersion"

    if ([version]$installedVersion -lt [version]$latestVersion) {
        Write-Log "NON-COMPLIANT: $installedVersion -> $latestVersion available"
        Write-Host "PHP update available: $installedVersion -> $latestVersion"
        exit 1
    }
    else {
        Write-Log "Compliant - already on latest ($installedVersion) for branch $branch"
        Write-Host "PHP is up to date ($installedVersion)"
        exit 0
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Detection error: $($_.Exception.Message)"
    exit 1
}