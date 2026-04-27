# Remove Python via Win32 uninstall registry (covers EXE/MSI installs)
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = Get-ItemProperty $uninstallPaths | Where-Object {
    $_.DisplayName -like "Python*"
}

foreach ($app in $apps) {
    if ($app.DisplayVersion -notmatch "^3\.(1[3-9]|[2-9][0-9])") {
        Write-Output "Uninstalling $($app.DisplayName)"

        if ($app.UninstallString) {
            Start-Process "cmd.exe" -ArgumentList "/c $($app.UninstallString) /quiet" -Wait -WindowStyle Hidden
        }
    }
}