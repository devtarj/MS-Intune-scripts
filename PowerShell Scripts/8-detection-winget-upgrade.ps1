$ErrorActionPreference = "SilentlyContinue"

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $winget) {
    exit 0
}

try {

    $upgradeData = winget upgrade `
        --output json `
        --accept-source-agreements |
        ConvertFrom-Json

    if ($upgradeData.Sources.Packages.Count -gt 0) {
        Write-Output "Updates available"
        exit 1
    }
    else {
        Write-Output "Compliant"
        exit 0
    }

}
catch {

    exit 0
}