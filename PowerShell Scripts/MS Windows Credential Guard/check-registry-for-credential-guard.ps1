<#
.SYNOPSIS
    Run locally (as admin) on an affected device to see what's actually going on -
    live Credential Guard state, plus when the remediation last executed locally.
#>

Write-Host "=== Live Device Guard / Credential Guard state ===" -ForegroundColor Cyan
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' |
    Select-Object SecurityServicesConfigured, SecurityServicesRunning, VirtualizationBasedSecurityStatus |
    Format-List

Write-Host "`n=== Registry state ===" -ForegroundColor Cyan
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LsaCfgFlags' -ErrorAction SilentlyContinue |
    Select-Object LsaCfgFlags

Write-Host "`n=== Hardware prerequisite check ===" -ForegroundColor Cyan
$confirmation = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
Write-Host "Secure Boot enabled: $confirmation"

$vbsStatus = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard'
Write-Host "VBS status (0=off,1=enabled not running,2=running): $($vbsStatus.VirtualizationBasedSecurityStatus)"

Write-Host "`n=== Scheduled task last run (Intune remediation execution) ===" -ForegroundColor Cyan
Get-ScheduledTask -TaskPath "\Microsoft\Intune\Management Extension\Policies\*" -ErrorAction SilentlyContinue |
    Get-ScheduledTaskInfo |
    Select-Object TaskName, LastRunTime, LastTaskResult, NextRunTime |
    Format-Table -AutoSize

Write-Host "`n=== IME check-in / recent log entries ===" -ForegroundColor Cyan
$logPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
if (Test-Path $logPath) {
    Get-Content $logPath -Tail 20
} else {
    Write-Host "IME log not found at expected path."
}