# ============================================================
# Detection: Python Install Manager (pymanager/py.exe) version check
# Intune Proactive Remediation - USER CONTEXT
# (PyManager is a per-user tool; must run as the logged-on user)
# ============================================================

try {
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pyCmd) {
        $pyCmd = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WindowsApps\py.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $pyCmd) {
        Write-Output "COMPLIANT: Python Install Manager (py) not found for this user - nothing for this script to check."
        exit 0
    }

    $pyPath = if ($pyCmd.Source) { $pyCmd.Source } else { $pyCmd.FullName }

    # Latest true stable release, same source of truth used elsewhere
    $index = Invoke-WebRequest -Uri "https://www.python.org/ftp/python/" -UseBasicParsing
    $versions = ($index.Links.href | Where-Object { $_ -match '^\d+\.\d+\.\d+/$' }) -replace '/$', ''
    $latest = ($versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
    Write-Output "Latest stable Python release: $latest"

    # Parse `py list` table output for PythonCore-managed runtimes and their versions.
    # Not relying on exact column positions - just pulling version numbers off lines
    # that mention PythonCore, which is resilient to minor output format changes.
    $listOutput = & $pyPath list 2>&1 | Out-String
    $coreLines = $listOutput -split "`r?`n" | Where-Object { $_ -match 'PythonCore' }

    $installedVersions = @()
    foreach ($line in $coreLines) {
        if ($line -match '(\d+\.\d+\.\d+)') {
            $installedVersions += $matches[1]
        }
    }

    if ($installedVersions.Count -eq 0) {
        Write-Output "COMPLIANT: No PythonCore runtimes currently managed by py."
        exit 0
    }

    $outdatedOrExtra = $installedVersions | Where-Object { $_ -ne $latest }

    if ($outdatedOrExtra.Count -eq 0 -and $installedVersions.Count -eq 1) {
        Write-Output "COMPLIANT: Single runtime installed and it's the latest ($latest)."
        exit 0
    }

    Write-Output "NONCOMPLIANT: PyManager-managed runtime(s) found: $($installedVersions -join ', '). Target: single install of $latest only."
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}