# Date: 2026-06-24
Get-ItemProperty `
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* ,
HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
Where-Object {
    $_.DisplayName -like "*Microsoft .NET*"
} |
Select-Object DisplayName, DisplayVersion