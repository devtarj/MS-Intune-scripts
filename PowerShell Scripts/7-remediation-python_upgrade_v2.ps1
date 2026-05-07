# =========================================
# PYTHON ENTERPRISE REMEDIATION SCRIPT
# =========================================

# Exit if winget unavailable
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found"
    exit 1
}

Write-Output "Starting Python remediation..."

# =========================================
# 1. REMOVE ALL PYTHON INSTALLATIONS
# =========================================

$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$apps = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | Where-Object {
    $_.DisplayName -match "^Python"
}

foreach ($app in $apps) {

    Write-Output "Removing: $($app.DisplayName)"

    if ($app.UninstallString) {

        $uninstall = $app.UninstallString

        # MSI uninstall
        if ($uninstall -match "msiexec") {

            if ($uninstall -notmatch "/quiet") {
                $uninstall += " /quiet /norestart"
            }

            Start-Process "cmd.exe" `
                -ArgumentList "/c $uninstall" `
                -WindowStyle Hidden `
                -Wait
        }
        else {

            Start-Process "cmd.exe" `
                -ArgumentList "/c $uninstall /quiet /norestart" `
                -WindowStyle Hidden `
                -Wait
        }
    }
}

# =========================================
# 2. REMOVE PYTHON FOLDERS
# =========================================

$pythonFolders = @(
    "C:\Python*",
    "C:\Program Files\Python*",
    "C:\Program Files (x86)\Python*"
)

foreach ($folder in $pythonFolders) {

    Get-ChildItem $folder -ErrorAction SilentlyContinue | ForEach-Object {

        Write-Output "Deleting folder: $($_.FullName)"

        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# =========================================
# 3. CLEAN PATH VARIABLES
# =========================================

function Remove-PythonPathEntries {

    param (
        [string]$Scope
    )

    $path = [Environment]::GetEnvironmentVariable("Path", $Scope)

    if ($path) {

        $cleaned = ($path -split ";" | Where-Object {
            $_ -notmatch "Python"
        }) -join ";"

        [Environment]::SetEnvironmentVariable("Path", $cleaned, $Scope)
    }
}

Remove-PythonPathEntries -Scope Machine
Remove-PythonPathEntries -Scope User

# =========================================
# 4. INSTALL LATEST PYTHON
# =========================================

Write-Output "Installing latest Python..."

Start-Process "winget" -ArgumentList @(
    "install",
    "--id", "Python.Python.3",
    "--scope", "machine",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--disable-interactivity",
    "--force"
) -WindowStyle Hidden -Wait

Start-Sleep -Seconds 15

# =========================================
# 5. ADD LATEST PYTHON TO PATH
# =========================================

$latestPython = Get-ChildItem "C:\Program Files" -Directory |
Where-Object {
    $_.Name -match "^Python"
} |
Sort-Object Name -Descending |
Select-Object -First 1

if ($latestPython) {

    $pythonPath = "$($latestPython.FullName)"
    $scriptsPath = "$($latestPython.FullName)\Scripts"

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")

    $newPath = "$pythonPath;$scriptsPath;$machinePath"

    [Environment]::SetEnvironmentVariable(
        "Path",
        $newPath,
        "Machine"
    )

    Write-Output "Updated PATH"
}

# =========================================
# 6. VERIFY INSTALLATION
# =========================================

$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")

$versionOutput = python --version 2>&1

Write-Output "Installed version: $versionOutput"

# =========================================
# 7. OPTIONAL DEFENDER REFRESH
# =========================================

$mpCmd = "C:\Program Files\Windows Defender\MpCmdRun.exe"

if (Test-Path $mpCmd) {

    Start-Process $mpCmd `
        -ArgumentList "-Scan -ScanType 1" `
        -WindowStyle Hidden
}

Write-Output "Python remediation completed"
exit 0