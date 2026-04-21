# Ensure winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    exit 1
}

# Run completely hidden
$process = Start-Process "winget" -ArgumentList @(
    "upgrade",
    "--id", "Python.Python.3",
    "--scope", "machine",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--disable-interactivity"
) -WindowStyle Hidden -Wait -PassThru

# If upgrade failed, attempt install
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

# Wait for two minutes to ensure the installation is complete before updating Defender signatures
Start-Sleep -Seconds 120
Start-Process "C:\Program Files\Windows Defender\MpCmdRun.exe" -ArgumentList "-SignatureUpdate"