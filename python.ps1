# ================================
# Python Install / Upgrade Script
# For Intune (SYSTEM context)
# ================================

$ErrorActionPreference = "Stop"

# URL for latest Python 3 (64-bit) Windows installer
$PythonInstallerUrl = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
$InstallerPath = "$env:TEMP\python-installer.exe"

# Registry paths to detect Python
$PythonRegPaths = @(
    "HKLM:\SOFTWARE\Python\PythonCore",
    "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore"
)

function Get-InstalledPythonVersion {
    foreach ($path in $PythonRegPaths) {
        if (Test-Path $path) {
            $versions = Get-ChildItem $path -ErrorAction SilentlyContinue
            if ($versions) {
                return ($versions | Sort-Object Name -Descending | Select-Object -First 1).PSChildName
            }
        }
    }
    return $null
}

# Detect installed Python
$InstalledVersion = Get-InstalledPythonVersion

Write-Output "Detected Python version: $InstalledVersion"

# Download latest Python installer
Write-Output "Downloading Python installer..."
Invoke-WebRequest -Uri $PythonInstallerUrl -OutFile $InstallerPath

# Silent install / upgrade arguments
$InstallArgs = @(
    "/quiet",
    "InstallAllUsers=1",
    "PrependPath=1",
    "Include_test=0",
    "SimpleInstall=1"
)

Write-Output "Installing / upgrading Python..."
Start-Process -FilePath $InstallerPath -ArgumentList $InstallArgs -Wait -NoNewWindow

# Cleanup
Remove-Item $InstallerPath -Force

# Verify installation
try {
    $PythonVersion = & python --version 2>&1
    Write-Output "Python successfully installed: $PythonVersion"
}
catch {
    Write-Error "Python installation failed"
}
