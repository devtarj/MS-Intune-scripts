# ================================
# Silent PHP Upgrade Script (XAMPP)
# ================================

$ErrorActionPreference = "SilentlyContinue"

# CONFIG
$phpPath = "C:\xampp\php"
$tempPath = "C:\Windows\Temp\php-update"
$phpZipUrl = "https://your-secure-location/php-8.x.x-Win32-vs16-x64.zip"
$phpZipFile = "$tempPath\php.zip"

# Create temp directory
New-Item -ItemType Directory -Force -Path $tempPath | Out-Null

# Download PHP silently
Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipFile

# Stop XAMPP services quietly
Stop-Service -Name "Apache2.4" -Force
Stop-Service -Name "mysql" -Force

Start-Sleep -Seconds 3

# Backup existing PHP
$backupPath = "$phpPath`_backup_$(Get-Date -Format yyyyMMddHHmmss)"
Rename-Item -Path $phpPath -NewName $backupPath

# Extract new PHP
Expand-Archive -Path $phpZipFile -DestinationPath "C:\xampp" -Force

# Ensure folder name is correct
if (!(Test-Path $phpPath)) {
    $extractedFolder = Get-ChildItem "C:\xampp" | Where-Object { $_.Name -like "php*" } | Select-Object -First 1
    Rename-Item -Path $extractedFolder.FullName -NewName "php"
}

# Restore php.ini if exists
if (Test-Path "$backupPath\php.ini") {
    Copy-Item "$backupPath\php.ini" "$phpPath\php.ini" -Force
}

# Start services again
Start-Service -Name "Apache2.4"
Start-Service -Name "mysql"

# Cleanup
Remove-Item -Recurse -Force $tempPath

# Optional: Output version (for logs only, user won't see)
& "$phpPath\php.exe" -v