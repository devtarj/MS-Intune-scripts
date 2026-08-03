<#
.SYNOPSIS
    Detection script - Microsoft Credential Guard (Intune Proactive Remediation)
.NOTES
    Runs as SYSTEM. Exit 0 = compliant (no remediation needed). Exit 1 = needs remediation.
#>

$ErrorActionPreference = 'Stop'
$logDir  = 'C:\ProgramData\IntuneLogs'
$logFile = Join-Path $logDir 'CredentialGuard_Detection.log'

if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
}

try {
    Write-Log "=== Detection run started ==="

    # 1. Check the config registry values are set as desired
    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    $dgPath  = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'

    $lsaCfgFlags = (Get-ItemProperty -Path $lsaPath -Name 'LsaCfgFlags' -ErrorAction SilentlyContinue).LsaCfgFlags
    $vbs         = (Get-ItemProperty -Path $dgPath -Name 'EnableVirtualizationBasedSecurity' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity

    Write-Log "LsaCfgFlags = $lsaCfgFlags | EnableVirtualizationBasedSecurity = $vbs"

    $configOk = ($lsaCfgFlags -in 1,2) -and ($vbs -eq 1)

    # 2. Check it's actually RUNNING, not just configured (config can be pending a reboot)
    $dgInstance = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    $runningServices = $dgInstance.SecurityServicesRunning
    # SecurityServicesRunning value 1 = Credential Guard
    $isRunning = $runningServices -contains 1

    Write-Log "SecurityServicesRunning = $($runningServices -join ',') | isRunning = $isRunning"

    if ($configOk -and $isRunning) {
        Write-Log "Result: COMPLIANT - Credential Guard configured and running"
        exit 0
    }
    elseif ($configOk -and -not $isRunning) {
        # Configured but not yet running - almost always means "pending reboot".
        # Treat as compliant so we don't force endless remediation loops/reboots;
        # remediation script logs this state distinctly if you want to track it separately.
        Write-Log "Result: COMPLIANT (config set, pending reboot to activate)"
        exit 0
    }
    else {
        Write-Log "Result: NON-COMPLIANT - remediation required"
        exit 1
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}