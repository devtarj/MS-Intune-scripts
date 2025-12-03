<#
Creation date: 03-Dec-2025
Last modified date: 03-Dec-2025
Version: 0.1
#>

<#
Detection Script to check CPU uptime in windows devices
#>

param([int]$ThresholdHours=1)
$ErrorActionPreference='SilentlyContinue'

$lastResume=(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Power-Troubleshooter';Id=1} -MaxEvents 1 -ErrorAction SilentlyContinue).TimeCreated
$lastBoot=(Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime

$referenceStart = if($lastResume -and $lastBoot -and $lastResume -gt $lastBoot){ $lastResume }
                  elseif($lastResume){ $lastResume }
                  elseif($lastBoot){ $lastBoot } else { Get-Date }

$uptimeHours = [math]::Round(((Get-Date)-$referenceStart).TotalHours,2)
$source = if($referenceStart -eq $lastResume){ 'Since last resume' } elseif($referenceStart -eq $lastBoot){ 'Since boot' } else { 'Unknown (fallback)' }

$payload = [pscustomobject]@{ thresholdHours=$ThresholdHours; uptimeHours=$uptimeHours; lastBoot=$lastBoot; lastResume=$lastResume; referenceStart=$referenceStart; overThreshold=($uptimeHours -ge $ThresholdHours); source=$source }

$payload | ConvertTo-Json -Compress
if ($payload.overThreshold) { exit 1 } else { exit 0 }
