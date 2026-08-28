# ============================================================
# Remediation: Remove all outdated Python installs (any scope) and
# install the latest stable release machine-wide.
# Intune Proactive Remediation - SYSTEM context
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

function Get-AllPythonInstalls {
    $installs = @()

    $machinePaths = @()
    $machinePaths += Get-ChildItem "$env:ProgramFiles\Python*\python.exe" -ErrorAction SilentlyContinue
    $machinePaths += Get-ChildItem "${env:ProgramFiles(x86)}\Python*\python.exe" -ErrorAction SilentlyContinue

    foreach ($exe in $machinePaths) {
        $verOutput = & $exe.FullName --version 2>&1
        if ($verOutput -match '(\d+\.\d+\.\d+)') {
            $installs += [PSCustomObject]@{ Path = $exe.FullName; Version = $matches[1]; Scope = "Machine"; UserDir = $null }
        }
    }

    $userDirs = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") }

    foreach ($userDir in $userDirs) {
        $pyExes = Get-ChildItem "$($userDir.FullName)\AppData\Local\Programs\Python\Python*\python.exe" -ErrorAction SilentlyContinue
        foreach ($exe in $pyExes) {
            $verOutput = & $exe.FullName --version 2>&1
            if ($verOutput -match '(\d+\.\d+\.\d+)') {
                $installs += [PSCustomObject]@{ Path = $exe.FullName; Version = $matches[1]; Scope = "User:$($userDir.Name)"; UserDir = $userDir.FullName }
            }
        }
    }

    return $installs
}

function Get-UserSID {
    param([string]$Username)
    $prof = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPath -eq "C:\Users\$Username" }
    return $prof.SID
}

function Remove-UserScopedPython {
    param([string]$Username, [string]$Version)

    $sid = Get-UserSID -Username $Username
    if (-not $sid) {
        Write-Log "Could not resolve SID for $Username - skipping registry-based uninstall, will remove folder directly."
        return $false
    }

    $hiveKey = "HKU\$sid"
    $hivePath = "Registry::HKEY_USERS\$sid"
    $loadedByUs = $false

    if (-not (Test-Path $hivePath)) {
        $ntUserDat = "C:\Users\$Username\NTUSER.DAT"
        if (-not (Test-Path $ntUserDat)) {
            Write-Log "NTUSER.DAT not found for $Username - skipping registry-based uninstall."
            return $false
        }
        $result = cmd /c reg load $hiveKey `"$ntUserDat`" 2>&1
        Write-Log "reg load result for $Username : $result"
        $loadedByUs = $true
    }

    $found = $false
    try {
        $uninstallRoot = "$hivePath\Software\Microsoft\Windows\CurrentVersion\Uninstall"
        if (Test-Path $uninstallRoot) {
            $entries = Get-ChildItem $uninstallRoot -ErrorAction SilentlyContinue
            foreach ($entry in $entries) {
                $props = Get-ItemProperty $entry.PSPath -ErrorAction SilentlyContinue
                if ($props.DisplayName -match "^Python 3\.") {
                    $uninstallStr = $props.QuietUninstallString
                    if (-not $uninstallStr) { $uninstallStr = $props.UninstallString }

                    if ($uninstallStr -match '^"([^"]+)"') {
                        $exePath = $matches[1]
                    } else {
                        $exePath = ($uninstallStr -split ' ')[0]
                    }

                    if (Test-Path $exePath) {
                        Write-Log "Uninstalling $($props.DisplayName) for $Username via $exePath"
                        Start-Process -FilePath $exePath -ArgumentList "/uninstall","/quiet" -Wait -NoNewWindow
                        $found = $true
                    } else {
                        Write-Log "Uninstaller exe not found at $exePath for $($props.DisplayName) - will remove folder directly."
                    }
                }
            }
        }
    }
    finally {
        if ($loadedByUs) {
            [gc]::Collect()
            Start-Sleep -Seconds 2
            $result = cmd /c reg unload $hiveKey 2>&1
            Write-Log "reg unload result for $Username : $result"
        }
    }

    return $found
}

try {
    $latest = Get-LatestPythonVersion
    Write-Log "Latest stable Python release: $latest"

    $installs = Get-AllPythonInstalls
    $outdated = $installs | Where-Object { [version]$_.Version -lt [version]$latest }

    if ($outdated.Count -eq 0) {
        Write-Log "No outdated Python installs found at remediation time."
        exit 0
    }

    $summary = ($outdated | ForEach-Object { "$($_.Version) [$($_.Scope)]" }) -join ', '
    Write-Log "Found $($outdated.Count) outdated install(s): $summary"

    foreach ($install in $outdated) {
        if ($install.Scope -eq "Machine") {
            $uninstallKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                                            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
            foreach ($key in $uninstallKeys) {
                $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
                if ($props.DisplayName -match "^Python $([regex]::Escape($install.Version))") {
                    $uninstallStr = $props.QuietUninstallString
                    if (-not $uninstallStr) { $uninstallStr = $props.UninstallString }
                    if ($uninstallStr -match '^"([^"]+)"') { $exePath = $matches[1] } else { $exePath = ($uninstallStr -split ' ')[0] }
                    if (Test-Path $exePath) {
                        Write-Log "Uninstalling machine-wide Python $($install.Version) via $exePath"
                        Start-Process -FilePath $exePath -ArgumentList "/uninstall","/quiet" -Wait -NoNewWindow
                    }
                }
            }
        }
        else {
            $username = ($install.Scope -split ':')[1]
            $uninstalled = Remove-UserScopedPython -Username $username -Version $install.Version

            if (-not $uninstalled -and (Test-Path (Split-Path $install.Path -Parent))) {
                Write-Log "Falling back to direct folder removal for $($install.Path)"
                Remove-Item (Split-Path $install.Path -Parent) -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

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
        Write-Log "REMEDIATION INCOMPLETE: Installer failed with exit code $($proc.ExitCode)."
        exit 1
    }

    Write-Log "Remediation successful - Python $latest installed machine-wide, old versions removed."
    exit 0
}
catch {
    Write-Log "FAILED: $($_.Exception.Message)"
    exit 1
}