# ============================================
# Reliable .NET Detection Script
# Intune Enterprise Version
# ============================================

$LogPath = "C:\ProgramData\Company\Logs"
$LogFile = "$LogPath\DotNet-Detection.log"

if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "Starting detection..."

# Check if dotnet exists
$DotNet = Get-Command dotnet.exe -ErrorAction SilentlyContinue

if (!$DotNet) {
    Write-Log ".NET not installed"
    exit 1
}

# Get installed runtimes
$Runtimes = dotnet --list-runtimes 2>&1

Write-Log "Installed runtimes:"
Write-Log $Runtimes

# Required major versions
$RequiredVersions = @(
    "Microsoft.NETCore.App 8",
    "Microsoft.AspNetCore.App 8",
    "Microsoft.WindowsDesktop.App 8"
)

$Missing = $false

foreach ($Version in $RequiredVersions) {

    if ($Runtimes -match [regex]::Escape($Version)) {

        Write-Log "$Version FOUND"
    }
    else {

        Write-Log "$Version MISSING"
        $Missing = $true
    }
}

if ($Missing) {

    Write-Log "NON-COMPLIANT"
    exit 1
}
else {

    Write-Log "COMPLIANT"
    exit 0
}