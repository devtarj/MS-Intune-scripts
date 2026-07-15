<#
.SYNOPSIS
    Intune Proactive Remediation - OPTIONAL remediation script for Credential Guard.

.DESCRIPTION
    Sets the registry values that enable Credential Guard, then flags that a
    reboot is required for it to actually start running.

    ** Read before deploying **
    - Enabling Credential Guard has hardware/firmware prerequisites: UEFI
      (Secure Boot), virtualization extensions (Intel VT-x/AMD-V), and SLAT.
      Devices that don't meet these will NOT start Credential Guard even
      after this script runs, and the next detection pass will still show
      non-compliant.
    - This forces a reboot to take effect. Consider whether a silent
      registry push + eventual reboot fits your change-management process,
      or whether this is better rolled out via an Intune Endpoint Security
      "Account protection" profile, which handles prerequisite checks and
      user reboot prompts for you.
    - LsaCfgFlags = 2 enables Credential Guard WITHOUT UEFI lock (allows
      remote/scripted disable later, e.g. if you need to roll back).
      LsaCfgFlags = 1 enables WITH UEFI lock (more secure, but disabling
      afterward requires physical presence at boot). Adjust $EnableMode below.

.NOTES
    Runs in SYSTEM context under Intune. Exit 0 = script ran successfully
    (does not mean Credential Guard is running yet - that requires reboot
    and will be confirmed by the next detection run).
#>

$ErrorActionPreference = 'Stop'

# 1 = enable with UEFI lock (recommended for production, harder to reverse)
# 2 = enable without UEFI lock (easier to roll back, slightly less secure)
$EnableMode = 1

$logDir = 'C:\ProgramData\IntuneLogs'
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir 'CredentialGuard-Remediate.log'

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding utf8
}

Write-Log '--- Remediation run started ---'

try {
    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    $dgPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'

    if (-not (Test-Path $dgPath)) {
        New-Item -Path $dgPath -Force | Out-Null
    }

    # Turns on the virtualization-based security feature set.
    New-ItemProperty -Path $dgPath -Name 'EnableVirtualizationBasedSecurity' `
        -Value 1 -PropertyType DWord -Force | Out-Null

    # Requires Secure Boot at minimum (1); use 3 for Secure Boot + DMA protection.
    New-ItemProperty -Path $dgPath -Name 'RequirePlatformSecurityFeatures' `
        -Value 1 -PropertyType DWord -Force | Out-Null

    # This is the actual Credential Guard toggle.
    New-ItemProperty -Path $lsaPath -Name 'LsaCfgFlags' `
        -Value $EnableMode -PropertyType DWord -Force | Out-Null

    Write-Log "Registry values set. LsaCfgFlags = $EnableMode. Reboot required to take effect."
    Write-Output "Credential Guard registry keys configured (mode $EnableMode). Reboot required before it will show as running."
    exit 0
}
catch {
    Write-Log "Remediation failed: $($_.Exception.Message)"
    Write-Output "Failed to configure Credential Guard: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Log '--- Remediation run finished ---'
}