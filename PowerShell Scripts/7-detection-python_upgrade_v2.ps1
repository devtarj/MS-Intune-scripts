# Find all python.exe locations
$pythonPaths = Get-ChildItem -Path "C:\Program Files","C:\Program Files (x86)" -Recurse -Filter python.exe -ErrorAction SilentlyContinue

if (-not $pythonPaths) {
    Write-Output "No Python found"
    exit 1
}

$minimumVersion = [version]"3.14.4"
$compliant = $false

foreach ($path in $pythonPaths) {
    try {
        $versionOutput = & $path.FullName --version 2>&1
        if ($versionOutput -match "(\d+\.\d+\.\d+)") {
            $ver = [version]$matches[1]

            if ($ver -ge $minimumVersion) {
                $compliant = $true
            } else {
                Write-Output "Old Python found: $ver at $($path.FullName)"
                exit 1
            }
        }
    } catch {}
}

if ($compliant) {
    Write-Output "Python compliant"
    exit 0
}

exit 1