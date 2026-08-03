<#
.SYNOPSIS
    Remediation script - Microsoft Credential Guard (Intune Proactive Remediation)
.NOTES
    Runs as SYSTEM. Requires a reboot to fully activate - exits 3010 when one is needed,
    matching the convention used in your other remediation scripts.

    LsaCfgFlags:
      1 = Enabled with UEFI lock (can't be disabled remotely/via registry once set - requires physical presence)
      2 = Enabled without UEFI lock (can be disabled remotely by flipping the value back)
    Defaulting to 2 here so it's remotely reversible if a compatibility issue turns up.
    Change to 1 once you're confident in fleet-wide compatibility.
#>

$ErrorActionPreference = 'Stop'
$logDir  = 'C:\ProgramData\IntuneLogs'
$logFile = Join-Path $logDir 'CredentialGuard_Remediation.log'

if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
}

try {
    Write-Log "=== Remediation run started ==="

    # --- Hardware/firmware readiness check ---
    # Credential Guard needs Secure Boot at minimum. Bail out cleanly rather than
    # half-configuring a device that can't actually run it.
    $confirmation = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    if ($confirmation -ne $true) {
        Write-Log "FAIL: Secure Boot is not enabled/available on this device - Credential Guard cannot be enabled. Skipping."
        exit 1
    }
    Write-Log "Secure Boot confirmed enabled."

    # --- Set DeviceGuard VBS registry keys ---
    $dgPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
    New-ItemProperty -Path $dgPath -Name 'EnableVirtualizationBasedSecurity' -Value 1 -PropertyType DWord -Force | Out-Null
    # RequirePlatformSecurityFeatures: 1 = Secure Boot only, 3 = Secure Boot + DMA protection
    New-ItemProperty -Path $dgPath -Name 'RequirePlatformSecurityFeatures' -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Log "Set EnableVirtualizationBasedSecurity=1, RequirePlatformSecurityFeatures=1 under $dgPath"

    $hvciPath = "$dgPath\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
    New-ItemProperty -Path $hvciPath -Name 'Enabled' -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Log "Enabled HVCI scenario key under $hvciPath"

    # --- Set Credential Guard flag ---
    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    New-ItemProperty -Path $lsaPath -Name 'LsaCfgFlags' -Value 2 -PropertyType DWord -Force | Out-Null
    Write-Log "Set LsaCfgFlags=2 (enabled, without UEFI lock) under $lsaPath"

    # --- Enable the underlying Windows feature Credential Guard depends on ---
    # (Hyper-V hypervisor component - not the full Hyper-V management stack)
    $feature = Get-WindowsOptionalFeature -Online -FeatureName 'HypervisorPlatform' -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -ne 'Enabled') {
        Write-Log "Enabling HypervisorPlatform optional feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName 'HypervisorPlatform' -All -NoRestart | Out-Null
    } else {
        Write-Log "HypervisorPlatform feature already enabled or not applicable on this build."
    }

    Write-Log "Result: Configuration applied successfully - reboot required to activate."
    exit 3010
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}