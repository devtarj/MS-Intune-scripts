# Detect Python installations via registry (both 32-bit & 64-bit)
$paths = @(
    "HKLM:\SOFTWARE\Python\PythonCore",
    "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore"
)

$versions = @()

foreach ($path in $paths) {
    if (Test-Path $path) {
        $versions += (Get-ChildItem $path | Select-Object -ExpandProperty PSChildName)
    }
}

# Remove duplicates
$versions = $versions | Sort-Object -Unique

if (-not $versions -or $versions.Count -eq 0) {
    Write-Output "Python not installed"
    exit 1
}

# If multiple versions → non-compliant
if ($versions.Count -gt 1) {
    Write-Output "Multiple Python versions detected: $($versions -join ', ')"
    exit 1
}

# Get installed version
$installedVersion = $versions[0]

# Basic sanity check: ensure it's Python 3.x and reasonably recent
if ($installedVersion -match "^3\.(1[3-9]|[2-9][0-9])") {
    Write-Output "Python version OK: $installedVersion"
    exit 0
} else {
    Write-Output "Outdated Python version: $installedVersion"
    exit 1
}