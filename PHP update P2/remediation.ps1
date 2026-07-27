<#
.SYNOPSIS
    Intune Proactive Remediation - REMEDIATION script for Laragon-managed PHP.

.DESCRIPTION
    Downloads the latest matching PHP build and drops it into
    C:\laragon\bin\php\ as a new sibling folder, named exactly the way Laragon
    expects (php-<version>-[nts-]Win32-vs<NN>-<arch>) - this is the same manual
    method Laragon's own docs describe for adding a version, so Laragon will pick
    it up and show it in its PHP menu automatically.

    IMPORTANT - this does NOT switch Laragon's active PHP version. That has to be
    done by a person: Laragon menu > PHP > select the new version, then (if the
    PATH doesn't refresh automatically) Tools > PATH > Remove Laragon from Path,
    then Add Laragon to Path, then log off/on. Laragon reloads Apache/Nginx
    automatically once you switch. There is no documented safe way to drive that
    switch from a script, so this remediation is intentionally scoped to staging
    only - it will keep flagging "non-compliant" from a Defender standpoint on the
    OLD version's binary until a person completes the switch and (optionally)
    removes the old version folder.
#>

$ErrorActionPreference = 'Stop'
$LaragonPhpRoot = "C:\laragon\bin\php"
$TargetBranch = $null

$LogFile = "C:\ProgramData\IntuneLogs\PHP-Laragon-Remediate.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

try {
    if (-not (Test-Path $LaragonPhpRoot)) {
        Write-Log "Laragon not found on this device. Nothing to do."
        Write-Host "Laragon not present"
        exit 0
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- 1. Identify current highest version + flavor ---------------------------
    $versionFolders = Get-ChildItem -Path $LaragonPhpRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^php-(\d+\.\d+\.\d+)-(nts-)?Win32-(?:vc|vs)\d+-(x\d+)$' }

    if (-not $versionFolders -or $versionFolders.Count -eq 0) {
        throw "No recognizable php-<version>-Win32-... subfolders found under $LaragonPhpRoot"
    }

    $parsed = $versionFolders | ForEach-Object {
        if ($_.Name -match '^php-(\d+\.\d+\.\d+)-(nts-)?Win32-(?:vc|vs)\d+-(x\d+)$') {
            [PSCustomObject]@{ Version = $Matches[1]; IsNts = [bool]$Matches[2]; Arch = $Matches[3]; Folder = $_.FullName; Name = $_.Name }
        }
    }
    $current = $parsed | Sort-Object { [version]$_.Version } -Descending | Select-Object -First 1
    $branch = if ($TargetBranch) { $TargetBranch } else { ($current.Version -split '\.')[0..1] -join '.' }
    Write-Log "Current highest staged: $($current.Name)"

    # --- 2. Find latest matching build --------------------------------------------
    $releasesUrl = "https://windows.php.net/downloads/releases/"
    $html = (New-Object System.Net.WebClient).DownloadString($releasesUrl)
    $ntsTag = if ($current.IsNts) { '-nts' } else { '' }
    $branchEscaped = [regex]::Escape($branch)
    $pattern = "php-$branchEscaped\.\d+$ntsTag-Win32-(?:vc|vs)\d+-$($current.Arch)\.zip"
    $found = [regex]::Matches($html, $pattern) | ForEach-Object { $_.Value } | Select-Object -Unique

    if (-not $found -or $found.Count -eq 0) {
        throw "No matching Windows build found for branch $branch"
    }

    $downloadFile = $found | Sort-Object { [version]([regex]::Match($_, '\d+\.\d+\.\d+').Value) } -Descending | Select-Object -First 1
    $latestVersion = [regex]::Match($downloadFile, '\d+\.\d+\.\d+').Value
    $newFolderName = [System.IO.Path]::GetFileNameWithoutExtension($downloadFile)  # matches Laragon's naming exactly
    $newFolderPath = Join-Path $LaragonPhpRoot $newFolderName

    if ([version]$current.Version -ge [version]$latestVersion) {
        Write-Log "Already staged ($($current.Version)). No action needed."
        Write-Host "Latest PHP build already staged in Laragon"
        exit 0
    }

    if (Test-Path $newFolderPath) {
        Write-Log "Target folder $newFolderPath already exists but version check said non-compliant - treating as already staged."
        Write-Host "Latest build folder already present"
        exit 0
    }

    Write-Log "Staging new version: $($current.Version) -> $latestVersion ($newFolderName)"

    # --- 3. Download and extract as a new sibling folder ---------------------------
    $downloadUrl = "$releasesUrl$downloadFile"
    $zipPath = Join-Path "C:\Windows\Temp" $downloadFile
    (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $zipPath)

    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -lt 1MB) {
        throw "Downloaded file missing or too small - download likely failed"
    }

    New-Item -Path $newFolderPath -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $newFolderPath -Force
    Write-Log "Extracted new build into $newFolderPath"

    # Best-effort: carry over php.ini from the current version for continuity.
    # NOTE: if php.ini has any absolute paths referencing the OLD version folder
    # name (e.g. extension_dir="C:/laragon/bin/php/$($current.Name)/ext"), those
    # will need manual correction after switching - flagging this explicitly
    # rather than trying to auto-rewrite paths, which risks silently breaking config.
    $oldIni = Join-Path $current.Folder "php.ini"
    if (Test-Path $oldIni) {
        Copy-Item $oldIni (Join-Path $newFolderPath "php.ini") -Force
        Write-Log "Copied php.ini from $($current.Name) into $newFolderName - VERIFY any absolute paths inside it after switching versions"
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path (Join-Path $newFolderPath "php.exe"))) {
        throw "Extraction completed but php.exe not found in $newFolderPath - staging failed"
    }

    Write-Log "SUCCESS: staged $newFolderName. Manual switch still required."
    Write-Host "Staged PHP $latestVersion in Laragon ($newFolderName). ACTION NEEDED: open Laragon > Menu > PHP > select this version to activate it (Apache/Nginx reload automatically). If PATH doesn't refresh, use Tools > PATH > Remove/Add Laragon to Path and log off/on. Old version ($($current.Name)) is left in place until you confirm the new one works - remove it manually afterward to fully clear the related Defender finding."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Host "Remediation failed: $($_.Exception.Message)"
    exit 1
}