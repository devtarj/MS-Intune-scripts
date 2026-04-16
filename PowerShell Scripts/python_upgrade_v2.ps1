# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "winget not found"
    exit 1
}

# Upgrade Python to latest available version (Python 3.x)
winget upgrade --id Python.Python.3 `
    --source winget `
    --accept-package-agreements `
    --accept-source-agreements `
    --silent

# If Python is not installed, install latest version
if ($LASTEXITCODE -ne 0) {
    winget install --id Python.Python.3 `
        --scope user `
        --source winget `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent
}