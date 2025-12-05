<#
Creation date: 04-Dec-2025
Last modified date: 05-Dec-2025
Version: 0.1
#>

# Simple Hardware Inventory Script
# Outputs inventory data as JSON

# ---------------------------
# Helper: Safe Property Getter
# ---------------------------
function Invoke-SafeCommand {
    param($script)
    try { & $script } catch { $null }
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
$ramGB = [Math]::Round(($compSys.TotalPhysicalMemory / 1GB), 2)

# ---------------------------
# Disk Info (Physical Disks)
# ---------------------------
$disks = Invoke-SafeCommand { 
    Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size, HealthStatus 
}

# Convert disk size to GB
$diskList = @()
if ($disks) {
    foreach ($d in $disks) {
        $diskList += [PSCustomObject]@{
            Name         = $d.FriendlyName
            Type         = $d.MediaType
            SizeGB       = [Math]::Round(($d.Size / 1GB), 2)
            HealthStatus = $d.HealthStatus
        }
    }
}

# ---------------------------
# Battery Info (If Laptop)
# ---------------------------
$battery = Invoke-SafeCommand { 
    Get-CimInstance -ClassName Win32_Battery | 
    Select-Object Status, EstimatedChargeRemaining, BatteryStatus
}

# ---------------------------
# Installed Applications
# (Simple list)
# ---------------------------
$apps = Invoke-SafeCommand {
    Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Select-Object DisplayName, DisplayVersion, Publisher
}

# ---------------------------
# Last Reboot
# ---------------------------
$lastBoot = ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))

# ---------------------------
# Build Inventory Object
# ---------------------------
$inventory = [PSCustomObject]@{
    DeviceName      = $env:COMPUTERNAME
    Manufacturer    = $compSys.Manufacturer
    Model           = $compSys.Model
    SerialNumber    = $bios.SerialNumber
    OSVersion       = $os.Version
    RAM_GB          = $ramGB
    LastReboot      = $lastBoot
    Disks           = $diskList
    Battery         = $battery
    InstalledApps   = $apps
}

# ---------------------------
# Output as JSON
# ---------------------------
$inventory | ConvertTo-Json -Depth 5

# --------------------------- END OF SCRIPT ---------------------------