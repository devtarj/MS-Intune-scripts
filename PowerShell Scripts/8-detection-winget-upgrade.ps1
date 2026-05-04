$updates = winget upgrade --accept-source-agreements | Select-String "^\S"

if ($updates) {
    Write-Output "Updates available"
    exit 1
} else {
    Write-Output "No updates"
    exit 0
}