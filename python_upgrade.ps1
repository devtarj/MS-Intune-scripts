# Ensure winget is available
if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found"
    exit 1
}

# Upgrade Python silently
winget upgrade --id Python.Python.3 --silent --accept-source-agreements --accept-package-agreements

exit 0