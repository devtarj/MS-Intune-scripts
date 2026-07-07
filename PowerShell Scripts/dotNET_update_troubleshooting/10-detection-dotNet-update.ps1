# ====================================================
# Update .NET Runtime / ASP.NET Core / SDK silently
# Intune Proactive Remediation – Remediation Script
# Runs as: SYSTEM
# Exit 0 = Remediation succeeded  → Intune: "Remediated"
# Exit 1 = Remediation failed     → Intune: "Failed"
#
# KEY FIX: Start-Process with -RedirectStandardOutput /
# -RedirectStandardError throws terminating exceptions
# under SYSTEM (no attached console). Replaced with
# direct invocation using & which is stable under SYSTEM.
# ====================================================

$LogFolder = "C:\ProgramData\Company\Logs"
$LogFile   = "$LogFolder\DotNetUpdate.log"

if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts [REMEDIATE] $Message"
}

function Get-WingetPath {
    # Method 1: cmd dir
    $raw = cmd /c 'dir /b /s "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" 2>nul'
    if ($raw) {
        $hit = ($raw -split "`r?`n") |
               Where-Object { $_.Trim() -match 'winget\.exe$' } |
               Select-Object -Last 1
        if ($hit) { return $hit.Trim() }
    }

    # Method 2: Get-AppxPackage (AllUsers)
    try {
        $pkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -AllUsers -ErrorAction Stop |
               Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg) {
            $p = Join-Path $pkg.InstallLocation "winget.exe"
            if (Test-Path $p) { return $p }
        }
    } catch { }

    return $null
}

Write-Log "===== Remediation started ====="

# winget needs LOCALAPPDATA for its source cache and settings,
# even when running as SYSTEM.
if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
    $env:LOCALAPPDATA = "$env:SystemRoot\System32\config\systemprofile\AppData\Local"
    Write-Log "Set LOCALAPPDATA to $env:LOCALAPPDATA"
}

$WingetPath = Get-WingetPath

if (-not $WingetPath) {
    Write-Log "ERROR: winget not found – cannot remediate"
    Exit 1
}

Write-Log "Winget: $WingetPath"

# Refresh the winget source before attempting any upgrades.
# This ensures the source cache is valid under the SYSTEM profile.
Write-Log "Refreshing winget sources..."
try {
    $srcOut = & $WingetPath source update --accept-source-agreements 2>&1 | Out-String
    Write-Log "Source update: $($srcOut.Trim() -replace '\s+',' ')"
} catch {
    Write-Log "Source update warning (non-fatal): $_"
}

# Must stay in sync with the detection script's package list
$Packages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

$AnyFailure = $false

foreach ($pkg in $Packages) {
    Write-Log "--- Processing $pkg"

    try {
        # Direct invocation with & avoids the Start-Process + redirection
        # crash that occurs when SYSTEM has no console attached.
        $raw = & $WingetPath upgrade `
            --id $pkg `
            --exact `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity 2>&1

        # $LASTEXITCODE is reliable here; capture it immediately
        $ec  = $LASTEXITCODE
        $out = ($raw | Out-String).Trim()

        Write-Log "[$pkg] exit=$ec output=$($out -replace '\s+',' ')"

        if ($ec -eq 0) {
            Write-Log "[$pkg] Updated successfully"
        }
        elseif ($out -match "No applicable update found|No available upgrade found|No installed package found|already installed") {
            # winget may exit 0 or non-zero for "nothing to do" depending on version;
            # checking output text is more reliable across versions.
            Write-Log "[$pkg] Already up to date – skipping"
        }
        else {
            Write-Log "[$pkg] FAILED (exit=$ec)"
            $AnyFailure = $true
        }

    } catch {
        Write-Log "[$pkg] Exception: $_"
        $AnyFailure = $true
    }
}

Write-Log "===== Remediation finished – AnyFailure=$AnyFailure ====="

if ($AnyFailure) { Exit 1 }
Exit 0