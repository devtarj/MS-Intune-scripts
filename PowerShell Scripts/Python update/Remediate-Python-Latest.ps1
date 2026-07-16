<#
.SYNOPSIS
    Intune Proactive Remediation - Remediation Script
    Downloads the latest stable Python installer directly from python.org
    and installs it silently for all users. Runs as SYSTEM.

    Does NOT use winget - same reasoning as the detection script.

    NOTE: Installs the new version alongside any existing one rather than
    uninstalling the old version first, so this cannot break anything that
    depends on the previously installed Python. Detection will report
    compliant once the newer version is present, since it checks the
    HIGHEST installed version.

.EXIT CODES
    0 = Success
    1 = Failure
#>

$logPath = "C:\ProgramData\IntuneLogs\PythonUpdate.log"
New-Item -Path (Split-Path $logPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logPath -Append -Encoding utf8
}

try {
    Write-Log "=== Remediation started (python.org direct installer method) ==="
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # --- Get latest stable version from endoflife.date API ---
    try {
        $releases = Invoke-RestMethod -Uri "https://endoflife.date/api/python.json" -UseBasicParsing -TimeoutSec 30
    }
    catch {
        Write-Log "ERROR: Failed to query endoflife.date API: $($_.Exception.Message)"
        exit 1
    }

    $stableLatest = $releases |
        Where-Object { $_.latest -match '^\d+\.\d+\.\d+$' } |
        ForEach-Object { [version]$_.latest } |
        Sort-Object -Descending |
        Select-Object -First 1

    if (-not $stableLatest) {
        Write-Log "ERROR: Could not parse latest version from API response."
        exit 1
    }
    $latestVersion = $stableLatest.ToString()
    Write-Log "Target version: $latestVersion"

    # --- Download official installer (64-bit) ---
    $installerUrl  = "https://www.python.org/ftp/python/$latestVersion/python-$latestVersion-amd64.exe"
    $installerPath = Join-Path $env:TEMP "python-$latestVersion-amd64.exe"

    Write-Log "Downloading from $installerUrl"
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -TimeoutSec 300
    }
    catch {
        Write-Log "ERROR: Download failed: $($_.Exception.Message)"
        exit 1
    }

    if (-not (Test-Path $installerPath)) {
        Write-Log "ERROR: Installer not found on disk after download attempt."
        exit 1
    }
    Write-Log "Download complete: $installerPath ($((Get-Item $installerPath).Length) bytes)"

    # --- Silent install ---
    # InstallAllUsers=1  -> installs to Program Files, registers under HKLM (matches detection script)
    # PrependPath=1      -> adds this version to PATH ahead of others
    # Include_test=0     -> skip the bundled test suite, smaller footprint
    # No stdout/stderr redirection on Start-Process - that has crashed under SYSTEM before.
    $installArgs = "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
    Write-Log "Running installer silently with args: $installArgs"

    $proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
    $exitCode = $proc.ExitCode
    Write-Log "Installer exit code: $exitCode"

    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    # Python.org installer: 0 = success, 3010 = success but reboot recommended
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        Write-Log "Python $latestVersion installed successfully."
        exit 0
    }
    else {
        Write-Log "Installer returned non-zero exit code: $exitCode"
        exit 1
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}