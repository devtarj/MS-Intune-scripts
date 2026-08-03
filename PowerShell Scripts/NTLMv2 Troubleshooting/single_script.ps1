<#
.SYNOPSIS
    Enforces NTLMv2-only authentication and disables legacy LM/NTLMv1.
.NOTES
    Intended for Intune Proactive Remediation (runs as SYSTEM).
    Does NOT set Restrict NTLM Traffic to "Deny All" — that would also
    block NTLMv2, not just legacy NTLM. Remove that block only if you
    intend to force Kerberos-only and have confirmed nothing still
    depends on NTLMv2.
#>

$ErrorActionPreference = 'Stop'
$logPath = "C:\ProgramData\IntuneLogs"
if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $logPath "Set-NTLMv2Only.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
    Write-Output $line
}

try {
    # LAN Manager Authentication Level
    # 5 = Send NTLMv2 response only. Refuse LM & NTLM.
    $lsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
    if (-not (Test-Path $lsaPath)) { New-Item -Path $lsaPath -Force | Out-Null }

    New-ItemProperty -Path $lsaPath -Name "LmCompatibilityLevel" -Value 5 -PropertyType DWord -Force | Out-Null
    Write-Log "Set LmCompatibilityLevel = 5 (NTLMv2 only, LM/NTLMv1 refused)"

    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}