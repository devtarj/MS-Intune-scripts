# ================================
# Python Silent Install / Upgrade
# For Intune (System Context)
# ================================

$LatestPythonVersion = "3.13.1"
$PythonInstallerUrl  = "https://www.python.org/ftp/python/3.14.3/python-3.14.3-amd64.exe"
$InstallerPath       = "$env:TEMP\python-installer.exe"
$TargetDir           = "C:\Python"

Write-Output "Checking for existing Python installation..."

function Get-InstalledPythonVersion {
    try {
        $version = & python --version 2>$null
        if ($version) {
            return ($version -replace "Python ", "").Trim()
        }
    } catch {
        return $null
    }
}

$InstalledVersion = Get-InstalledPythonVersion

if ($InstalledVersion) {
    Write-Output "Detected Python version: $InstalledVersion"

    if ([version]$InstalledVersion -ge [version]$LatestPythonVersion) {
        Write-Output "Latest Python already installed. Exiting script."
        exit 0
    } else {
        Write-Output "Older Python version detected. Upgrading to $LatestPythonVersion..."
    }
} else {
    Write-Output "Python not found. Installing Python $LatestPythonVersion..."
}

# Download installer
Write-Output "Downloading Python installer..."
Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $InstallerPath -UseBasicParsing

# Silent install / upgrade
Write-Output "Running silent installation..."
Start-Process -FilePath $InstallerPath -ArgumentList `
    "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 TargetDir=$TargetDir" `
    -Wait

# Cleanup
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue

# Verify installation
$PostInstallVersion = Get-InstalledPythonVersion

if ($PostInstallVersion) {
    Write-Output "Python successfully installed/updated to version $PostInstallVersion"
    exit 0
} else {
    Write-Error "Python installation failed"
    exit 1
}