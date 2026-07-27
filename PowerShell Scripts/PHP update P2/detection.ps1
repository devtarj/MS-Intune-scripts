<#
.SYNOPSIS
    Intune Proactive Remediation - DETECTION script for Laragon-managed PHP.

.DESCRIPTION
    Laragon stores each PHP version as its own sibling folder under
    C:\laragon\bin\php\ (e.g. php-8.3.30-Win32-vs16-x64) and switches which one is
    "active" via its own GUI (Laragon menu > PHP > select version) - there is no
    documented safe way to change that selection programmatically, so this pair
    only manages whether the LATEST matching build is staged as a folder ready to
    select, not which one is currently active.

    Exit 0 = compliant (latest matching version already staged, or Laragon not
             present on this device).
    Exit 1 = non-compliant, triggers remediation to stage the new version.
#>

$ErrorActionPreference = 'Stop'
$LaragonPhpRoot = "C:\laragon\bin\php"
$TargetBranch = $null   # leave $null to match the highest branch currently present

$LogFile = "C:\ProgramData\IntuneLogs\PHP-Laragon-Detect.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

try {
    if (-not (Test-Path $LaragonPhpRoot)) {
        Write-Log "Laragon not found on this device ($LaragonPhpRoot missing). Nothing to check."
        Write-Host "Laragon not present"
        exit 0
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- 1. Enumerate installed version folders --------------------------------
    $versionFolders = Get-ChildItem -Path $LaragonPhpRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^php-(\d+\.\d+\.\d+)-(nts-)?Win32-(?:vc|vs)\d+-(x\d+)$' }

    if (-not $versionFolders -or $versionFolders.Count -eq 0) {
        throw "Laragon php folder exists but no recognizable php-<version>-Win32-... subfolders found"
    }

    $parsed = $versionFolders | ForEach-Object {
        if ($_.Name -match '^php-(\d+\.\d+\.\d+)-(nts-)?Win32-(?:vc|vs)\d+-(x\d+)$') {
            [PSCustomObject]@{
                Version = $Matches[1]
                IsNts   = [bool]$Matches[2]
                Arch    = $Matches[3]
                Folder  = $_.Name
            }
        }
    }

    # Use the highest-versioned folder present to infer thread-safety/arch/branch to match
    $current = $parsed | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
    $branch = if ($TargetBranch) { $TargetBranch } else { ($current.Version -split '\.')[0..1] -join '.' }
    Write-Log "Highest version currently staged: $($current.Version) (branch $branch, nts=$($current.IsNts), arch=$($current.Arch))"

    # --- 2. Check latest available for that branch/flavor on windows.php.net -----
    $releasesUrl = "https://windows.php.net/downloads/releases/"
    $html = (New-Object System.Net.WebClient).DownloadString($releasesUrl)
    $ntsTag = if ($current.IsNts) { '-nts' } else { '' }
    $branchEscaped = [regex]::Escape($branch)
    $pattern = "php-($branchEscaped\.\d+)$ntsTag-Win32-(?:vc|vs)\d+-$($current.Arch)\.zip"
    $found = [regex]::Matches($html, $pattern)

    if ($found.Count -eq 0) {
        throw "No matching Windows build found on windows.php.net for branch $branch"
    }

    $latestVersion = $found | ForEach-Object { $_.Groups[1].Value } | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
    Write-Log "Latest available for branch ${branch}: $latestVersion"

    if ([version]$current.Version -lt [version]$latestVersion) {
        Write-Log "NON-COMPLIANT: latest staged is $($current.Version), $latestVersion available"
        Write-Host "Newer PHP build available for Laragon: $($current.Version) -> $latestVersion (not yet staged)"
        exit 1
    }
    else {
        Write-Log "Compliant - latest version ($($current.Version)) already staged"
        Write-Host "Latest PHP build already staged in Laragon ($($current.Version))"
        exit 0
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Detection error: $($_.Exception.Message)"
    exit 1
}