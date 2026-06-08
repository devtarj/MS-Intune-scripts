# ====================================================
# Update .NET Runtime Silently
# Intune Proactive Remediation
# Runs as SYSTEM
# ====================================================

$LogFolder = "C:\ProgramData\Company\Logs"
$LogFile = "$LogFolder\DotNetUpdate.log"

if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content -Path $LogFile -Value "$Timestamp - $Message"
}

Write-Log "===== Starting .NET Update ====="

# Locate Winget

$Winget = Get-ChildItem `
    "C:\Program Files\WindowsApps" `
    -Recurse `
    -Filter winget.exe `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (!$Winget) {
    Write-Log "Winget not found"
    Exit 1
}

$WingetPath = $Winget.FullName

Write-Log "Winget found at $WingetPath"

# Runtime IDs to update

$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

foreach ($Package in $DotNetPackages) {

    Write-Log "Processing $Package"

    try {

        Start-Process `
            -FilePath $WingetPath `
            -ArgumentList @(
                "upgrade",
                "--id", $Package,
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements"
            ) `
            -Wait `
            -NoNewWindow

        Write-Log "$Package completed"

    }
    catch {

        Write-Log "$Package failed : $_"

    }
}

Write-Log "===== .NET Update Finished ====="

Exit 0