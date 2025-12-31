<#
Creation date: 05-Dec-2025
Last modified date: 11-Dec-2025
Version: 0.1
#>

# Simple Hardware Inventory Script
# Outputs inventory data as JSON

# ===========================
# Intune-Friendly Inventory Script
# Outputs a single JSON object
# ===========================

# Stop noisy non-terminating errors from cluttering output
$ErrorActionPreference = 'SilentlyContinue'

# Simple wrapper to safely run commands
function Invoke-Safe {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock
    )
    try {
        & $ScriptBlock
    }
    catch {
        # Return $null on failure, keep script going
        $null
    }
}

# ---------------------------
# Basic System Information
# ---------------------------

$compSys = Get-CimInstance -ClassName CIM_ComputerSystem
$bios    = Get-CimInstance -ClassName Win32_BIOS
$os      = Get-CimInstance -ClassName Win32_OperatingSystem

# ---------------------------
# RAM
# ---------------------------
$ramGB = if ($compSys.TotalPhysicalMemory) {
    [Math]::Round(($compSys.TotalPhysicalMemory / 1GB), 2)
}
else {
    $null
}

# ---------------------------
# Disk Info (Physical Disks)
# ---------------------------
$disks = Invoke-Safe {
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size, HealthStatus
}

$diskList = @()
if ($disks) {
    foreach ($d in $disks) {
        $diskList += [PSCustomObject]@{
            Name         = $d.FriendlyName
            Type         = $d.MediaType
            SizeGB       = if ($d.Size) { [Math]::Round(($d.Size / 1GB), 2) } else { $null }
            HealthStatus = $d.HealthStatus
        }
    }
}

# ---------------------------
# Battery Info (If Laptop)
# ---------------------------
$battery = Invoke-Safe {
    Get-CimInstance -ClassName Win32_Battery |
        Select-Object Status, EstimatedChargeRemaining, BatteryStatus
}

# ---------------------------
# Installed Applications
#  - Includes 32-bit and 64-bit
#  - Filters out entries with no DisplayName
# ---------------------------
$apps = Invoke-Safe {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
        Select-Object DisplayName, DisplayVersion, Publisher
}

# ---------------------------
# Last Reboot
# ---------------------------
$lastBoot = $null
if ($os.LastBootUpTime) {
    $lastBoot = [System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime).ToString('o')  # ISO 8601
}

# ---------------------------
# Build Inventory Object
# (Flat enough for Intune/Log Analytics)
# ---------------------------
$inventory = [PSCustomObject]@{
    DeviceName   = $env:COMPUTERNAME
    Manufacturer = $compSys.Manufacturer
    Model        = $compSys.Model
    SerialNumber = $bios.SerialNumber
    OSVersion    = $os.Version
    RAM_GB       = $ramGB
    LastReboot   = $lastBoot
    Disks        = $diskList
    Battery      = $battery
    InstalledApps = $apps
}

# --------------------------
# Output as JSON (single object)
# --------------------------
$inventory | ConvertTo-Json -Depth 5


# --------------------------- END OF SCRIPT ---------------------------