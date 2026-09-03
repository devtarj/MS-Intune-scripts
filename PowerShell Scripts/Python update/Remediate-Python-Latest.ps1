# ============================================================
# Remediation: Remove ALL outdated Python interpreter installs (any path,
# any scope, found via registry) and install the latest stable release
# machine-wide. Also attempts a winget-based update for Python Launcher
# (MSIX component) as a separate, best-effort step.
# Intune Proactive Remediation - SYSTEM context
# Date: 2026-09-03
# ============================================================

$logDir = "C:\ProgramData\IntuneLogs"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $logDir "PythonReplace-Remediation.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Add-Content -Path $logFile -Value $line
    Write-Output $Message
}

function Get-LatestPythonVersion {
    $index = Invoke-WebRequest -Uri "https://www.python.org/ftp/python/" -UseBasicParsing
    $versions = ($index.Links.href | Where-Object { $_ -match '^\d+\.\d+\.\d+/$' }) -replace '/$', ''
    $latest = $versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1
    return $latest.ToString()
}

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
                    $uninstallStr = $_.QuietUninstallString
                    if (-not $uninstallStr) { $uninstallStr = $_.UninstallString }
                    $results += [PSCustomObject]@{
                        DisplayName     = $_.DisplayName
                        Version         = $matches[1]
                        InstallLocation = $_.InstallLocation
                        UninstallString = $uninstallStr
                    }
                }
            }
    }
    return $results
}

function Get-AllPythonInstalls {
    $installs = @()

    Get-PythonRegistryEntries -HiveRoot "HKLM:" | ForEach-Object {
        $installs += [PSCustomObject]@{
            DisplayName = $_.DisplayName; Version = $_.Version; InstallLocation = $_.InstallLocation
            UninstallString = $_.UninstallString; Scope = "Machine"; SID = $null
        }
    }

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
            $installs += [PSCustomObject]@{
                DisplayName = $_.DisplayName; Version = $_.Version; InstallLocation = $_.InstallLocation
                UninstallString = $_.UninstallString; Scope = "User:$($userDir.Name)"; SID = $sid
            }
        }

        # Leave the hive loaded if we loaded it - remediation will unload after uninstall runs,
        # since the uninstall itself may need to write to that hive.
        if ($loadedByUs) {
            $installs | Where-Object { $_.Scope -eq "User:$($userDir.Name)" } | ForEach-Object { $_ | Add-Member -NotePropertyName LoadedHive -NotePropertyValue $true -Force }
        }
    }

    return $installs
}

function Invoke-PythonUninstall {
    param([string]$UninstallString, [string]$DisplayName)

    if (-not $UninstallString) {
        Write-Log "No uninstall string available for $DisplayName - skipping."
        return $false
    }
    if ($UninstallString -match '^"([^"]+)"(.*)$') {
        $exePath = $matches[1]
        $existingArgs = $matches[2].Trim()
    } else {
        $parts = $UninstallString -split ' ', 2
        $exePath = $parts[0]
        $existingArgs = if ($parts.Count -gt 1) { $parts[1] } else { "" }
    }

    if (-not (Test-Path $exePath)) {
        Write-Log "Uninstaller not found at $exePath for $DisplayName - skipping."
        return $false
    }

    $argList = "$existingArgs /quiet".Trim()
    Write-Log "Uninstalling $DisplayName via $exePath $argList"
    Start-Process -FilePath $exePath -ArgumentList $argList -Wait -NoNewWindow
    return $true
}

function Update-PythonLauncher {
    param([string]$WingetPath)

    Write-Log "--- Checking Python Launcher (MSIX component) ---"
    $result = & $WingetPath upgrade --id "Python.Launcher" --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String
    Write-Log $result
}

try {
    $wingetPath = (cmd /c dir /b /s "C:\Program Files\WindowsApps\winget.exe" 2>$null) | Select-Object -First 1

    $latest = Get-LatestPythonVersion
    Write-Log "Latest stable Python release: $latest"

    $installs = Get-AllPythonInstalls
    $outdated = $installs | Where-Object { [version]$_.Version -lt [version]$latest }

    if ($outdated.Count -eq 0) {
        Write-Log "No outdated Python interpreter installs found."
    } else {
        $summary = ($outdated | ForEach-Object { "$($_.Version) [$($_.Scope)] at $($_.InstallLocation)" }) -join '; '
        Write-Log "Found $($outdated.Count) outdated install(s): $summary"

        $loadedSids = @()
        foreach ($install in $outdated) {
            Invoke-PythonUninstall -UninstallString $install.UninstallString -DisplayName $install.DisplayName | Out-Null

            # Fallback: registry uninstall may leave files behind on some builds - clean the folder too.
            if ($install.InstallLocation -and (Test-Path $install.InstallLocation)) {
                Write-Log "Removing residual folder: $($install.InstallLocation)"
                Remove-Item $install.InstallLocation -Recurse -Force -ErrorAction SilentlyContinue
            }

            if ($install.SID -and ($loadedSids -notcontains $install.SID)) {
                $loadedSids += $install.SID
            }
        }

        # Unload any hives we loaded, now that uninstalls have run
        foreach ($sid in $loadedSids) {
            [gc]::Collect()
            Start-Sleep -Milliseconds 500
            $result = cmd /c reg unload "HKU\$sid" 2>&1
            Write-Log "reg unload result for SID $sid : $result"
        }

        # --- Install latest stable version, machine-wide ---
        $installerUrl = "https://www.python.org/ftp/python/$latest/python-$latest-amd64.exe"
        $installerPath = "C:\Windows\Temp\python-$latest-amd64.exe"

        Write-Log "Downloading $installerUrl"
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

        Write-Log "Installing Python $latest machine-wide..."
        $proc = Start-Process -FilePath $installerPath -ArgumentList `
            "/quiet","InstallAllUsers=1","PrependPath=1","Include_test=0","Include_launcher=1" `
            -Wait -PassThru -NoNewWindow

        Write-Log "Installer exit code: $($proc.ExitCode)"
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
            Write-Log "REMEDIATION INCOMPLETE: Interpreter installer failed with exit code $($proc.ExitCode)."
            exit 1
        }
    }

    # --- Best-effort Python Launcher update (separate from interpreter, not a hard fail) ---
    if ($wingetPath) {
        Update-PythonLauncher -WingetPath $wingetPath
    } else {
        Write-Log "winget not found - skipping Python Launcher check."
    }

    Write-Log "Remediation successful."
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}