# ============================================================
# Detection: Python version check across ALL scopes (machine + every user)
# Compares against the absolute latest stable python.org release.
# Intune Proactive Remediation - SYSTEM context
# ============================================================

function Get-LatestPythonVersion {
    # Parses python.org's FTP index for the highest stable (non-alpha/beta/rc) release
    $index = Invoke-WebRequest -Uri "https://www.python.org/ftp/python/" -UseBasicParsing
    $versions = ($index.Links.href | Where-Object { $_ -match '^\d+\.\d+\.\d+/$' }) -replace '/$', ''
    $latest = $versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1
    return $latest.ToString()
}

function Get-AllPythonInstalls {
    $installs = @()

    # --- Machine-wide install locations ---
    $machinePaths = @()
    $machinePaths += Get-ChildItem "$env:ProgramFiles\Python*\python.exe" -ErrorAction SilentlyContinue
    $machinePaths += Get-ChildItem "${env:ProgramFiles(x86)}\Python*\python.exe" -ErrorAction SilentlyContinue

    foreach ($exe in $machinePaths) {
        $verOutput = & $exe.FullName --version 2>&1
        if ($verOutput -match '(\d+\.\d+\.\d+)') {
            $installs += [PSCustomObject]@{ Path = $exe.FullName; Version = $matches[1]; Scope = "Machine"; SID = $null }
        }
    }

    # --- Per-user install locations (filesystem scan, works regardless of hive access) ---
    $userDirs = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") }

    foreach ($userDir in $userDirs) {
        $pyExes = Get-ChildItem "$($userDir.FullName)\AppData\Local\Programs\Python\Python*\python.exe" -ErrorAction SilentlyContinue
        foreach ($exe in $pyExes) {
            $verOutput = & $exe.FullName --version 2>&1
            if ($verOutput -match '(\d+\.\d+\.\d+)') {
                $installs += [PSCustomObject]@{ Path = $exe.FullName; Version = $matches[1]; Scope = "User:$($userDir.Name)"; SID = $null }
            }
        }
    }

    return $installs
}

try {
    $latest = Get-LatestPythonVersion
    Write-Output "Latest stable Python release: $latest"

    $installs = Get-AllPythonInstalls

    if ($installs.Count -eq 0) {
        Write-Output "COMPLIANT: No Python installations found on disk."
        exit 0
    }

    $outdated = $installs | Where-Object { [version]$_.Version -lt [version]$latest }

    if ($outdated.Count -eq 0) {
        Write-Output "COMPLIANT: All found Python installs ($($installs.Count)) are already at the latest version."
        exit 0
    }

    $details = $outdated | ForEach-Object { "$($_.Version) [$($_.Scope)] at $($_.Path)" }
    Write-Output "NONCOMPLIANT: Outdated Python install(s) found: $($details -join '; ')"
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}