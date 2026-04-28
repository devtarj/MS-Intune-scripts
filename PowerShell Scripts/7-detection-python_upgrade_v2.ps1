# Check if python is available in PATH
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

# Define minimum acceptable version (adjust if needed)
$minimumVersion = [version]"3.13.0"

if ($installedVersion -lt $minimumVersion) {
    Write-Output "Outdated Python version detected: $installedVersion"
    exit 1
}

Write-Output "Python is compliant: $installedVersion"
exit 0