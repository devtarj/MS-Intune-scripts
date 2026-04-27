# Count Python executables in PATH
$pythons = where.exe python 2>$null

if (-not $pythons) {
    Write-Output "Python not installed"
    exit 1
}

# If multiple python paths → likely multiple installs
if ($pythons.Count -gt 1) {
    Write-Output "Multiple Python paths detected"
    exit 1
}

# Check version
$version = (python --version 2>&1)

if ($version -match "3\.(1[3-9]|[2-9][0-9])") {
    exit 0
} else {
    exit 1
}