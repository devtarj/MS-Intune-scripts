$logDir = "C:\ProgramData\WingetLogs"
$logFile = "$logDir\upgrade_$(Get-Date -Format yyyyMMdd_HHmmss).json"

New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Safe installer types
$allowedInstallers = @("msi","msix","appx")

# Known safe EXE packages (customize this)
$trustedExe = @(
    "Microsoft.VisualStudioCode",
    "7zip.7zip",
    "Notepad++.Notepad++"
)

$results = @()

# Get upgrade list in JSON
$upgradeJson = winget upgrade --output json --accept-source-agreements | ConvertFrom-Json

foreach ($pkg in $upgradeJson.Sources.Packages) {

    $id = $pkg.PackageIdentifier
    $name = $pkg.PackageName

    # Get package details
    $details = winget show --id $id --output json --accept-source-agreements | ConvertFrom-Json

    $installerType = $details.Installers[0].InstallerType

    $isAllowed = $false

    if ($allowedInstallers -contains $installerType) {
        $isAllowed = $true
    }
    elseif ($trustedExe -contains $id) {
        $isAllowed = $true
    }

    if (-not $isAllowed) {
        $results += @{
            Name = $name
            Id = $id
            Status = "Skipped"
            Reason = "Non-silent installer ($installerType)"
        }
        continue
    }

    try {
        Start-Process winget `
            -ArgumentList "upgrade --id $id --silent --accept-package-agreements --accept-source-agreements --disable-interactivity --force" `
            -WindowStyle Hidden `
            -Wait

        $results += @{
            Name = $name
            Id = $id
            Status = "Updated"
        }
    }
    catch {
        $results += @{
            Name = $name
            Id = $id
            Status = "Failed"
            Error = $_.Exception.Message
        }
    }
}

# Save structured log
$results | ConvertTo-Json -Depth 5 | Out-File $logFile -Encoding utf8

exit 0