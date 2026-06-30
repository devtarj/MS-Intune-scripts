# ====================================================
# Detect if .NET Runtime/ASP.NET Core/SDK updates are required
# Intune Proactive Remediation - Detection
# Runs as SYSTEM
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

Write-Log "===== Starting .NET Detection ====="

$WingetPath = Get-WingetPath

if (-not $WingetPath) {
    Write-Log "Winget executable not found under SYSTEM context"
    Write-Output "Non-Compliant: Winget not found"
    Exit 1
}

# Must match the package list in the remediation script exactly
$DotNetPackages = @(
    "Microsoft.DotNet.Runtime.8",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)

$UpdateNeeded = $false

foreach ($Package in $DotNetPackages) {
    try {
        $output = & $WingetPath upgrade `
            --id $Package `
            --exact `
            --source winget `
            --accept-source-agreements `
            --disable-interactivity 2>&1 | Out-String

        $outputClean = $output.Trim() -replace '\s+', ' '
        Write-Log "Check [$Package]: $outputClean"

        # Winget's "nothing to update" phrasing across recent versions
        if ($output -match "No applicable update found" -or
            $output -match "No available upgrade found" -or
            $output -match "No installed package found" -or
            $output -match "already installed") {
            Write-Log "$Package is up to date or not installed"
            continue
        }

        Write-Log "$Package has an available update"
        $UpdateNeeded = $true

    } catch {
        Write-Log "Error checking $Package : $_"
        $UpdateNeeded = $true
    }
}

Write-Log "===== Detection Finished - UpdateNeeded=$UpdateNeeded ====="

if ($UpdateNeeded) {
    Write-Output "Non-Compliant: One or more .NET components require an update"
    Exit 1
} else {
    Write-Output "Compliant: .NET components are up to date"
    Exit 0
}