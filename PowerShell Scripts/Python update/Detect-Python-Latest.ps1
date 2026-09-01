# ============================================================
# Detection: Python version check via registry (any install path,
# any scope) + Python Launcher (MSIX) check via winget
# Intune Proactive Remediation - SYSTEM context
# ============================================================

function Get-LatestPythonVersion {
    $index = Invoke-WebRequest -Uri "https://www.python.org/ftp/python/" -UseBasicParsing
    $versions = ($index.Links.href | Where-Object { $_ -match '^\d+\.\d+\.\d+/$' }) -replace '/$', ''
    $latest = $versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1
    return $latest.ToString()
}

# Reads Python entries from a given Uninstall registry root - works for any
# install location (custom paths like C:\Python are registered here too,
# unlike a folder-pattern filesystem scan which would miss them).
function Get-PythonRegistryEntries {
    param([string]$HiveRoot)

    $paths = @(
        "$HiveRoot\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "$HiveRoot\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $results = @()
    foreach ($p in $paths) {
        Get-ItemProperty -Path $p -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match '^Python 3\.\d+\.\d+' } |
            ForEach-Object {
                if ($_.DisplayVersion -match '(\d+\.\d+\.\d+)') {
                    $results += [PSCustomObject]@{
                        DisplayName     = $_.DisplayName
                        Version         = $matches[1]
                        InstallLocation = $_.InstallLocation
                    }
                }
            }
    }
    return $results
}

function Get-AllPythonInstalls {
    $installs = @()

    # Machine scope
    Get-PythonRegistryEntries -HiveRoot "HKLM:" | ForEach-Object {
        $installs += [PSCustomObject]@{ DisplayName = $_.DisplayName; Version = $_.Version; InstallLocation = $_.InstallLocation; Scope = "Machine" }
    }

    # Per-user scope - load each real user's hive to read their Uninstall key
    $userDirs = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") }

    foreach ($userDir in $userDirs) {
        $sid = (Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
            Where-Object { $_.LocalPath -eq $userDir.FullName }).SID
        if (-not $sid) { continue }

        $hivePath = "Registry::HKEY_USERS\$sid"
        $loadedByUs = $false
        if (-not (Test-Path $hivePath)) {
            $ntUserDat = Join-Path $userDir.FullName "NTUSER.DAT"
            if (-not (Test-Path $ntUserDat)) { continue }
            cmd /c reg load "HKU\$sid" "`"$ntUserDat`"" 2>&1 | Out-Null
            $loadedByUs = $true
        }

        Get-PythonRegistryEntries -HiveRoot $hivePath | ForEach-Object {
            $installs += [PSCustomObject]@{ DisplayName = $_.DisplayName; Version = $_.Version; InstallLocation = $_.InstallLocation; Scope = "User:$($userDir.Name)" }
        }

        if ($loadedByUs) {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            cmd /c reg unload "HKU\$sid" 2>&1 | Out-Null
        }
    }

    return $installs
}

function Get-PythonLauncherStatus {
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1
    if (-not $wingetPath) { return "winget not found - cannot check launcher" }

    $result = & $wingetPath upgrade --id "Python.Launcher" --accept-source-agreements 2>&1 | Out-String
    if ($result -match "No installed package found") {
        return "not installed via winget-visible source"
    }
    if ($result -match "No applicable update found") {
        return "up to date"
    }
    return "update available"
}

try {
    $latest = Get-LatestPythonVersion
    Write-Output "Latest stable Python release: $latest"

    $installs = Get-AllPythonInstalls
    $launcherStatus = Get-PythonLauncherStatus
    Write-Output "Python Launcher status: $launcherStatus"

    $outdatedCore = $installs | Where-Object { [version]$_.Version -lt [version]$latest }

    $needsRemediation = ($outdatedCore.Count -gt 0) -or ($launcherStatus -eq "update available")

    if (-not $needsRemediation) {
        Write-Output "COMPLIANT: All Python interpreter installs ($($installs.Count)) and the Launcher are up to date."
        exit 0
    }

    $details = $outdatedCore | ForEach-Object { "$($_.Version) [$($_.Scope)] at $($_.InstallLocation)" }
    Write-Output "NONCOMPLIANT: Outdated Python install(s): $($details -join '; '). Launcher: $launcherStatus"
    exit 1
}
catch {
    Write-Output "NONCOMPLIANT: Detection error - $($_.Exception.Message)"
    exit 1
}