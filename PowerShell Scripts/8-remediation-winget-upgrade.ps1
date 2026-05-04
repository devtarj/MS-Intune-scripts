$logPath = "C:\ProgramData\WingetUpgrade.log"

# Ensure winget is available in SYSTEM context
$wingetPath = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $wingetPath) {
    $possiblePaths = Get-ChildItem "C:\Program Files\WindowsApps" -Recurse -Filter winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($possiblePaths) {
        $wingetPath = $possiblePaths.FullName
    } else {
        Write-Output "Winget not found"
        exit 1
    }
}

try {
    Start-Process -FilePath $wingetPath `
        -ArgumentList "upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --include-unknown --force" `
        -NoNewWindow `
        -WindowStyle Hidden `
        -Wait

    Write-Output "Upgrade completed silently"
    exit 0
}
catch {
    Write-Output "Upgrade failed"
    exit 1
}