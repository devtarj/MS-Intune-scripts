$minimumVersion = [version]"3.14.4"

$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = Get-ItemProperty $uninstallPaths | Where-Object {
    $_.DisplayName -like "Python*"
}

foreach ($app in $apps) {
    if ($app.DisplayVersion) {
        try {
            $ver = [version]$app.DisplayVersion

            if ($ver -lt $minimumVersion) {
                Write-Output "Force removing: $($app.DisplayName)"

                if ($app.UninstallString) {
                    Start-Process "cmd.exe" -ArgumentList "/c $($app.UninstallString) /quiet /norestart" -Wait -WindowStyle Hidden
                }
            }
        } catch {}
    }
}