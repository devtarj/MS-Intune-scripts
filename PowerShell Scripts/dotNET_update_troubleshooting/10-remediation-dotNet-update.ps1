# ====================================================
# Update .NET Runtime/ASP.NET Core/SDK Silently
# Intune Proactive Remediation - Remediation
# Runs as SYSTEM
# Date: 2026-07-02
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

function Get-WingetPath {
    # ---------------------------------------------------------------
    # Get-ChildItem on C:\Program Files\WindowsApps silently returns
    # nothing under the SYSTEM account due to Windows ACLs, even
    # though SYSTEM can execute files inside it.
    # cmd /c dir /b /s bypasses that PS-level restriction.
    # ---------------------------------------------------------------

    # Method 1: cmd dir (most reliable under SYSTEM)
    $cmdResult = cmd /c 'dir /b /s "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" 2>nul'
    if ($cmdResult) {
        $paths = ($cmdResult -split "`r?`n") | Where-Object { $_.Trim() -match "winget\.exe$" }
        if ($paths) {
            $found = ($paths | Select-Object -Last 1).Trim()
            Write-Log "Winget found via cmd dir: $found"
            return $found
        }
    }

    # Method 2: Get-AppxPackage fallback
    try {
        $pkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -AllUsers -ErrorAction Stop |
               Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg) {
            $p = Join-Path $pkg.InstallLocation "winget.exe"
            if (Test-Path $p) {
                Write-Log "Winget found via AppxPackage: $p"
                return $p
            }
        }
    } catch {
        Write-Log "AppxPackage lookup failed: $_"
    }

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

    # Clear per-package log files so previous runs don't confuse diagnostics
    $stdoutLog = "$LogFolder\${Package}_stdout.log"
    $stderrLog = "$LogFolder\${Package}_stderr.log"

    try {
        $proc = Start-Process `
            -FilePath $WingetPath `
            -ArgumentList @(
                "upgrade",
                "--id", $Package,
                "--exact",
                "--source", "winget",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--disable-interactivity"
            ) `
            -Wait -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError  $stderrLog

        # Log stdout/stderr output for diagnostics
        if (Test-Path $stdoutLog) {
            $out = Get-Content $stdoutLog -Raw -ErrorAction SilentlyContinue
            if ($out) { Write-Log "$Package stdout: $($out.Trim())" }
        }

        # winget exit codes:
        #   0            = success
        #   -1978335189  = 0x8A150109 - no applicable update found (not a failure)
        #   -1978335150  = 0x8A150132 - no installed package found (not a failure)
        $noUpdateCodes = @(-1978335189, -1978335150)

        if ($proc.ExitCode -eq 0) {
            Write-Log "$Package updated successfully"
        } elseif ($proc.ExitCode -in $noUpdateCodes) {
            Write-Log "$Package already up to date or not installed (exit $($proc.ExitCode))"
        } else {
            Write-Log "$Package FAILED with exit code $($proc.ExitCode)"
            $AnyFailure = $true
        }

    } catch {
        Write-Log "$Package threw an exception: $_"
        $AnyFailure = $true
    }
}

Write-Log "===== .NET Update Finished - AnyFailure=$AnyFailure ====="

if ($AnyFailure) {
    Exit 1
}

Exit 0