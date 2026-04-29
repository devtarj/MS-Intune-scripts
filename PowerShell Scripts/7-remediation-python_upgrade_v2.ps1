# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    exit 1
}

# -------------------------------
# 1. Install / Upgrade Python
# -------------------------------
$process = Start-Process "winget" -ArgumentList @(
    "upgrade",
    "--id", "Python.Python.3",
    "--scope", "machine",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--disable-interactivity",
    "--force"
) -WindowStyle Hidden -Wait -PassThru

# If upgrade fails (not installed), install
if ($process.ExitCode -ne 0) {
    Start-Process "winget" -ArgumentList @(
        "install",
        "--id", "Python.Python.3",
        "--scope", "machine",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    ) -WindowStyle Hidden -Wait
}

Start-Sleep -Seconds 10

# -------------------------------
# 2. Remove old Python versions (EXE/MSI)
# -------------------------------
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
            $appVersion = [version]$app.DisplayVersion

            if ($appVersion -lt $minimumVersion) {
                Write-Output "Removing old version: $($app.DisplayName) ($appVersion)"

                if ($app.UninstallString) {
                    Start-Process "cmd.exe" `
                        -ArgumentList "/c $($app.UninstallString) /quiet" `
                        -WindowStyle Hidden -Wait
                }
            }
        } catch {}
    }
}

# -------------------------------
# 3. Remove old versions via winget
# -------------------------------
$wingetList = winget list --source winget | Select-String "Python"

foreach ($line in $wingetList) {
    if ($line -match "Python\.Python\.(\d+\.\d+)") {
        $ver = $matches[1]

        try {
            $verObj = [version]("$ver.0")

            if ($verObj -lt $minimumVersion) {
                Start-Process "winget" -ArgumentList @(
                    "uninstall",
                    "--id", "Python.Python.$ver",
                    "--silent",
                    "--accept-package-agreements",
                    "--accept-source-agreements"
                ) -WindowStyle Hidden -Wait
            }
        } catch {}
    }
}

# -------------------------------
# 4. Clean PATH (remove old Python entries)
# -------------------------------
$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

$newPath = ($envPath -split ";" | Where-Object {
    $_ -notmatch "Python3\.(1[0-3]|14\.0|14\.1|14\.2|14\.3)"
}) -join ";"

[Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

# -------------------------------
# 5. Trigger Defender refresh (optional)
# -------------------------------
Start-Process "C:\Program Files\Windows Defender\MpCmdRun.exe" `
    -ArgumentList "-Scan -ScanType 1" `
    -WindowStyle Hidden