$results = Get-ItemProperty `
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*,
    HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
Where-Object {
    $_.DisplayName -like "*Microsoft .NET*" -or
    $_.DisplayName -like "*.NET*" -or
    $_.DisplayName -like "*Windows Desktop Runtime*" -or
    $_.DisplayName -like "*ASP.NET*"
} |
Select-Object DisplayName, DisplayVersion

if ($results) {
    $results | Format-Table -AutoSize | Out-String | Write-Output
}
else {
    Write-Output "No matching .NET entries found in uninstall registry."
}