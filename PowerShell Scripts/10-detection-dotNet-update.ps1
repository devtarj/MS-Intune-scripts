# ============================================
# .NET Runtime Detection Script
# Enterprise Grade - Intune Remediation
# ============================================

$LogPath = "C:\ProgramData\Company\Logs"
$LogFile = "$LogPath\DotNet-Detection.log"

# Create log folder
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "Starting .NET detection..."

# Ensure winget exists
$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (!$Winget) {
    Write-Log "Winget not found."
    exit 1
}

# IDs to check
$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.6",
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.DesktopRuntime.8"
)

$UpdatesNeeded = $false

foreach ($Package in $DotNetPackages) {

    Write-Log "Checking package: $Package"

    $Result = winget upgrade --id $Package --accept-source-agreements 2>&1

    if ($Result -match "available") {

        Write-Log "Update available for $Package"
        $UpdatesNeeded = $true
    }
    else {

        Write-Log "No updates for $Package"
    }
}

if ($UpdatesNeeded) {

    Write-Log "Device NON-COMPLIANT"
    exit 1
}
else {

    Write-Log "Device COMPLIANT"
    exit 0
}