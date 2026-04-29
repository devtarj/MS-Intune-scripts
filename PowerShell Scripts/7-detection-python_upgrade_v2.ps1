# Check if python is available
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue

if (-not $pythonCmd) {
    Write-Output "Python not installed"
    exit 1
}

# Get active Python version
$versionOutput = python --version 2>&1

if ($versionOutput -match "(\d+\.\d+\.\d+)") {
    $installedVersion = [version]$matches[1]
} else {
    Write-Output "Unable to determine Python version"
    exit 1
}

# Enforce minimum version = 3.14.4
$minimumVersion = [version]"3.14.4"

if ($installedVersion -lt $minimumVersion) {
    Write-Output "Outdated Python version: $installedVersion"
    exit 1
}

Write-Output "Python compliant: $installedVersion"
exit 0