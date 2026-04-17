$log = "C:\temp\python_remediation.txt"

Add-Content $log "Starting remediation at $(Get-Date)"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Add-Content $log "winget not found"
    exit 1
}

winget upgrade --id Python.Python.3 `
    --accept-package-agreements `
    --accept-source-agreements `
    --silent

Add-Content $log "Upgrade exit code: $LASTEXITCODE"

if ($LASTEXITCODE -ne 0) {
    winget install --id Python.Python.3 `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    Add-Content $log "Install exit code: $LASTEXITCODE"
}

Add-Content $log "Remediation finished"
exit 0