# ============================================================
# PowerShell 7 - Silent Latest Version Upgrade
# Designed for Microsoft Intune
# Runs in SYSTEM context
# ============================================================

$ErrorActionPreference = "Stop"

$LogPath = "C:\ProgramData\IntuneScripts"
$LogFile = Join-Path $LogPath "PowerShell-Upgrade.log"

# Create log directory
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

try {

    Write-Log "=============================================="
    Write-Log "PowerShell upgrade process started"

    # --------------------------------------------------------
    # Check Windows PowerShell version
    # --------------------------------------------------------

    Write-Log "Current Windows PowerShell version: $($PSVersionTable.PSVersion)"

    # --------------------------------------------------------
    # Locate WinGet
    # --------------------------------------------------------

    $WingetPath = $null

    $PossibleWingetPaths = @(
        "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )

    foreach ($Path in $PossibleWingetPaths) {

        $Found = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue |
                 Sort-Object FullName -Descending |
                 Select-Object -First 1

        if ($Found) {
            $WingetPath = $Found.FullName
            break
        }
    }

    # Try normal PATH lookup
    if (-not $WingetPath) {
        $WingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue

        if ($WingetCommand) {
            $WingetPath = $WingetCommand.Source
        }
    }

    if (-not $WingetPath) {
        Write-Log "ERROR: WinGet was not found."
        Write-Log "PowerShell upgrade cannot continue."
        exit 1
    }

    Write-Log "WinGet found at: $WingetPath"

    # --------------------------------------------------------
    # Check whether PowerShell 7 is installed
    # --------------------------------------------------------

    $PowerShell7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($PowerShell7) {

        $CurrentVersion = & $PowerShell7.Source -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null

        Write-Log "Installed PowerShell 7 version: $CurrentVersion"

    }
    else {

        Write-Log "PowerShell 7 is not currently installed."

    }

    # --------------------------------------------------------
    # Check for available PowerShell upgrade
    # --------------------------------------------------------

    Write-Log "Checking Microsoft WinGet repository for latest PowerShell..."

    $UpgradeCheck = & $WingetPath upgrade `
        --id Microsoft.PowerShell `
        --exact `
        --source winget `
        --accept-source-agreements `
        --disable-interactivity 2>&1

    $UpgradeCheck | Out-File -FilePath $LogFile -Append -Encoding UTF8

    # --------------------------------------------------------
    # Perform silent upgrade/install
    # --------------------------------------------------------

    Write-Log "Starting PowerShell upgrade/install..."

    $Arguments = @(
        "upgrade"
        "--id"
        "Microsoft.PowerShell"
        "--exact"
        "--source"
        "winget"
        "--silent"
        "--accept-source-agreements"
        "--accept-package-agreements"
        "--disable-interactivity"
    )

    $Process = Start-Process `
        -FilePath $WingetPath `
        -ArgumentList $Arguments `
        -Wait `
        -PassThru `
        -WindowStyle Hidden

    $ExitCode = $Process.ExitCode

    Write-Log "WinGet exit code: $ExitCode"

    # --------------------------------------------------------
    # Validate result
    # --------------------------------------------------------

    Start-Sleep -Seconds 5

    $PowerShell7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if ($PowerShell7) {

        $NewVersion = & $PowerShell7.Source `
            -NoProfile `
            -Command '$PSVersionTable.PSVersion.ToString()' 2>$null

        Write-Log "PowerShell 7 detected after operation: $NewVersion"

    }
    else {

        Write-Log "PowerShell 7 executable was not detected after operation."

    }

    # --------------------------------------------------------
    # Interpret WinGet result
    # --------------------------------------------------------

    # 0 = Success
    # 0x8A150014 = No applicable update
    # 0x8A150010 = Package already installed / no upgrade needed
    # --------------------------------------------------------

    if ($ExitCode -eq 0) {

        Write-Log "PowerShell upgrade completed successfully."
        exit 0

    }
    elseif ($ExitCode -eq 0x8A150014) {

        Write-Log "PowerShell is already at the latest available version."
        exit 0

    }
    elseif ($ExitCode -eq 0x8A150010) {

        Write-Log "PowerShell is already installed and no upgrade was required."
        exit 0

    }
    else {

        Write-Log "PowerShell upgrade returned exit code: $ExitCode"
        exit $ExitCode

    }

}
catch {

    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"

    exit 1
}