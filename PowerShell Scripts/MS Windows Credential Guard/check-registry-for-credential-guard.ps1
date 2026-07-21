<#
.SYNOPSIS
    Non-admin Credential Guard check. Run as a normal logged-in user, no elevation needed.

.NOTES
    This can only confirm the LIVE running state and registry config - it can't
    confirm Secure Boot status or read Intune's local execution logs, since
    those genuinely require admin rights. If this comes back inconclusive,
    you'll still need someone with local admin (or remote access, e.g. via
    Intune's "Run script" / remote help) to check those two pieces.
#>

Write-Host "=== Live Device Guard / Credential Guard state ===" -ForegroundColor Cyan
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop
    $dg | Select-Object SecurityServicesConfigured, SecurityServicesRunning, VirtualizationBasedSecurityStatus | Format-List

    switch ($dg.VirtualizationBasedSecurityStatus) {
        0 { Write-Host "VBS is OFF. Credential Guard cannot run until VBS is enabled/supported." -ForegroundColor Yellow }
        1 { Write-Host "VBS is enabled but NOT running yet (often means: pending reboot, or hardware can't start it)." -ForegroundColor Yellow }
        2 { Write-Host "VBS is running." -ForegroundColor Green }
    }

    if ($dg.SecurityServicesRunning -contains 1) {
        Write-Host "Credential Guard IS running." -ForegroundColor Green
    } else {
        Write-Host "Credential Guard is NOT running." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Could not query Win32_DeviceGuard: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Registry config (LsaCfgFlags) ===" -ForegroundColor Cyan
try {
    $flag = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LsaCfgFlags' -ErrorAction Stop
    Write-Host "LsaCfgFlags = $($flag.LsaCfgFlags)  (0/absent=disabled, 1=enabled+UEFI lock, 2=enabled no lock)"
}
catch {
    Write-Host "Could not read LsaCfgFlags (value may not be set, or access denied): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Note ===" -ForegroundColor Cyan
Write-Host "Secure Boot status and IME run history need admin rights to check on this device."