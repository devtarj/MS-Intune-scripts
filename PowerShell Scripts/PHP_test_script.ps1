# =========================================================
# Dynamic PHP Silent Updater for Intune
# Author: Enterprise Intune Deployment
# =========================================================

$ErrorActionPreference = "SilentlyContinue"

# =========================================================
# Logging
# =========================================================

$LogPath = "C:\ProgramData\PHPUpdate"
$LogFile = "$LogPath\php_update.log"

if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

Write-Log "========== PHP Update Started =========="

# =========================================================
# Detect PHP
# =========================================================

$PhpExe = $null

# Common locations
$SearchPaths = @(
    "C:\PHP\php.exe",
    "C:\xampp\php\php.exe",
    "C:\wamp64\bin\php",
    "C:\laragon\bin\php"
)

foreach ($Path in $SearchPaths) {
    if (Test-Path $Path) {
        $PhpExe = $Path
        break
    }
}

# Search PATH if not found
if (!$PhpExe) {
    $Cmd = Get-Command php.exe -ErrorAction SilentlyContinue
    if ($Cmd) {
        $PhpExe = $Cmd.Source
    }
}

if (!$PhpExe) {
    Write-Log "PHP not found. Exiting."
    exit 0
}

Write-Log "PHP found at: $PhpExe"

$PhpFolder = Split-Path $PhpExe -Parent

# =========================================================
# Get Installed Version
# =========================================================

$InstalledVersionOutput = & $PhpExe -v
$InstalledVersion = ($InstalledVersionOutput[0] -split " ")[1]

Write-Log "Installed Version: $InstalledVersion"

# =========================================================
# Get Latest PHP Version Dynamically
# =========================================================

try {
    $ReleaseData = Invoke-RestMethod -Uri "https://www.php.net/releases/index.php?json&version=8"

    $LatestVersion = $ReleaseData.PSObject.Properties.Name |
        Sort-Object {[version]$_} -Descending |
        Select-Object -First 1

    Write-Log "Latest Available Version: $LatestVersion"
}
catch {
    Write-Log "Failed to query latest PHP version."
    exit 1
}

# =========================================================
# Compare Versions
# =========================================================

if ([version]$InstalledVersion -ge [version]$LatestVersion) {
    Write-Log "PHP already up to date."
    exit 0
}

Write-Log "Upgrade required."

# =========================================================
# Detect Architecture
# =========================================================

if ([Environment]::Is64BitOperatingSystem) {
    $Arch = "x64"
}
else {
    $Arch = "x86"
}

# =========================================================
# Build Download URL
# =========================================================

# Using windows binaries from php.net
# VS17 builds

$ZipName = "php-$LatestVersion-Win32-vs17-$Arch.zip"
$DownloadUrl = "https://windows.php.net/downloads/releases/$ZipName"

Write-Log "Download URL: $DownloadUrl"

# =========================================================
# Download
# =========================================================

$TempZip = "$env:TEMP\$ZipName"
$ExtractPath = "$env:TEMP\PHP_Update"

Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -UseBasicParsing
    Write-Log "Download completed."
}
catch {
    Write-Log "Download failed."
    exit 1
}

# =========================================================
# Extract
# =========================================================

try {
    Expand-Archive -Path $TempZip -DestinationPath $ExtractPath -Force
    Write-Log "Extraction completed."
}
catch {
    Write-Log "Extraction failed."
    exit 1
}

# =========================================================
# Backup Existing PHP
# =========================================================

$BackupPath = "$PhpFolder-backup-$(Get-Date -Format yyyyMMddHHmmss)"

try {
    Copy-Item $PhpFolder $BackupPath -Recurse -Force
    Write-Log "Backup created at: $BackupPath"
}
catch {
    Write-Log "Backup failed."
}

# =========================================================
# Stop IIS if running
# =========================================================

$iis = Get-Service W3SVC -ErrorAction SilentlyContinue

if ($iis -and $iis.Status -eq "Running") {
    Stop-Service W3SVC -Force
    Write-Log "IIS stopped."
}

# =========================================================
# Replace PHP Files
# =========================================================

try {
    Get-ChildItem $ExtractPath | ForEach-Object {
        Copy-Item $_.FullName $PhpFolder -Recurse -Force
    }

    Write-Log "PHP files replaced successfully."
}
catch {
    Write-Log "File replacement failed."
    exit 1
}

# =========================================================
# Start IIS
# =========================================================

if ($iis) {
    Start-Service W3SVC
    Write-Log "IIS started."
}

# =========================================================
# Cleanup
# =========================================================

Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

# =========================================================
# Verify
# =========================================================

$NewVersionOutput = & $PhpExe -v
$NewVersion = ($NewVersionOutput[0] -split " ")[1]

Write-Log "Updated Version: $NewVersion"

if ([version]$NewVersion -ge [version]$LatestVersion) {
    Write-Log "PHP updated successfully."
    exit 0
}
else {
    Write-Log "PHP update verification failed."
    exit 1
}