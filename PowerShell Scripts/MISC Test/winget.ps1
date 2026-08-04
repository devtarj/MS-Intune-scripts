$before = (Get-Process).Id

winget upgrade --all --silent --accept-source-agreements --accept-package-agreements --include-unknown

Start-Sleep -Seconds 5

Get-Process | Where-Object { $before -notcontains $_.Id -and $_.MainWindowHandle -ne 0 } |
    Stop-Process -Force