<#
.SYNOPSIS
    Diagnostic - locates every php.exe on a device by scanning fixed drives.
    Run manually (e.g. via Intune "Run script" or locally as SYSTEM/admin) on a
    device where Defender flags PHP but the Proactive Remediation detection
    script reports "not installed" - this tells you the actual path so you can
    add it to $SearchRoots in Detect-PHPVersion.ps1 / Remediate-PHPVersion.ps1.

.NOTES
    This is a full-drive search (excludes Windows/WinSxS/node_modules for speed)
    so it's slower than the normal detection script - expect it to take a couple
    of minutes depending on disk size. Not intended to run as a recurring
    Proactive Remediation - it's a targeted, run-once troubleshooting tool.
#>

$ErrorActionPreference = 'Continue'
$LogFile = "C:\ProgramData\IntuneLogs\PHP-Diagnostic.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    Write-Host $line
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

Write-Log "=== PHP diagnostic scan starting ==="

# --- 1. Known common install roots (fast check first) -------------------------
$knownRoots = @(
    "C:\php",
    "C:\Program Files\PHP",
    "C:\Program Files (x86)\PHP",
    "C:\tools\php",
    "C:\xampp\php",
    "C:\wamp64\bin\php",
    "C:\wamp\bin\php",
    "C:\laragon\bin\php",
    "C:\inetpub\php",
    "D:\xampp\php",
    "D:\wamp64\bin\php"
)

Write-Log "--- Checking known common locations ---"
foreach ($root in $knownRoots) {
    if (Test-Path $root) {
        $hits = cmd /c "dir /b /s `"$root\php.exe`" 2>nul"
        if ($hits) {
            foreach ($hit in ($hits -split "`r`n" | Where-Object { $_ -match '\S' })) {
                Write-Log "FOUND (known root): $hit"
            }
        }
    }
}

# --- 2. PATH ---------------------------------------------------------------------
Write-Log "--- Checking PATH ---"
$whereResult = cmd /c "where php.exe 2>nul"
if ($whereResult) {
    foreach ($hit in ($whereResult -split "`r`n" | Where-Object { $_ -match '\S' })) {
        Write-Log "FOUND (PATH): $hit"
    }
}

# --- 3. Broad scan of fixed drives (slower, catches anything unlisted) -----------
Write-Log "--- Running broad scan of fixed drives (this may take a few minutes) ---"
$excludeDirs = @('Windows', 'WinSxS', 'node_modules', '$Recycle.Bin', 'ProgramData\Microsoft')
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | Select-Object -ExpandProperty Root

foreach ($drive in $drives) {
    Write-Log "Scanning $drive ..."
    try {
        Get-ChildItem -Path $drive -Filter "php.exe" -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $path = $_.FullName
                -not ($excludeDirs | Where-Object { $path -like "*\$_\*" })
            } |
            ForEach-Object {
                $verOutput = & $_.FullName -v 2>$null
                $ver = if ($verOutput -match 'PHP\s+(\d+\.\d+\.\d+)') { $Matches[1] } else { "unknown" }
                Write-Log "FOUND (broad scan): $($_.FullName)  [version: $ver]"
            }
    }
    catch {
        Write-Log "Could not scan ${drive}: $($_.Exception.Message)"
    }
}

Write-Log "=== Scan complete. Review $LogFile for full results. ==="
Write-Host ""
Write-Host "Next step: add the parent folder of any FOUND path above to `$SearchRoots"
Write-Host "in Detect-PHPVersion.ps1 and Remediate-PHPVersion.ps1."