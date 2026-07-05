# ============================================
# Silent PHP Upgrade Script (XAMPP - Intune)
# ============================================

$ErrorActionPreference = "SilentlyContinue"

# CONFIG
$phpPath      = "C:\xampp\php"
$tempPath     = "C:\Windows\Temp\php-update"
$phpZipUrl    = "https://your-secure-location/php-8.x.x-Win32-vs16-x64.zip"
$phpZipFile   = "$tempPath\php.zip"
$expectedHash = "PUT_SHA256_HASH_HERE"

# Create temp directory
New-Item -ItemType Directory -Force -Path $tempPath | Out-Null

# Download PHP
Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipFile

# Validate hash (security check)
if ($expectedHash -ne "PUT_SHA256_HASH_HERE") {
    $actualHash = (Get-FileHash $phpZipFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        exit 1
    }
}

# -----------------------------
# Detect XAMPP Services
# -----------------------------
$apacheService = Get-WmiObject Win32_Service | Where-Object {
    $_.PathName -match "httpd.exe"
}

$mysqlService = Get-WmiObject Win32_Service | Where-Object {
    $_.PathName -match "mysqld.exe"
}

# -----------------------------
# Stop Services (if exist)
# -----------------------------
if ($apacheService) {
    Stop-Service -Name $apacheService.Name -Force
}

if ($mysqlService) {
    Stop-Service -Name $mysqlService.Name -Force
}

Start-Sleep -Seconds 3

# Fallback: Kill processes if still running
Get-Process httpd  -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process mysqld -ErrorAction SilentlyContinue | Stop-Process -Force

# -----------------------------
# Backup existing PHP
# -----------------------------
$backupPath = "$phpPath`_backup_$(Get-Date -Format yyyyMMddHHmmss)"
Rename-Item -Path $phpPath -NewName $backupPath

# -----------------------------
# Extract new PHP
# -----------------------------
Expand-Archive -Path $phpZipFile -DestinationPath "C:\xampp" -Force

# Fix folder name if needed
if (!(Test-Path $phpPath)) {
    $extractedFolder = Get-ChildItem "C:\xampp" | Where-Object {
        $_.PSIsContainer -and $_.Name -like "php*"
    } | Select-Object -First 1

    if ($extractedFolder) {
        Rename-Item -Path $extractedFolder.FullName -NewName "php"
    } else {
        # Rollback if extraction failed
        Rename-Item -Path $backupPath -NewName "php"
        exit 1
    }
}

# -----------------------------
# Restore php.ini
# -----------------------------
if (Test-Path "$backupPath\php.ini") {
    Copy-Item "$backupPath\php.ini" "$phpPath\php.ini" -Force
}

# -----------------------------
# Start Services Again
# -----------------------------
if ($apacheService) {
    Start-Service -Name $apacheService.Name
}

if ($mysqlService) {
    Start-Service -Name $mysqlService.Name
}

# -----------------------------
# Cleanup
# -----------------------------
Remove-Item -Recurse -Force $tempPath

# -----------------------------
# Validation (silent)
# -----------------------------
$phpExe = "$phpPath\php.exe"

if (Test-Path $phpExe) {
    $versionOutput = & $phpExe -v
    Write-Output $versionOutput
} else {
    # Rollback if something failed badly
    Rename-Item -Path $backupPath -NewName "php"
    exit 1
}