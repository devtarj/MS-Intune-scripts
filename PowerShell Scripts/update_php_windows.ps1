$phpPath = "C:\PHP"
$tempPath = "C:\Temp\php-update"
$zipPath = "php.zip"

# Stop services using PHP
Write-Host "Stopping services..."
Stop-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
iisreset /stop

# Create temp folder
New-Item -ItemType Directory -Force -Path $tempPath

# Extract new PHP
Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force

# Backup current PHP
$backupPath = "$phpPath`_backup_$(Get-Date -Format yyyyMMddHHmmss)"
Rename-Item -Path $phpPath -NewName $backupPath

# Move new PHP
Move-Item -Path "$tempPath\php*" -Destination $phpPath

# Start services again
Write-Host "Starting services..."
Start-Service -Name "Apache2.4" -ErrorAction SilentlyContinue
iisreset /start

# Cleanup
Remove-Item -Recurse -Force $tempPath