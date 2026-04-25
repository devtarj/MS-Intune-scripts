# Ensure winget is available on the target device, if not, exit with code 1 to trigger retry in Intune
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    exit 1
}

# Install or upgrade to latest Python 3 silently
$process = Start-Process "winget" -ArgumentList @(
    "upgrade",
    "--id", "Python.Python.3",
    "--scope", "machine",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--disable-interactivity"
) -WindowStyle Hidden -Wait -PassThru

# If upgrade fails (not installed), install fresh
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

# Give system time to register install
Start-Sleep -Seconds 10

# Remove old Python versions via registry detection
$paths = @(
    "HKLM:\SOFTWARE\Python\PythonCore",
    "HKLM:\SOFTWARE\WOW6432Node\Python\PythonCore"
)

$versions = @()

foreach ($path in $paths) {
    if (Test-Path $path) {
        $versions += (Get-ChildItem $path | Select-Object -ExpandProperty PSChildName)
    }
}

$versions = $versions | Sort-Object -Unique

# Keep only latest version
if ($versions.Count -gt 1) {
    $latest = ($versions | Sort-Object {[version]$_} -Descending)[0]

    foreach ($ver in $versions) {
        if ($ver -ne $latest) {
            Write-Output "Removing old Python version: $ver"

            Start-Process "winget" -ArgumentList @(
                "uninstall",
                "--id", "Python.Python.$ver",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements"
            ) -WindowStyle Hidden -Wait
        }
    }
}

# Optional: Trigger Defender refresh (helps close findings faster)
Start-Process "C:\Program Files\Windows Defender\MpCmdRun.exe" `
    -ArgumentList "-Scan -ScanType 1" `
    -WindowStyle Hidden