# =====================================================
# PHP Remediation Script for Intune
# =====================================================

$ErrorActionPreference = "SilentlyContinue"

# =====================================================
# Logging
# =====================================================

$LogPath = "C:\ProgramData\PHPRemediation"
$LogFile = "$LogPath\php_remediation.log"

if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Out-File $LogFile -Append -Encoding utf8
}

Write-Log "========== PHP Remediation Started =========="

# =====================================================
# Detect PHP
# =====================================================

$PhpExe = $null

$SearchPaths = @(
    "C:\PHP\php.exe",
    "C:\xampp\php\php.exe"
)

foreach ($Path in $SearchPaths) {
    if (Test-Path $Path) {
        $PhpExe = $Path
        break
    }
}

if (!$PhpExe) {
    $Cmd = Get-Command php.exe -ErrorAction SilentlyContinue
    if ($Cmd) {
        $PhpExe = $Cmd.Source
    }
}

if (!$PhpExe) {
    Write-Log "PHP not found."
    exit 0
}

$PhpFolder = Split-Path $PhpExe -Parent

Write-Log "PHP detected at: $PhpFolder"

# =====================================================
# Current Version
# =====================================================

try {
    $InstalledVersionOutput = & $PhpExe -v
    $InstalledVersion = ($InstalledVersionOutput[0] -split " ")[1]

    Write-Log "Installed Version: $InstalledVersion"
}
catch {
    Write-Log "Unable to detect installed version."
    exit 1
}

# =====================================================
# Latest Version
# =====================================================

try {
    $ReleaseData = Invoke-RestMethod -Uri "https://www.php.net/releases/index.php?json&version=8"

    $LatestVersion = $ReleaseData.PSObject.Properties.Name |
        Sort-Object {[version]$_} -Descending |
        Select-Object -First 1

    Write-Log "Latest Version: $LatestVersion"
}
catch {
    Write-Log "Unable to query latest version."
    exit 1
}

if ([version]$InstalledVersion -ge [version]$LatestVersion) {
    Write-Log "Already compliant."
    exit 0
}

# =====================================================
# Architecture
# =====================================================

if ([Environment]::Is64BitOperatingSystem) {
    $Arch = "x64"
}
else {
    $Arch = "x86"
}

# =====================================================
# Download
# =====================================================

$ZipName = "php-$LatestVersion-Win32-vs17-$Arch.zip"
$DownloadUrl = "https://windows.php.net/downloads/releases/$ZipName"

$TempZip = "$env:TEMP\$ZipName"
$ExtractPath = "$env:TEMP\PHP_UPDATE"

Write-Log "Downloading from: $DownloadUrl"

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -UseBasicParsing
}
catch {
    Write-Log "Download failed."
    exit 1
}

# =====================================================
# Extract
# =====================================================

try {
    Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

    Expand-Archive $TempZip -DestinationPath $ExtractPath -Force

    Write-Log "Extraction successful."
}
catch {
    Write-Log "Extraction failed."
    exit 1
}

# =====================================================
# Backup
# =====================================================

$BackupFolder = "$PhpFolder-backup-$(Get-Date -Format yyyyMMddHHmmss)"

try {
    Copy-Item $PhpFolder $BackupFolder -Recurse -Force
    Write-Log "Backup created: $BackupFolder"
}
catch {
    Write-Log "Backup failed."
}

# =====================================================
# Stop IIS
# =====================================================

$IIS = Get-Service W3SVC -ErrorAction SilentlyContinue

if ($IIS -and $IIS.Status -eq "Running") {
    Stop-Service W3SVC -Force
    Write-Log "IIS stopped."
}

# =====================================================
# Replace Files
# =====================================================

try {
    Get-ChildItem $ExtractPath | ForEach-Object {
        Copy-Item $_.FullName $PhpFolder -Recurse -Force
    }

    Write-Log "Files replaced."
}
catch {
    Write-Log "Replacement failed."
    exit 1
}

# =====================================================
# Start IIS
# =====================================================

if ($IIS) {
    Start-Service W3SVC
    Write-Log "IIS started."
}

# =====================================================
# Cleanup
# =====================================================

Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

# =====================================================
# Verify
# =====================================================

try {
    $UpdatedVersionOutput = & $PhpExe -v
    $UpdatedVersion = ($UpdatedVersionOutput[0] -split " ")[1]

    Write-Log "Updated Version: $UpdatedVersion"

    if ([version]$UpdatedVersion -ge [version]$LatestVersion) {
        Write-Log "PHP updated successfully."
        exit 0
    }
    else {
        Write-Log "Verification failed."
        exit 1
    }
}
catch {
    Write-Log "Verification failed."
    exit 1
}