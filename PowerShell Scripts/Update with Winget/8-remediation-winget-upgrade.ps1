<#
===========================================================================
 Enterprise Winget Auto-Upgrade Framework for Intune
===========================================================================

FEATURES
--------
✔ Silent updates
✔ Zero user disruption
✔ Safe installer filtering
✔ Detailed JSON audit logging
✔ Compliance reporting ready
✔ Retry logic
✔ Timeout protection
✔ Structured telemetry
✔ Supports Log Analytics ingestion
✔ SYSTEM-context compatible
✔ Hidden execution
✔ No forced reboot

RECOMMENDED DEPLOYMENT
----------------------
Intune Remediation Script
Run As: SYSTEM
64-bit PowerShell: YES
Schedule: Daily (2 AM recommended)

LOG LOCATION
------------
C:\ProgramData\WingetLogs

=========================================================================== 
#>

# =========================
# CONFIGURATION
# =========================

$ErrorActionPreference = "Continue"

$LogRoot = "C:\ProgramData\WingetLogs"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$JsonLog = "$LogRoot\WingetAudit_$TimeStamp.json"
$TextLog = "$LogRoot\WingetExecution_$TimeStamp.log"

$MaxRetries = 2
$InstallTimeoutMinutes = 15

# Safe installer types
$AllowedInstallerTypes = @(
    "msi",
    "msix",
    "appx",
    "burn",
    "nullsoft"
)

# Trusted EXE packages
# Add/remove based on your environment
$TrustedExePackages = @(
    "7zip.7zip",
    "Notepad++.Notepad++",
    "Microsoft.VisualStudioCode",
    "VideoLAN.VLC"
)

# Explicitly excluded/problematic packages
$ExcludedPackages = @(
    "Google.Chrome",
    "Oracle.JavaRuntimeEnvironment",
    "Microsoft.Edge"
)

# =========================
# PREP
# =========================

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

function Write-Log {
    param([string]$Message)

    $entry = "$(Get-Date -Format s) : $Message"

    Add-Content -Path $TextLog -Value $entry
}

Write-Log "========== Winget Enterprise Upgrade Started =========="

# =========================
# FIND WINGET
# =========================

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $winget) {

    $wingetPath = Get-ChildItem `
        "C:\Program Files\WindowsApps" `
        -Recurse `
        -Filter winget.exe `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($wingetPath) {
        $winget = $wingetPath.FullName
    }
    else {

        Write-Log "Winget not found."

        $failure = @{
            DeviceName = $env:COMPUTERNAME
            Status = "Failure"
            Reason = "Winget not found"
            Timestamp = (Get-Date)
        }

        $failure | ConvertTo-Json -Depth 5 | Out-File $JsonLog

        exit 1
    }
}
else {
    $winget = $winget.Source
}

Write-Log "Winget Path: $winget"

# =========================
# GET AVAILABLE UPDATES
# =========================

try {

    $upgradeData = winget upgrade `
        --output json `
        --accept-source-agreements |
        ConvertFrom-Json

}
catch {

    Write-Log "Failed retrieving upgrade list."

    exit 1
}

$Results = @()

if (-not $upgradeData.Sources.Packages) {

    Write-Log "No upgrades available."

    $Results += @{
        DeviceName = $env:COMPUTERNAME
        Status = "Compliant"
        Message = "No updates available"
        Timestamp = (Get-Date)
    }

    $Results | ConvertTo-Json -Depth 10 | Out-File $JsonLog

    exit 0
}

# =========================
# PROCESS PACKAGES
# =========================

