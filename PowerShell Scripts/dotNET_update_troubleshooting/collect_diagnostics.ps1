Write-Output "===== WHOAMI ====="
whoami

Write-Output "`n===== WINGET ====="
Get-Command winget.exe -ErrorAction SilentlyContinue | Format-List *

Write-Output "`n===== DOTNET ====="
dotnet --list-runtimes

Write-Output "`n===== SDKS ====="
dotnet --list-sdks

Write-Output "`n===== UPGRADES ====="
winget upgrade