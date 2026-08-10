try {
    $before = (Get-Process).Id

    winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
    $wingetExit = $LASTEXITCODE

    Start-Sleep -Seconds 5

    Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
        Stop-Process -Force

    Write-Output "Upgrade completed. Winget exit code: $wingetExit"
    exit 0
}
catch {
    Write-Output "FAILED: $($_.Exception.Message)"
    exit 1
}

#under testing