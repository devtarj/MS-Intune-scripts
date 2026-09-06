# ============================================================
# Remediation: Purge all PyManager-managed Python runtimes and
# install a single, latest-only runtime. PATH is handled by PyManager
# itself via --configure.
# Intune Proactive Remediation - USER CONTEXT
# ============================================================

$logDir = "$env:LOCALAPPDATA\IntuneLogs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir "PyManagerUpdate-Remediation.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
    Write-Output $Message
}

try {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pyCmd) {
        $pyCmd = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WindowsApps\py.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $pyCmd) {
        Write-Log "FAILED: py (Python Install Manager) not found for this user."
        exit 1
    }

    $pyPath = if ($pyCmd.Source) { $pyCmd.Source } else { $pyCmd.FullName }
    Write-Log "py found at: $pyPath"

    # --- Purge every runtime PyManager currently manages ---
    # -y / --yes skips the interactive confirmation prompt (required for
    # unattended execution). --purge also cleans up shortcuts, registry
    # entries, and download caches - a full reset, not just the exe files.
    Write-Log "Purging all managed runtimes..."
    $purgeOutput = & $pyPath uninstall --purge -y 2>&1 | Out-String
    Write-Log $purgeOutput

    # --- Install latest stable ---
    # Bare tag "3" resolves to the newest stable 3.x release (prereleases
    # excluded unless specifically requested with a more specific tag).
    Write-Log "Installing latest stable Python 3.x..."
    $installOutput = & $pyPath install 3 -y 2>&1 | Out-String
    Write-Log $installOutput

    # --- Ensure PATH/alias configuration is applied ---
    # PyManager normally does this automatically on install, but running
    # --configure explicitly guarantees it after a fresh purge+install.
    Write-Log "Running configuration check..."
    $configOutput = & $pyPath install --configure -y 2>&1 | Out-String
    Write-Log $configOutput

    # --- Verify ---
    $verifyOutput = & $pyPath list 2>&1 | Out-String
    Write-Log "Post-remediation runtime list:"
    Write-Log $verifyOutput

    if ($verifyOutput -notmatch 'PythonCore') {
        Write-Log "REMEDIATION INCOMPLETE: No PythonCore runtime found after install attempt."
        exit 1
    }

    Write-Log "Remediation successful."
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}