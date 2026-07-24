<#
.SYNOPSIS
    Enables Google Chrome auto-updates on Intune-enrolled Windows devices.

.DESCRIPTION
    Deploy via Intune > Devices > Scripts and remediations > Platform scripts.
    Runs as SYSTEM by default (leave "Run this script using the logged on
    credentials" set to No), so it does NOT require the signed-in user to
    have local admin rights. It DOES require HKLM write access, which the
    SYSTEM context already has.

    Actions:
      1. Ensures HKLM\SOFTWARE\Policies\Google\Update exists.
      2. Sets UpdateDefault = 1 (updates enabled by default for all Google apps).
      3. Sets Update{ChromeAppId} = 1 (explicitly enables updates for Chrome).
      4. Removes any policy that disables Chrome's in-app update check, if present.
      5. Ensures the gupdate / gupdatem services are set to Automatic and started.
      6. Kicks off an immediate update check if GoogleUpdate.exe is present.

.NOTES
    Exit 0  = success (or already compliant)
    Exit 1  = failure — check the log
#>

$ErrorActionPreference = 'Stop'

$LogDir  = 'C:\ProgramData\IntuneLogs'
$LogFile = Join-Path $LogDir 'Chrome-AutoUpdate-Enable.log'

function Write-Log {
    param([string]$Message)
    if (-not (Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp  $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

try {
    Write-Log '--- Starting Chrome auto-update enablement ---'

    $GoogleUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Google\Update'
    $ChromePolicyPath       = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
    $ChromeAppId            = '{8A69D345-D564-463c-AFF1-A69D9E530F96}'

    # 1. Ensure the Google Update policy key exists
    if (-not (Test-Path $GoogleUpdatePolicyPath)) {
        New-Item -Path $GoogleUpdatePolicyPath -Force | Out-Null
        Write-Log "Created registry key: $GoogleUpdatePolicyPath"
    }

    # 2. Enable updates by default for all Google apps under this policy set
    New-ItemProperty -Path $GoogleUpdatePolicyPath -Name 'UpdateDefault' `
        -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Log 'Set UpdateDefault = 1'

    # 3. Explicitly enable updates for Chrome (overrides UpdateDefault if it was set per-app)
    New-ItemProperty -Path $GoogleUpdatePolicyPath -Name "Update$ChromeAppId" `
        -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Log "Set Update$ChromeAppId = 1"

    # 4. Remove any policy that disables Chrome's own "check for updates" UI/behavior
    if (Test-Path $ChromePolicyPath) {
        $disableProp = Get-ItemProperty -Path $ChromePolicyPath -Name 'DisableAutoUpdateCheckDefaultValue' -ErrorAction SilentlyContinue
        if ($disableProp) {
            Remove-ItemProperty -Path $ChromePolicyPath -Name 'DisableAutoUpdateCheckDefaultValue' -Force
            Write-Log 'Removed DisableAutoUpdateCheckDefaultValue policy (was blocking update checks)'
        }
    }

    # 5. Ensure the Google Update services are set to Automatic and running
    foreach ($svcName in @('gupdate', 'gupdatem')) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.StartType -ne 'Automatic') {
                Set-Service -Name $svcName -StartupType Automatic
                Write-Log "Set $svcName startup type to Automatic"
            }
            if ($svc.Status -ne 'Running') {
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                Write-Log "Started service $svcName"
            }
        } else {
            Write-Log "Service $svcName not found (Chrome/Google Update may not be installed on this device yet)"
        }
    }

    # 6. Kick off an immediate update check, if GoogleUpdate.exe exists
    $googleUpdateExe = Get-ChildItem -Path 'C:\Program Files (x86)\Google\Update\GoogleUpdate.exe',
                                            'C:\Program Files\Google\Update\GoogleUpdate.exe' `
                                      -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($googleUpdateExe) {
        & $googleUpdateExe.FullName /ua /installsource scheduler
        Write-Log "Triggered immediate update check via $($googleUpdateExe.FullName)"
    } else {
        Write-Log 'GoogleUpdate.exe not found — skipping immediate update trigger (policy is still set for when it is installed)'
    }

    Write-Log '--- Completed successfully ---'
    Write-Output 'Chrome auto-update policy enabled successfully.'
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Output "Failed to enable Chrome auto-update: $($_.Exception.Message)"
    exit 1
}