foreach ($pkg in $upgradeData.Sources.Packages) {

    $PackageId = $pkg.PackageIdentifier
    $PackageName = $pkg.PackageName
    $CurrentVersion = $pkg.InstalledVersion
    $AvailableVersion = $pkg.AvailableVersion

    Write-Log "Processing package: $PackageName"

    # ----------------------------------
    # EXCLUDED PACKAGE CHECK
    # ----------------------------------

    if ($ExcludedPackages -contains $PackageId) {

        Write-Log "Skipped excluded package: $PackageName"

        $Results += @{
            DeviceName = $env:COMPUTERNAME
            PackageName = $PackageName
            PackageId = $PackageId
            CurrentVersion = $CurrentVersion
            AvailableVersion = $AvailableVersion
            Status = "Skipped"
            Reason = "Excluded package"
            Timestamp = (Get-Date)
        }

        continue
    }

    # ----------------------------------
    # GET INSTALLER DETAILS
    # ----------------------------------

    try {

        $details = winget show `
            --id $PackageId `
            --output json `
            --accept-source-agreements |
            ConvertFrom-Json

        $InstallerType = $details.Installers[0].InstallerType
    }
    catch {

        $InstallerType = "Unknown"
    }

    Write-Log "Installer Type: $InstallerType"

    # ----------------------------------
    # SILENT SAFETY VALIDATION
    # ----------------------------------

    $Allowed = $false

    if ($AllowedInstallerTypes -contains $InstallerType) {
        $Allowed = $true
    }

    if ($TrustedExePackages -contains $PackageId) {
        $Allowed = $true
    }

    if (-not $Allowed) {

        Write-Log "Skipped non-silent package: $PackageName"

        $Results += @{
            DeviceName = $env:COMPUTERNAME
            PackageName = $PackageName
            PackageId = $PackageId
            CurrentVersion = $CurrentVersion
            AvailableVersion = $AvailableVersion
            InstallerType = $InstallerType
            Status = "Skipped"
            Reason = "Non-approved installer type"
            Timestamp = (Get-Date)
        }

        continue
    }

    # =========================
    # INSTALL WITH RETRY
    # =========================

    $Attempt = 0
    $Success = $false

    while (($Attempt -lt $MaxRetries) -and (-not $Success)) {

        $Attempt++

        Write-Log "Installing $PackageName (Attempt $Attempt)"

        try {

            $Process = Start-Process `
                -FilePath $winget `
                -ArgumentList @(
                    "upgrade",
                    "--id", $PackageId,
                    "--silent",
                    "--disable-interactivity",
                    "--accept-package-agreements",
                    "--accept-source-agreements",
                    "--force"
                ) `
                -WindowStyle Hidden `
                -PassThru

            $Completed = $Process.WaitForExit($InstallTimeoutMinutes * 60 * 1000)

            if (-not $Completed) {

                Write-Log "Timeout reached for $PackageName"

                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue

                throw "Installation timeout"
            }

            if ($Process.ExitCode -eq 0) {

                Write-Log "Successfully updated $PackageName"

                $Results += @{
                    DeviceName = $env:COMPUTERNAME
                    PackageName = $PackageName
                    PackageId = $PackageId
                    CurrentVersion = $CurrentVersion
                    UpdatedVersion = $AvailableVersion
                    InstallerType = $InstallerType
                    Status = "Updated"
                    Attempt = $Attempt
                    Timestamp = (Get-Date)
                }

                $Success = $true
            }
            else {

                throw "Exit Code: $($Process.ExitCode)"
            }

        }
        catch {

            Write-Log "Failed installing $PackageName : $_"

            if ($Attempt -ge $MaxRetries) {

                $Results += @{
                    DeviceName = $env:COMPUTERNAME
                    PackageName = $PackageName
                    PackageId = $PackageId
                    CurrentVersion = $CurrentVersion
                    AvailableVersion = $AvailableVersion
                    InstallerType = $InstallerType
                    Status = "Failed"
                    Error = $_.ToString()
                    Attempt = $Attempt
                    Timestamp = (Get-Date)
                }
            }
        }
    }
}

# =========================
# SAVE AUDIT LOG
# =========================

$Results | ConvertTo-Json -Depth 10 | Out-File $JsonLog -Encoding utf8

Write-Log "JSON audit log written to: $JsonLog"

# =========================
# SUMMARY
# =========================

$UpdatedCount = ($Results | Where-Object {$_.Status -eq "Updated"}).Count
$SkippedCount = ($Results | Where-Object {$_.Status -eq "Skipped"}).Count
$FailedCount = ($Results | Where-Object {$_.Status -eq "Failed"}).Count

Write-Log "Updated: $UpdatedCount"
Write-Log "Skipped: $SkippedCount"
Write-Log "Failed : $FailedCount"

Write-Log "========== Winget Enterprise Upgrade Completed =========="

# =========================
# EXIT CODE
# =========================

if ($FailedCount -gt 0) {
    exit 1
}
else {
    exit 0
}