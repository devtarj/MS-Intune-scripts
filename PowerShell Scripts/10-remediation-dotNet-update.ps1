# ============================================
# .NET Runtime Remediation Script
# Enterprise Grade - Silent Updater
# ============================================

$LogPath = "C:\ProgramData\Company\Logs"
$LogFile = "$LogPath\DotNet-Remediation.log"

# Create log folder
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "Starting .NET remediation..."

# Ensure winget exists
$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (!$Winget) {

    Write-Log "Winget not found. Exiting."
    exit 1
}

# Packages to update
$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.6",
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.DesktopRuntime.8"
)

foreach ($Package in $DotNetPackages) {

    try {

        Write-Log "Updating $Package"

        winget upgrade `
            --id $Package `
            --silent `
            --scope machine `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity `
            --force `
            2>&1 | Out-File -Append $LogFile

        Write-Log "$Package updated successfully"

    }
    catch {

        Write-Log "FAILED updating ${Package}: $_"
    }
}

Write-Log "Remediation completed."

exit 0