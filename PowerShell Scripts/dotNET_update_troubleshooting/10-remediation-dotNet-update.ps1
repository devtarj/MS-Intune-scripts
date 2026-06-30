# ====================================================
# Update .NET Runtime/ASP.NET Core/SDK Silently
# Intune Proactive Remediation - Remediation
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
    Add-Content -Path $LogFile -Value "$Timestamp [REMEDIATE] - $Message"
}

# Same resolution logic as the detection script - keeping these identical
# is what stops detection and remediation from disagreeing with each other.
function Get-WingetPath {
    $candidate = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" `
        -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -like "Microsoft.DesktopAppInstaller_*" } |
        Sort-Object { [version]($_.Directory.Name -replace '.*_(\d+\.\d+\.\d+\.\d+)_.*','$1') } -Descending |
        Select-Object -First 1

    if ($candidate) { return $candidate.FullName }
    return $null
}

Write-Log "===== Starting .NET Update ====="

$WingetPath = Get-WingetPath

if (-not $WingetPath) {
    Write-Log "Winget executable not found under SYSTEM context - cannot remediate"
    Exit 1
}

Write-Log "Winget found at $WingetPath"

# Must match the package list in the detection script exactly
$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

$AnyFailure = $false

foreach ($Package in $DotNetPackages) {

    Write-Log "Processing $Package"

    try {
        $proc = Start-Process `
            -FilePath $WingetPath `
            -ArgumentList @(
                "upgrade",
                "--id", $Package,
                "--exact",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--disable-interactivity"
            ) `
            -Wait -NoNewWindow -PassThru `
            -RedirectStandardOutput "$LogFolder\${Package}_stdout.log" `
            -RedirectStandardError  "$LogFolder\${Package}_stderr.log"

        # winget's "no applicable update" exit code is harmless;
        # only treat genuine non-zero errors as a real failure.
        if ($proc.ExitCode -eq 0) {
            Write-Log "$Package completed successfully"
        }
        elseif ($proc.ExitCode -eq -1978335189) {
            # No applicable update found - nothing to do, not a failure
            Write-Log "$Package already up to date"
        }
        else {
            Write-Log "$Package failed with exit code $($proc.ExitCode)"
            $AnyFailure = $true
        }
    }
    catch {
        Write-Log "$Package failed : $_"
        $AnyFailure = $true
    }
}

Write-Log "===== .NET Update Finished - AnyFailure=$AnyFailure ====="

if ($AnyFailure) {
    # Report failure honestly so Intune reflects the real remediation state
    # instead of silently masking errors with Exit 0.
    Exit 1
}

Exit 0