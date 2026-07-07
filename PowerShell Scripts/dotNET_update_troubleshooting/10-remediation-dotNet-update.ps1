# ====================================================
# Detect if .NET Runtime / ASP.NET Core / SDK need updating
# Intune Proactive Remediation – Detection Script
# Runs as: SYSTEM
# Exit 0 = Compliant   ("Without issues" in Intune)
# Exit 1 = Non-compliant ("With issues" in Intune → triggers remediation)
# ====================================================

$LogFolder = "C:\ProgramData\Company\Logs"
$LogFile   = "$LogFolder\DotNetUpdate.log"

if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$ts [DETECT] $Message"
}

# ---------------------------------------------------------------
# SYSTEM has no console PATH alias for winget.
# SYSTEM also cannot list C:\Program Files\WindowsApps via
# Get-ChildItem due to ACLs, so we use cmd /c dir instead.
# ---------------------------------------------------------------
function Get-WingetPath {
    # Method 1: cmd dir (bypasses PowerShell ACL restriction on WindowsApps)
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

Write-Log "===== Detection started ====="

# winget needs LOCALAPPDATA even as SYSTEM (for source cache / settings)
if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
    $env:LOCALAPPDATA = "$env:SystemRoot\System32\config\systemprofile\AppData\Local"
    Write-Log "Set LOCALAPPDATA to $env:LOCALAPPDATA"
}

$WingetPath = Get-WingetPath

if (-not $WingetPath) {
    Write-Log "ERROR: winget not found"
    Write-Output "Non-Compliant: Winget not found"
    Exit 1
}

Write-Log "Winget: $WingetPath"

# Must stay in sync with the remediation script's package list
$Packages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

$UpdateNeeded = $false

foreach ($pkg in $Packages) {
    try {
        $raw = & $WingetPath upgrade `
            --id $pkg `
            --exact `
            --accept-source-agreements `
            --disable-interactivity 2>&1

        $out = ($raw | Out-String).Trim()
        Write-Log "[$pkg] $($out -replace '\s+',' ')"

        # These phrases all mean "nothing to do" across winget versions
        $upToDate = $out -match "No applicable update found|No available upgrade found|No installed package found|already installed"

        if (-not $upToDate) {
            Write-Log "[$pkg] UPDATE AVAILABLE"
            $UpdateNeeded = $true
        }
    } catch {
        Write-Log "[$pkg] Exception: $_"
        $UpdateNeeded = $true
    }
}

Write-Log "===== Detection finished – UpdateNeeded=$UpdateNeeded ====="

if ($UpdateNeeded) {
    Write-Output "Non-Compliant: One or more .NET components require an update"
    Exit 1
}

Write-Output "Compliant: All .NET components are up to date"
Exit 0