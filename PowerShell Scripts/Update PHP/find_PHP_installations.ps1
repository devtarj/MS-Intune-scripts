<#
.SYNOPSIS
    Diagnostic - locates every php.exe on a device by scanning fixed drives.
    Designed to be run REMOTELY via Intune (Devices > Scripts > Run script, or
    as a one-off Proactive Remediation detection script) - all detail is logged
    to file for reference, but the actual result you need is printed as ONE
    compact summary line at the very end via Write-Host, since that's what
    Intune actually captures and shows in the portal's per-device Output field
    (which truncates long/streamed output).

.NOTES
    Full-drive search (excludes Windows/WinSxS/node_modules for speed) - can
    take a couple of minutes depending on disk size. Always exits 0; this is a
    read-only diagnostic, not a compliance check.
#>

$ErrorActionPreference = 'Continue'
$LogFile = "C:\ProgramData\IntuneLogs\PHP-Diagnostic.log"
New-Item -Path (Split-Path $LogFile) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

function Write-DetailLog {
    # Full detail goes to the log file only - NOT to stdout, so it can't crowd
    # out the summary line if you're reading this via Intune's remote output.
    param([string]$Message)
    $line = "$(Get-Date -Format s)  $Message"
    try { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

$results = New-Object System.Collections.Generic.List[string]

Write-DetailLog "=== PHP diagnostic scan starting ==="

# --- 1. Known common install roots (fast check first) -------------------------
$knownRoots = @(
    "C:\php", "C:\Program Files\PHP", "C:\Program Files (x86)\PHP", "C:\tools\php",
    "C:\xampp\php", "C:\wamp64\bin\php", "C:\wamp\bin\php", "C:\laragon\bin\php",
    "C:\inetpub\php", "D:\xampp\php", "D:\wamp64\bin\php"
)

foreach ($root in $knownRoots) {
    if (Test-Path $root) {
        $hits = cmd /c "dir /b /s `"$root\php.exe`" 2>nul"
        if ($hits) {
            foreach ($hit in ($hits -split "`r`n" | Where-Object { $_ -match '\S' })) {
                Write-DetailLog "FOUND (known root): $hit"
                if (-not $results.Contains($hit.Trim())) { $results.Add($hit.Trim()) }
            }
        }
    }
}

# --- 2. PATH ---------------------------------------------------------------------
$whereResult = cmd /c "where php.exe 2>nul"
if ($whereResult) {
    foreach ($hit in ($whereResult -split "`r`n" | Where-Object { $_ -match '\S' })) {
        Write-DetailLog "FOUND (PATH): $hit"
        if (-not $results.Contains($hit.Trim())) { $results.Add($hit.Trim()) }
    }
}

# --- 3. Broad scan of fixed drives (slower, catches anything unlisted) -----------
$excludeDirs = @('Windows', 'WinSxS', 'node_modules', '$Recycle.Bin', 'ProgramData\Microsoft')
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | Select-Object -ExpandProperty Root

foreach ($drive in $drives) {
    Write-DetailLog "Scanning $drive ..."
    try {
        Get-ChildItem -Path $drive -Filter "php.exe" -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $path = $_.FullName
                -not ($excludeDirs | Where-Object { $path -like "*\$_\*" })
            } |
            ForEach-Object {
                Write-DetailLog "FOUND (broad scan): $($_.FullName)"
                if (-not $results.Contains($_.FullName)) { $results.Add($_.FullName) }
            }
    }
    catch {
        Write-DetailLog "Could not scan ${drive}: $($_.Exception.Message)"
    }
}

# --- 4. Build ONE compact summary line for Intune's captured output --------------
if ($results.Count -eq 0) {
    Write-DetailLog "=== Scan complete: no php.exe found anywhere ==="
    Write-Host "PHP_SCAN_RESULT: NONE_FOUND"
}
else {
    $withVersions = foreach ($path in $results) {
        $ver = "unknown"
        try {
            $verOutput = & $path -v 2>$null
            if ($verOutput -match 'PHP\s+(\d+\.\d+\.\d+)') { $ver = $Matches[1] }
        } catch {}
        "$path (v$ver)"
    }
    Write-DetailLog "=== Scan complete: $($results.Count) found ==="
    $summary = "PHP_SCAN_RESULT: found=$($results.Count) | " + ($withVersions -join " ;; ")

    # Safety cap so the line can't exceed Intune's captured output size
    if ($summary.Length -gt 1900) { $summary = $summary.Substring(0, 1900) + " ...(truncated - see PHP-Diagnostic.log)" }

    Write-Host $summary
}