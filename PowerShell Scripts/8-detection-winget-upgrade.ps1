$ErrorActionPreference = "SilentlyContinue"

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) { exit 0 }

$upgrades = winget upgrade --accept-source-agreements | Out-String

# Filter lines with actual packages (ignore headers)
$lines = $upgrades -split "`n" | Where-Object { $_ -match "^\S" }

# If no upgrades → compliant
if ($lines.Count -eq 0) {
    exit 0
}

# If upgrades exist → trigger remediation
exit 1