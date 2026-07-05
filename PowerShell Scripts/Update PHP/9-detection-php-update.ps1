# =====================================================
# PHP Detection Script for Intune Remediation
# =====================================================

$ErrorActionPreference = "SilentlyContinue"

function Write-OutputAndExit {
    param (
        [string]$Message,
        [int]$Code
    )

    Write-Output $Message
    exit $Code
}

# =====================================================
# Detect PHP
# =====================================================

$PhpExe = $null

$SearchPaths = @(
    "C:\PHP\php.exe",
    "C:\xampp\php\php.exe"
)

foreach ($Path in $SearchPaths) {
    if (Test-Path $Path) {
        $PhpExe = $Path
        break
    }
}

if (!$PhpExe) {
    $Cmd = Get-Command php.exe -ErrorAction SilentlyContinue
    if ($Cmd) {
        $PhpExe = $Cmd.Source
    }
}

if (!$PhpExe) {
    Write-OutputAndExit "PHP not installed." 0
}

# =====================================================
# Installed Version
# =====================================================

try {
    $InstalledVersionOutput = & $PhpExe -v
    $InstalledVersion = ($InstalledVersionOutput[0] -split " ")[1]
}
catch {
    Write-OutputAndExit "Unable to determine installed PHP version." 1
}

# =====================================================
# Latest Version
# =====================================================

try {
    $ReleaseData = Invoke-RestMethod -Uri "https://www.php.net/releases/index.php?json&version=8"

    $LatestVersion = $ReleaseData.PSObject.Properties.Name |
        Sort-Object {[version]$_} -Descending |
        Select-Object -First 1
}
catch {
    Write-OutputAndExit "Unable to determine latest PHP version." 1
}

# =====================================================
# Compare
# =====================================================

if ([version]$InstalledVersion -lt [version]$LatestVersion) {
    Write-OutputAndExit "Outdated PHP detected. Installed: $InstalledVersion Latest: $LatestVersion" 1
}
else {
    Write-OutputAndExit "PHP compliant. Installed: $InstalledVersion" 0
}