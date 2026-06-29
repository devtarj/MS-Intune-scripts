# Detect if .NET update is required
# Date: 2026-06-29

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $winget) {
    Write-Output ".NET update required - Winget not found"
    Exit 1
}

try {
    $updates = winget upgrade --id Microsoft.DotNet.Runtime.8 --silent --accept-source-agreements 2>$null

    if ($updates -match "No available upgrade found") {
        Exit 0
    }

    Exit 1
}
catch {
    Exit 1
}