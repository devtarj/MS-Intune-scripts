try {
    $before = (Get-Process).Id

    $wingetOutput = winget upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    $wingetExit = $LASTEXITCODE

    Start-Sleep -Seconds 5

    Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
        Stop-Process -Force

    Write-Output "Winget exit code: $wingetExit"
    Write-Output $wingetOutput
    exit 0
}
catch {
    Write-Output "FAILED: $($_.Exception.Message)"
    exit 1
}