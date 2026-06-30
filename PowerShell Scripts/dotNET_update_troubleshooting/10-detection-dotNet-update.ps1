# ====================================================
# Detect if .NET Runtime/ASP.NET Core/SDK updates are required
# Intune Proactive Remediation - Detection
# Runs as SYSTEM
# Date: 2026-06-30
# ====================================================

$LogFolder = "C:\ProgramData\Company\Logs"
$LogFile   = "$LogFolder\DotNetUpdate.log"

if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Timestamp [DETECT] - $Message"
}

# ----------------------------------------------------
# Locate winget.exe reliably under the SYSTEM account.
# Get-Command winget.exe / "winget" alone will NOT work
# as SYSTEM because the App Execution Alias only exists
# in the interactive user's PATH, not SYSTEM's.
# ----------------------------------------------------
function Get-WingetPath {
    $candidate = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -like "Microsoft.DesktopAppInstaller_*" } |
        Sort-Object { [version]($_.Directory.Name -replace '.*_(\d+\.\d+\.\d+\.\d+)_.*','$1') } -Descending |
        Select-Object -First 1

    if ($candidate) { return $candidate.FullName }
    return $null
}

Write-Log "===== Starting .NET Detection ====="

$WingetPath = Get-WingetPath

if (-not $WingetPath) {
    Write-Log "Winget executable not found under SYSTEM context"
    Write-Output "Non-Compliant: Winget not found"
    Exit 1
}

Write-Log "Winget found at $WingetPath"

# Must match the package list in the remediation script exactly
$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

$UpdateNeeded = $false

foreach ($Package in $DotNetPackages) {
    try {
        $output = & $WingetPath upgrade --id $Package --exact --accept-source-agreements --disable-interactivity 2>&1 |
            Out-String

        Write-Log "Check for $Package : $($output.Trim() -replace '\s+',' ')"

        # Winget's "nothing to update" phrasing varies slightly by version/locale,
        # so match on the stable substrings it has used across recent releases.
        if ($output -match "No applicable update found" -or
            $output -match "No available upgrade found" -or
            $output -match "No installed package found") {
            Write-Log "$Package is up to date or not installed - skipping"
            continue
        }

        Write-Log "$Package has an available update"
        $UpdateNeeded = $true
    }
    catch {
        Write-Log "Error checking $Package : $_"
        $UpdateNeeded = $true
    }
}

Write-Log "===== Detection Finished - UpdateNeeded=$UpdateNeeded ====="

if ($UpdateNeeded) {
    Write-Output "Non-Compliant: One or more .NET components require an update"
    Exit 1
}
else {
    Write-Output "Compliant: .NET components are up to date"
    Exit 0
}